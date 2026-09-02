.efile_resource <- function(root, filename) {
  if (grepl("^https?://", root, ignore.case = TRUE))
    paste0(sub("/+$", "", root), "/", filename)
  else file.path(root, filename)
}

#' Download or reuse efile table CSV files
#'
#' Each file is fetched by [.p990_fetch()], which raises the download timeout,
#' retries with exponential backoff, and discards partial files between
#' attempts. Progress is reported as a START line before each transfer begins
#' and an OK/FAIL line when it settles, so a stalled file is identifiable while
#' it is still running.
#'
#' Every call writes its own log under `<path>/logs` named for the run, so
#' repeated runs accumulate rather than overwrite. See [retrieval_log()].
#'
#' @param years Integer tax years.
#' @param tables Aliases or literal canonical table names.
#' @param source An [data_source()] configuration.
#' @param path Cache directory used when `cache = "retain"`.
#' @param cache `"retain"` for a durable cache or `"temporary"` for a session
#'   temporary directory.
#' @param overwrite Download again even when a cached file exists.
#' @param retry_max Maximum attempts per remote file.
#' @param timeout Download timeout in seconds, per attempt.
#' @param verbose Print per-file progress messages.
#' @return An `download_result` containing successful file paths, a structured
#'   table-year manifest, the `run_id`, and the per-run `log_file`.
#' @export
download_tables <- function(
    years,
    tables,
    source = data_source(),
    path = "PANEL990",
    cache = c("retain", "temporary"),
    overwrite = FALSE,
    retry_max = 3L,
    timeout = 1800,
    verbose = TRUE
) {
  cache <- match.arg(cache)
  if (!is.numeric(years) || !length(years) || anyNA(years))
    stop("`years` must be a non-empty numeric vector.")
  years <- sort(unique(as.integer(years)))
  if (retry_max < 1L) stop("`retry_max` must be at least 1.")
  resolved <- resolve_tables(tables, source)
  base_path <- if (cache == "temporary") tempfile("panel990-") else path
  dir.create(base_path, recursive = TRUE, showWarnings = FALSE)
  run_id <- .p990_run_id()

  total <- length(years) * nrow(resolved)
  if (verbose)
    .p990_say("Run ", run_id, ": ", total, " table-year file(s) from ",
              source$root)

  manifest <- list()
  files <- character()
  row <- 0L
  for (year in years) for (i in seq_len(nrow(resolved))) {
    table <- resolved$table[[i]]
    filename <- paste0(table, "-", year, ".CSV")
    destination <- file.path(base_path, as.character(year), filename)
    resource <- .efile_resource(source$root, filename)
    row <- row + 1L
    outcome <- .p990_fetch(
      resource, destination, timeout = timeout, retry_max = retry_max,
      label = paste0("[", row, "/", total, "] ", table, " ", year),
      overwrite = overwrite, verbose = verbose
    )
    success <- outcome$status %in% c("downloaded", "reused")
    if (success) files <- c(files, destination)
    manifest[[row]] <- data.frame(
      year = year, request = resolved$request[[i]], table = table,
      cardinality = resolved$cardinality[[i]], source = resource,
      path = normalizePath(destination, winslash = "/", mustWork = FALSE),
      status = outcome$status, attempts = outcome$attempts,
      bytes = if (success) outcome$bytes else NA_real_,
      elapsed_seconds = round(outcome$seconds, 2L),
      error = outcome$error, stringsAsFactors = FALSE
    )
  }
  manifest <- do.call(rbind, manifest)
  log_file <- .p990_write_log(manifest, base_path, run_id, kind = "download")
  failed <- sum(manifest$status == "failed")
  if (verbose)
    .p990_say("Run ", run_id, " complete: ",
              sum(manifest$status == "downloaded"), " downloaded, ",
              sum(manifest$status == "reused"), " reused, ", failed,
              " failed. Log: ", log_file)
  structure(
    list(files = unname(files), manifest = manifest, run_id = run_id,
         cache_path = normalizePath(base_path, winslash = "/", mustWork = FALSE),
         log_file = log_file),
    class = "download_result"
  )
}
