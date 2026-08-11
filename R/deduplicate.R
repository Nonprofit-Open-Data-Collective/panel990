.efile_flagged <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  if (is.numeric(x)) return(!is.na(x) & x == 1)
  value <- toupper(trimws(as.character(x)))
  !is.na(value) & value %in% c("X", "TRUE", "T", "1", "Y", "YES")
}

.efile_parse_timestamp <- function(x) {
  value <- trimws(as.character(x))
  value[is.na(value) | value == ""] <- NA_character_
  value <- sub(" (UTC|GMT)$", "", value, ignore.case = TRUE)
  out <- as.POSIXct(rep(NA_real_, length(value)), origin = "1970-01-01", tz = "UTC")
  for (fmt in c("%Y-%m-%d %H:%M:%OS", "%Y-%m-%dT%H:%M:%OS", "%Y-%m-%d")) {
    missing <- is.na(out) & !is.na(value)
    if (!any(missing)) break
    out[missing] <- suppressWarnings(as.POSIXct(value[missing], format = fmt,
                                                tz = "UTC"))
  }
  out
}

#' Select one filing per organization-year
#'
#' Prefers non-group and non-partial filings, then amended filings, then the
#' most recent timestamp. At least one filing is retained per organization-year.
#'
#' @param data A filing data frame.
#' @param id Organization identifier column.
#' @param year Filing-year column.
#' @param group Group-return flag column.
#' @param partial Partial-return flag column.
#' @param amended Amended-return flag column; use `NULL` to disable.
#' @param timestamp Filing timestamp column.
#' @param verbose Print a summary.
#' @return A data frame with at most one row per ID-year (or the panel, given a
#'   [panel][as_panel]). `deduplicate()` is a deprecated alias.
#' @export
panel_deduplicate <- function(
    data, id = "EIN2", year = "TAX_YEAR",
    group = "RETURN_GROUP_X", partial = "RETURN_PARTIAL_X",
    amended = "RETURN_AMENDED_X", timestamp = "RETURN_TIME_STAMP",
    verbose = TRUE
) {
  if (is_panel(data)) {
    a <- as.list(environment()); a[c("data", "id", "year")] <- NULL
    return(do.call(.panel_apply,
      c(list(data, panel_deduplicate, "panel_deduplicate"),
        list(stale = TRUE, time_arg = "year"), a)))
  }
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!id %in% names(data)) stop("ID column not found: ", id)
  if (!year %in% names(data)) stop("Year column not found: ", year)
  out <- as.data.frame(data)
  n <- nrow(out)
  score_group <- if (group %in% names(out))
    as.integer(!.efile_flagged(out[[group]])) else rep(1L, n)
  score_partial <- if (partial %in% names(out))
    as.integer(!.efile_flagged(out[[partial]])) else rep(1L, n)
  score_amended <- if (!is.null(amended) && amended %in% names(out))
    as.integer(.efile_flagged(out[[amended]])) else rep(0L, n)
  stamp <- if (timestamp %in% names(out))
    as.numeric(.efile_parse_timestamp(out[[timestamp]])) else rep(NA_real_, n)
  if (verbose) {
    optional <- c(group, partial, if (!is.null(amended)) amended, timestamp)
    for (column in optional)
      if (!column %in% names(out)) message("Column '", column, "' not found; preference skipped.")
  }
  ord <- order(out[[id]], out[[year]], -score_group, -score_partial,
               -score_amended, -stamp, seq_len(n), na.last = TRUE)
  out <- out[ord, , drop = FALSE]
  key <- paste(out[[id]], out[[year]], sep = "\r")
  out <- out[!duplicated(key), , drop = FALSE]
  rownames(out) <- NULL
  if (verbose) message("Deduplication complete: ", n, " -> ", nrow(out), " row(s).")
  out
}

#' @rdname panel_deduplicate
#' @export
deduplicate <- panel_deduplicate
