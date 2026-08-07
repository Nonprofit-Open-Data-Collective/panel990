.efile_resource <- function(root, filename) {
  if (grepl("^https?://", root, ignore.case = TRUE))
    paste0(sub("/+$", "", root), "/", filename)
  else file.path(root, filename)
}

#' Download or reuse efile table CSV files
#'
#' @param years Integer tax years.
#' @param tables Aliases or literal canonical table names.
#' @param source An [data_source()] configuration.
#' @param path Cache directory used when `cache = "retain"`.
#' @param cache `"retain"` for a durable cache or `"temporary"` for a session
#'   temporary directory.
#' @param overwrite Download again even when a cached file exists.
#' @param retry_max Maximum attempts per remote file.
#' @param timeout Download timeout in seconds.
#' @param verbose Print progress messages.
#' @return An `download_result` containing successful file paths and a
#'   structured table-year manifest.
#' @export
download_tables <- function(
    years,
    tables,
    source = data_source(),
    path = "efdata",
    cache = c("retain", "temporary"),
    overwrite = FALSE,
    retry_max = 3L,
    timeout = 300,
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
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = timeout)

  manifest <- list()
  files <- character()
  row <- 0L
  is_remote <- grepl("^https?://", source$root, ignore.case = TRUE)
  for (year in years) for (i in seq_len(nrow(resolved))) {
    table <- resolved$table[[i]]
    filename <- paste0(table, "-", year, ".CSV")
    year_path <- file.path(base_path, as.character(year))
    dir.create(year_path, recursive = TRUE, showWarnings = FALSE)
    destination <- file.path(year_path, filename)
    resource <- .efile_resource(source$root, filename)
    started <- Sys.time()
    attempts <- 0L
    status <- "failed"
    error_message <- NA_character_

    if (file.exists(destination) && !overwrite) {
      status <- "reused"
    } else {
      for (attempt in seq_len(as.integer(retry_max))) {
        attempts <- attempt
        ok <- tryCatch({
          if (is_remote) {
            utils::download.file(resource, destination, mode = "wb", quiet = TRUE)
            file.exists(destination)
          } else {
            if (!file.exists(resource)) stop("Source file not found: ", resource)
            file.copy(resource, destination, overwrite = TRUE)
          }
        }, error = function(e) {
          error_message <<- conditionMessage(e)
          FALSE
        })
        if (isTRUE(ok)) {
          status <- "downloaded"
          error_message <- NA_character_
          break
        }
      }
    }
    success <- status %in% c("downloaded", "reused")
    if (success) files <- c(files, destination)
    row <- row + 1L
    manifest[[row]] <- data.frame(
      year = year, request = resolved$request[[i]], table = table,
      cardinality = resolved$cardinality[[i]], source = resource,
      path = normalizePath(destination, winslash = "/", mustWork = FALSE),
      status = status, attempts = attempts,
      bytes = if (success) file.info(destination)$size else NA_real_,
      elapsed_seconds = as.numeric(difftime(Sys.time(), started, units = "secs")),
      error = error_message, stringsAsFactors = FALSE
    )
    if (verbose) message("[", year, "] ", table, ": ", status)
  }
  manifest <- do.call(rbind, manifest)
  log_file <- file.path(base_path, "efile_download_manifest.csv")
  utils::write.csv(manifest, log_file, row.names = FALSE, na = "")
  structure(
    list(files = unname(files), manifest = manifest,
         cache_path = normalizePath(base_path, winslash = "/", mustWork = FALSE),
         log_file = normalizePath(log_file, winslash = "/", mustWork = FALSE)),
    class = "download_result"
  )
}
