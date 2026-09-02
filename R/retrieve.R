# Shared retrieval infrastructure: run identity, per-run logging, progress
# messaging, and retrying fetches. Used by download_tables() and the BMF
# retrieval path so both emit the same START/OK/FAIL trace and write the same
# style of per-run log.

.p990_or <- function(x, y) if (is.null(x)) y else x

#' Identifier for a single retrieval run
#'
#' Timestamp plus a process-unique token, used to name per-run log files so
#' repeated or concurrent runs never overwrite one another. Uses `tempfile()`
#' rather than the RNG so package code leaves `.Random.seed` untouched.
#' @return A length-one character vector such as `"20260902T051200-1a2b3c"`.
#' @keywords internal
.p990_run_id <- function() {
  token <- sub("^p990", "", basename(tempfile("p990")))
  paste0(format(Sys.time(), "%Y%m%dT%H%M%S"), "-", token)
}

.p990_bytes <- function(x) {
  if (length(x) != 1L || is.na(x)) return("unknown size")
  x <- as.numeric(x)
  units <- c("B", "KB", "MB", "GB", "TB")
  i <- 1L
  while (x >= 1024 && i < length(units)) {
    x <- x / 1024
    i <- i + 1L
  }
  paste0(format(round(x, 1L), nsmall = 1L, trim = TRUE), " ", units[[i]])
}

.p990_rate <- function(bytes, seconds) {
  if (is.na(bytes) || is.na(seconds) || seconds <= 0) return("")
  paste0(" @ ", .p990_bytes(bytes / seconds), "/s")
}

# Messages go to stderr; flush so the START line is visible while a multi-GB
# transfer is still running rather than appearing only once it finishes.
.p990_say <- function(...) {
  message(...)
  utils::flush.console()
  invisible(NULL)
}

.p990_begin <- function(label, size = NA_real_, attempt = 1L, retry_max = 1L,
                        verbose = TRUE) {
  if (!isTRUE(verbose)) return(invisible(NULL))
  size_text <- if (is.na(size)) "" else paste0(" (", .p990_bytes(size), ")")
  try_text <- if (attempt > 1L)
    paste0(" [attempt ", attempt, " of ", retry_max, "]") else ""
  .p990_say("-> START    ", label, size_text, try_text)
}

.p990_done <- function(label, bytes = NA_real_, seconds = NA_real_,
                       status = "OK", verbose = TRUE) {
  if (!isTRUE(verbose)) return(invisible(NULL))
  .p990_say("<- ", format(status, width = 8L), " ", label, " ",
            .p990_bytes(bytes), " in ", round(seconds, 1L), "s",
            .p990_rate(bytes, seconds))
}

.p990_failed <- function(label, attempt, retry_max, error, verbose = TRUE) {
  if (!isTRUE(verbose)) return(invisible(NULL))
  .p990_say("<- FAIL     ", label, " (attempt ", attempt, " of ", retry_max,
            "): ", error)
}

