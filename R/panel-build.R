.efile_bind_rows <- function(items) {
  columns <- unique(unlist(lapply(items, names), use.names = FALSE))
  items <- lapply(items, function(x) {
    missing <- setdiff(columns, names(x))
    for (field in missing) x[[field]] <- NA
    x[, columns, drop = FALSE]
  })
  out <- do.call(rbind, items)
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
    cache = c("retain", "temporary", "none"), path = "efdata",
    filters = NULL, columns = NULL, include_many = FALSE,
    collision = c("error", "prefix"), overwrite = FALSE,
    retry_max = 3L, timeout = 300, verbose = TRUE
) {
  cache <- match.arg(cache)
  collision <- match.arg(collision)
  if (identical(backend, "db")) backend <- "duckdb"
  backend <- match.arg(backend, c("memory", "duckdb"))
  if (cache == "none" && backend != "duckdb")
    stop("`cache = 'none'` requires `backend = 'duckdb'`.")

  # keys come from the schema; an empty frame is created when none is supplied
  if (is.null(sfw)) sfw <- create_sfw("panel", record = "OBJECTID")
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
      read_tables(downloads, columns = read_columns, filters = filters)
  merged <- merge_tables(reads, keys = keys, include_many = include_many,
                        collision = collision)
  if (!length(merged$years)) stop("No table-year data were available for the panel.")
  data <- .efile_bind_rows(merged$years)
  sfw <- .panel_receipt(sfw, "panelize",
                        paste0(length(tables), " tables x ",
                               length(unique(years)), " years"),
                        c(NA, NA), dim(data))

  bmf_diagnostics <- NULL
  do_bmf <- if (identical(bmf, "auto")) .sfw_references_bmf(sfw) else !isFALSE(bmf)
  if (isTRUE(do_bmf)) {
    bmf_source <- if (isTRUE(bmf) || identical(bmf, "auto")) .EFILE_BMF_URL else bmf
    before <- dim(data)
    data <- bmf_merge(data, source = bmf_source, verbose = verbose)
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
