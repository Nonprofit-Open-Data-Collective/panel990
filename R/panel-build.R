.efile_bind_rows <- function(items) {
  columns <- unique(unlist(lapply(items, names), use.names = FALSE))
  # rbindlist(fill = TRUE) supplies missing columns and is far faster than
  # do.call(rbind, ...) on efile-sized frames; the explicit reorder keeps the
  # first-appearance column order the previous implementation produced.
  out <- data.table::rbindlist(items, use.names = TRUE, fill = TRUE)
  out <- as.data.frame(out, stringsAsFactors = FALSE)
  out <- out[, columns, drop = FALSE]
  rownames(out) <- NULL
  out
}

# Combine two named value-filter lists; shared columns intersect.
.efile_merge_filters <- function(a, b) {
  if (is.null(a)) return(b)
  if (is.null(b)) return(a)
  out <- a
  for (nm in names(b))
    out[[nm]] <- if (is.null(out[[nm]])) b[[nm]] else intersect(out[[nm]], b[[nm]])
  out
}

#' Download, filter, merge, append BMF, and stack a panel
#'
#' The workhorse acquisition recipe: resolve tables and years, download (or
#' virtually scan) the CSVs, project columns and push the sample frame's entity
#' restriction down to read-time, merge the tables within each year, stack the
#' years, optionally append BMF organization traits, then apply the frame's
#' rules. Returns a [panel][as_panel] bundling the data with the frame and a
#' provenance log.
#'
#' Keys are set automatically from the efile schema (entity `EIN2`, time
#' `TAX_YEAR`, record `OBJECTID`).
#'
#' @param sfw Optional [create_sfw()] sample frame governing the build. Filters
#'   prefilter reads and merges; `select` rules project columns.
#' @param tables Aliases or literal table names.
#' @param years Tax years.
#' @param source Efile source configuration.
#' @param bmf Append BMF fields: `"auto"` (default -- attach when the frame
#'   references a BMF field), `FALSE`, `TRUE` (the NCCS master), or a BMF source
#'   (data frame, path, or URL).
#' @param backend `"memory"` (default) or `"duckdb"` (`"db"` is accepted).
#' @param cache `"retain"`, `"temporary"`, or `"none"` (DuckDB-only virtual scan).
#' @param path Retained-cache directory.
#' @param filters Optional named value filters (merged with the frame's).
#' @param columns Optional source fields to retain (union with the frame's).
#' @param include_many Join one-to-many and supplemental tables.
#' @param collision Non-key collision policy.
#' @param overwrite Replace cached files.
#' @param retry_max Download attempts.
#' @param timeout Download timeout.
#' @param verbose Print progress.
#' @return A `panel` (see [as_panel()]) whose `data` is the stacked frame, whose
#'   `sfw` carries the rules and provenance log ([manifest()]), plus
#'   download/table/join manifests and BMF diagnostics.
#' @export
panelize <- function(
    sfw = NULL, tables, years, source = data_source(),
    bmf = "auto", backend = "memory",
    cache = c("retain", "temporary", "none"), path = "PANEL990",
    filters = NULL, columns = NULL, include_many = FALSE,
    collision = c("error", "prefix"), overwrite = FALSE,
    retry_max = 3L, timeout = 1800, verbose = TRUE
) {
  cache <- match.arg(cache)
  collision <- match.arg(collision)
  if (identical(backend, "db")) backend <- "duckdb"
  backend <- match.arg(backend, c("memory", "duckdb"))
  if (cache == "none" && backend != "duckdb")
    stop("`cache = 'none'` requires `backend = 'duckdb'`.")

  # keys come from the schema; when no frame is supplied we create a default one
  # (entity EIN2 / time TAX_YEAR from create_sfw(), record OBJECTID) and name it
  # after the tables and year range so the manifest is self-describing.
  if (is.null(sfw)) {
    tbl_lab <- if (length(tables) <= 6L) paste(tables, collapse = ",")
               else paste0(length(tables), " tables")
    yr_lab  <- if (length(years)) paste0(min(years), "-", max(years)) else "no years"
    sfw <- create_sfw(sprintf("panel[%s | %s]", tbl_lab, yr_lab), record = "OBJECTID")
  }
  else {
    .sfw_check(sfw)
    if (is.na(.sfw_key(sfw, "record")))
      sfw <- add_key(sfw, "record", "unique_record", "OBJECTID")
  }

  acq <- .sfw_to_acquire(sfw, columns)
  keys <- acq$keys
  if (is.null(columns)) columns <- acq$read_columns
  filters <- .efile_merge_filters(filters, acq$read_filters)

  downloads <- if (cache == "none")
    .efile_virtual_download(years, tables, source) else
      download_tables(years, tables, source, path, cache, overwrite, retry_max,
                     timeout, verbose)
  read_columns <- if (is.null(columns)) NULL else unique(c(keys, columns))
  reads <- if (backend == "duckdb")
    read_tables_duckdb(downloads, columns = read_columns, filters = filters) else
      read_tables(downloads, columns = read_columns, filters = filters,
                  verbose = verbose)
  merged <- merge_tables(reads, keys = keys, include_many = include_many,
                        collision = collision, verbose = verbose)
  if (!length(merged$years)) stop("No table-year data were available for the panel.")
  if (verbose) .p990_say("-> STACK    ", length(merged$years), " year(s)")
  stack_started <- Sys.time()
  data <- .efile_bind_rows(merged$years)
  if (verbose)
    .p990_say("<- STACK OK ", format(nrow(data), big.mark = ","), " x ",
              ncol(data), " in ",
              round(as.numeric(difftime(Sys.time(), stack_started,
                                        units = "secs")), 1L), "s")
  sfw <- .panel_receipt(sfw, "panelize",
                        paste0(length(tables), " tables x ",
                               length(unique(years)), " years"),
                        c(NA, NA), dim(data))

  bmf_diagnostics <- NULL
  do_bmf <- if (identical(bmf, "auto")) .sfw_references_bmf(sfw) else !isFALSE(bmf)
  if (isTRUE(do_bmf)) {
    # NULL routes bmf_merge() to the published release and its own strategy
    # selection; anything else is an explicit user override.
    bmf_source <- if (isTRUE(bmf) || identical(bmf, "auto")) NULL else bmf
    before <- dim(data)
    data <- bmf_merge(
      data, source = bmf_source, path = path,
      cache = if (cache == "retain") "retain" else "temporary",
      overwrite = overwrite, timeout = max(timeout, 3600), retry_max = retry_max,
      verbose = verbose
    )
    bmf_diagnostics <- attr(data, "bmf_diagnostics")
    attr(data, "bmf_diagnostics") <- NULL
    sfw <- .panel_receipt(sfw, "bmf_merge", "append BMF fields", before, dim(data))
  }

  before <- dim(data)
  data <- apply_sfw(data, sfw, verbose = verbose)
  steps <- attr(data, "sfw_steps")
  sfw_checks <- attr(data, "sfw_checks"); sfw_views <- attr(data, "sfw_views")
  for (a in c("sfw_steps", "sfw_checks", "sfw_views")) attr(data, a) <- NULL
  if (!is.null(steps)) for (i in seq_len(nrow(steps)))
    sfw <- .panel_receipt(sfw, steps$step[[i]], steps$criteria[[i]],
                          c(steps$rows_before[[i]], steps$cols_before[[i]]),
                          c(steps$rows_after[[i]], steps$cols_after[[i]]))

  structure(list(
    data = data, sfw = sfw, fresh = FALSE,
    download_manifest = downloads$manifest,
    table_manifest = merged$table_manifest,
    join_manifest = merged$join_manifest,
    sfw_checks = sfw_checks, sfw_views = sfw_views,
    bmf_diagnostics = bmf_diagnostics,
    source = source, backend = backend
  ), class = "panel")
}