#' Fetch one remote or local resource, retrying on failure
#'
#' Raises the download timeout for the duration of the call (the R default of
#' 60 seconds is far too short for multi-GB sources), retries with exponential
#' backoff, deletes partial files between attempts, and verifies the byte count
#' against `expected_bytes` when a published manifest supplies one.
#'
#' @param url Remote URL or local file path.
#' @param destination Local destination path.
#' @param timeout Per-attempt timeout in seconds.
#' @param retry_max Maximum attempts.
#' @param expected_bytes Optional expected size used as an integrity check.
#' @param label Human-readable name used in progress messages.
#' @param overwrite Re-fetch even when the destination already exists.
#' @param backoff Seconds before the second attempt; doubles thereafter.
#' @param verbose Print START/OK/FAIL messages.
#' @return A list with `status`, `attempts`, `bytes`, `seconds`, and `error`.
#' @keywords internal
.p990_fetch <- function(url, destination, timeout = 1800, retry_max = 3L,
                        expected_bytes = NA_real_,
                        label = basename(destination), overwrite = FALSE,
                        backoff = 5, verbose = TRUE) {
  retry_max <- max(1L, as.integer(retry_max))
  if (file.exists(destination) && !isTRUE(overwrite)) {
    size <- file.info(destination)$size
    if (isTRUE(verbose)) .p990_say("== REUSED   ", label, " ", .p990_bytes(size))
    return(list(status = "reused", attempts = 0L, bytes = size, seconds = 0,
                error = NA_character_))
  }
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  old_timeout <- getOption("timeout")
  on.exit(options(timeout = old_timeout), add = TRUE)
  options(timeout = timeout)

  is_remote <- grepl("^https?://", url, ignore.case = TRUE)
  error <- NA_character_
  overall <- Sys.time()
  for (attempt in seq_len(retry_max)) {
    .p990_begin(label, expected_bytes, attempt, retry_max, verbose)
    started <- Sys.time()
    # download.file() signals a truncated transfer as a warning, so treat
    # warnings as failures and let the retry loop handle them.
    ok <- tryCatch({
      if (is_remote) {
        utils::download.file(url, destination, mode = "wb", quiet = TRUE)
      } else {
        if (!file.exists(url)) stop("Source file not found: ", url)
        if (!file.copy(url, destination, overwrite = TRUE))
          stop("Could not copy source file: ", url)
      }
      file.exists(destination)
    },
    error = function(e) {
      error <<- conditionMessage(e)
      FALSE
    },
    warning = function(w) {
      error <<- conditionMessage(w)
      FALSE
    })
    seconds <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    bytes <- if (file.exists(destination)) file.info(destination)$size else NA_real_

    if (isTRUE(ok) && !is.na(expected_bytes) && !is.na(bytes) &&
        bytes != expected_bytes) {
      error <- paste0("incomplete transfer: received ", bytes, " of ",
                      expected_bytes, " bytes")
      ok <- FALSE
    }
    if (isTRUE(ok)) {
      .p990_done(label, bytes, seconds, "OK", verbose)
      return(list(status = "downloaded", attempts = attempt, bytes = bytes,
                  seconds = seconds, error = NA_character_))
    }
    # A partial file would otherwise be mistaken for a valid cache entry.
    if (file.exists(destination)) unlink(destination)
    .p990_failed(label, attempt, retry_max, error, verbose)
    if (attempt < retry_max) {
      wait <- backoff * 2^(attempt - 1L)
      if (isTRUE(verbose)) .p990_say("   waiting ", wait, "s before retry ...")
      Sys.sleep(wait)
    }
  }
  list(status = "failed", attempts = retry_max, bytes = NA_real_,
       seconds = as.numeric(difftime(Sys.time(), overall, units = "secs")),
       error = error)
}

#' Write a per-run log and append to the run index
#'
#' Every run writes its own timestamped file, so a later run can never
#' overwrite an earlier record.
#'
#' @param manifest Data frame describing the run.
#' @param base_path Cache directory; logs are written to `<base_path>/logs`.
#' @param run_id Identifier from [.p990_run_id()].
#' @param kind Log family, such as `"download"` or `"bmf"`.
#' @return The normalized path of the per-run log file.
#' @keywords internal
.p990_write_log <- function(manifest, base_path, run_id, kind = "download") {
  log_dir <- file.path(base_path, "logs")
  dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)
  log_file <- file.path(log_dir, paste0(kind, "-", run_id, ".csv"))
  manifest <- cbind(run_id = run_id, manifest, stringsAsFactors = FALSE)
  utils::write.csv(manifest, log_file, row.names = FALSE, na = "")

  index_file <- file.path(log_dir, "runs-index.csv")
  tally <- function(x) sum(manifest$status %in% x, na.rm = TRUE)
  entry <- data.frame(
    run_id = run_id, kind = kind,
    recorded_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S"),
    resources = nrow(manifest), downloaded = tally("downloaded"),
    reused = tally("reused"), failed = tally("failed"),
    bytes = sum(manifest$bytes, na.rm = TRUE),
    elapsed_seconds = round(sum(manifest$elapsed_seconds, na.rm = TRUE), 1L),
    log_file = basename(log_file), stringsAsFactors = FALSE
  )
  had_index <- file.exists(index_file)
  utils::write.table(entry, index_file, sep = ",", row.names = FALSE, na = "",
                     col.names = !had_index, append = had_index)
  normalizePath(log_file, winslash = "/", mustWork = FALSE)
}

#' List retrieval runs recorded in a cache directory
#'
#' Each call to [download_tables()] or [bmf_retrieve()] appends one row and
#' leaves a full per-run manifest beside it in `<path>/logs`.
#'
#' @param path Cache directory used by [download_tables()] or [bmf_retrieve()].
#' @return A data frame of recorded runs, oldest first, or `NULL` when the
#'   cache holds no run index.
#' @export
retrieval_log <- function(path = "PANEL990") {
  index_file <- file.path(path, "logs", "runs-index.csv")
  if (!file.exists(index_file)) {
    message("No retrieval runs recorded under ", file.path(path, "logs"), ".")
    return(invisible(NULL))
  }
  utils::read.csv(index_file, stringsAsFactors = FALSE)
}
