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

#' Download, read, merge, and assemble a multi-year efile panel
#'
#' Acquires and assembles a panel. When a sample frame is supplied via `sfw`, it
#' governs acquisition: keys come from the frame, its entity restriction is
#' pushed down to read-time, its `select` rules project columns, and after
#' assembly (and optional BMF join) its rules are applied via [apply_sfw()].
#'
#' @param years Tax years.
#' @param tables Aliases or literal table names.
#' @param source Efile source configuration.
#' @param sfw Optional [create_sfw()] sample frame governing the build.
#' @param bmf Merge BMF fields after assembly: `FALSE` (default), `TRUE` (the
#'   NCCS master), or a BMF source (data frame, path, or URL) passed to
#'   [bmf_merge()].
#' @param path Retained-cache directory.
#' @param cache `"retain"`, `"temporary"`, or `"none"`. `"none"` is available
#'   only with the DuckDB backend and scans source URLs virtually.
#' @param backend `"memory"` or `"duckdb"`.
#' @param filters Optional named value filters (merged with the frame's).
#' @param columns Optional source fields to retain. Join keys are added.
#' @param keys Explicit candidate filing keys (overridden by the frame's keys).
#' @param include_many Join one-to-many and supplemental tables.
#' @param collision Non-key collision policy.
#' @param overwrite Replace cached files.
#' @param retry_max Download attempts.
#' @param timeout Download timeout.
#' @param verbose Print progress.
#' @return A `panel990` object with `data`, download/table/join manifests, and
#'   (when `sfw` is given) the applied frame plus its step/check manifests.
#' @export
panelize <- function(
    years, tables, source = data_source(), sfw = NULL, bmf = FALSE,
    path = "efdata",
    cache = c("retain", "temporary", "none"), backend = c("memory", "duckdb"),
    filters = NULL, columns = NULL,
    keys = .EFILE_FILING_KEYS, include_many = FALSE,
    collision = c("error", "prefix"), overwrite = FALSE,
    retry_max = 3L, timeout = 300, verbose = TRUE
) {
  cache <- match.arg(cache)
  backend <- match.arg(backend)
  collision <- match.arg(collision)
  if (cache == "none" && backend != "duckdb")
    stop("`cache = 'none'` requires `backend = 'duckdb'`.")

  if (!is.null(sfw)) {
    .sfw_check(sfw)
    acq <- .sfw_to_acquire(sfw, columns)
    keys <- acq$keys
    if (is.null(columns)) columns <- acq$read_columns
    filters <- .efile_merge_filters(filters, acq$read_filters)
  }

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

  bmf_diagnostics <- NULL
  if (!isFALSE(bmf)) {
    bmf_source <- if (isTRUE(bmf)) .EFILE_BMF_URL else bmf
    data <- bmf_merge(data, source = bmf_source, verbose = verbose)
    bmf_diagnostics <- attr(data, "bmf_diagnostics")
    attr(data, "bmf_diagnostics") <- NULL
  }

  sfw_steps <- NULL; sfw_checks <- NULL
  if (!is.null(sfw)) {
    data <- apply_sfw(data, sfw, verbose = verbose)
    sfw_steps <- attr(data, "sfw_steps")
    sfw_checks <- attr(data, "sfw_checks")
    for (a in c("sfw_steps", "sfw_checks", "sfw_views")) attr(data, a) <- NULL
  }

  structure(list(
    data = data,
    download_manifest = downloads$manifest,
    table_manifest = merged$table_manifest,
    join_manifest = merged$join_manifest,
    cache_path = downloads$cache_path,
    log_file = downloads$log_file,
    source = source,
    backend = backend,
    sfw = sfw,
    sfw_steps = sfw_steps,
    sfw_checks = sfw_checks,
    bmf_diagnostics = bmf_diagnostics
  ), class = "panel990")
}

#' @export
as.data.frame.panel990 <- function(x, ...) x$data

#' @export
print.panel990 <- function(x, ...) {
  cat("<panel990>\n")
  cat("  Rows:", nrow(x$data), " Columns:", ncol(x$data), "\n")
  cat("  Years:", paste(sort(unique(x$data$TAX_YEAR)), collapse = ", "), "\n")
  if (!is.null(x$sfw)) cat("  Sample frame:", x$sfw$meta$name,
                           "(", length(x$sfw$rules), "rules )\n")
  invisible(x)
}
