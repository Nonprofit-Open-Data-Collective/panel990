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

#' Download, read, merge, and assemble a multi-year efile panel
#'
#' @param years Tax years.
#' @param tables Aliases or literal table names.
#' @param source Efile source configuration.
#' @param path Retained-cache directory.
#' @param cache `"retain"`, `"temporary"`, or `"none"`. `"none"` is available
#'   only with the DuckDB backend and scans source URLs virtually.
#' @param backend `"memory"` or `"duckdb"`.
#' @param filters Optional named value filters.
#' @param columns Optional source fields to retain. Join keys are added.
#' @param keys Explicit candidate filing keys.
#' @param include_many Join one-to-many and supplemental tables.
#' @param collision Non-key collision policy.
#' @param overwrite Replace cached files.
#' @param retry_max Download attempts.
#' @param timeout Download timeout.
#' @param verbose Print progress.
#' @return An `panel990` with `data`, download/table/join manifests,
#'   cache paths, and source configuration.
#' @export
panelize <- function(
    years, tables, source = data_source(), path = "efdata",
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
  structure(list(
    data = data,
    download_manifest = downloads$manifest,
    table_manifest = merged$table_manifest,
    join_manifest = merged$join_manifest,
    cache_path = downloads$cache_path,
    log_file = downloads$log_file,
    source = source
    , backend = backend
  ), class = "panel990")
}

#' @export
as.data.frame.panel990 <- function(x, ...) x$data

#' @export
print.panel990 <- function(x, ...) {
  cat("<panel990>\n")
  cat("  Rows:", nrow(x$data), " Columns:", ncol(x$data), "\n")
  cat("  Years:", paste(sort(unique(x$data$TAX_YEAR)), collapse = ", "), "\n")
  invisible(x)
}
