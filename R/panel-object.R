# =============================================================================
#  panel-object.R
#  A `panel` bundles the data frame with its sample frame (`sfw`) so the two
#  travel together through a workflow. The `panel_*` verbs are polymorphic:
#  handed a `panel` they operate, record a receipt in the frame's log (and, for
#  specification steps, update its rules), and return the panel; handed a bare
#  data frame they just operate and return a data frame.
#
#  Extract the pieces with as.data.frame() and sample_frame(); report the
#  provenance ledger with manifest().
# =============================================================================

#' Bundle a data frame with a sample frame
#'
#' @param data A data frame, or an existing `panel` (returned unchanged).
#' @param sfw An optional [create_sfw()] sample frame; a fresh empty frame is
#'   created when `NULL`.
#' @return A `panel` object: a list of `data`, `sfw`, and a label-freshness flag.
#' @seealso [sample_frame()], [manifest()].
#' @export
as_panel <- function(data, sfw = NULL) {
  if (is_panel(data)) return(data)
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (is.null(sfw)) sfw <- create_sfw("panel") else .sfw_check(sfw)
  structure(list(data = as.data.frame(data), sfw = sfw, fresh = FALSE),
            class = "panel")
}

#' @rdname as_panel
#' @export
is_panel <- function(data) inherits(data, "panel")

#' Extract the data frame or sample frame from a panel
#'
#' @param x A `panel`.
#' @return `panel_data()` returns the data frame; `sample_frame()` returns the
#'   `sfw` (with its rules and provenance log).
#' @export
panel_data <- function(x) if (is_panel(x)) x$data else x

#' @rdname panel_data
#' @export
sample_frame <- function(x) {
  if (is_panel(x)) return(x$sfw)
  if (inherits(x, "sfw")) return(x)
  stop("`x` has no sample frame.")
}

#' @export
as.data.frame.panel <- function(x, ...) x$data

#' @export
print.panel <- function(x, ...) {
  yrs <- if ("TAX_YEAR" %in% names(x$data))
    paste0("  years ", paste(range(x$data$TAX_YEAR, na.rm = TRUE), collapse = "-")) else ""
  cat("<panel>  ", nrow(x$data), " rows x ", ncol(x$data), " cols", yrs, "\n", sep = "")
  cat("  sample frame: ", x$sfw$meta$name, "  (", length(x$sfw$rules),
      " rules, ", length(x$sfw$log), " log entries)\n", sep = "")
  cat("  panel labels: ", if (isTRUE(x$fresh)) "current" else "stale / not computed",
      "\n", sep = "")
  invisible(x)
}

# ---- provenance log ---------------------------------------------------------

# Append a receipt (a record of what a step did) to the frame's log.
.panel_receipt <- function(sfw, step, detail = "", before = c(NA, NA),
                           after = c(NA, NA)) {
  rec <- data.frame(step = step, detail = detail,
                    rows_before = before[[1L]], rows_after = after[[1L]],
                    cols_before = before[[2L]], cols_after = after[[2L]],
                    stringsAsFactors = FALSE)
  sfw$log[[length(sfw$log) + 1L]] <- rec
  sfw$meta$updated <- .sfw_time()
  sfw
}

#' Report a panel's provenance ledger
#'
#' Renders the sample frame's log -- one row per executed step -- as a manifest:
#' the step, its criteria, and the rows/columns before and after, with dropped
#' counts and percentages.
#'
#' @param x A `panel` or a `sfw`.
#' @return A data frame provenance report (empty if nothing has been logged).
#' @export
manifest <- function(x) {
  sfw <- sample_frame(x)
  if (!length(sfw$log))
    return(data.frame(step = character(), detail = character(),
                      rows_before = integer(), rows_after = integer(),
                      rows_dropped = integer(), pct_dropped = numeric(),
                      cols_before = integer(), cols_after = integer(),
                      stringsAsFactors = FALSE))
  m <- do.call(rbind, sfw$log)
  m$rows_dropped <- m$rows_before - m$rows_after
  m$pct_dropped <- ifelse(is.na(m$rows_before) | m$rows_before == 0, NA_real_,
                          round(100 * m$rows_dropped / m$rows_before, 1))
  m[, c("step", "detail", "rows_before", "rows_after", "rows_dropped",
        "pct_dropped", "cols_before", "cols_after")]
}

# ---- governance -------------------------------------------------------------

# A specification step (a filter) becomes/updates a rule. If it conflicts with
# an existing rule on the same column, the old rule is demoted to a log entry
# and a warning is issued; otherwise the rule is added.
.panel_govern_filter <- function(sfw, column, values) {
  existing <- Filter(function(r) identical(r$type, "filter") && is.null(r$expr) &&
                       !is.null(r$column) && identical(r$column, column), sfw$rules)
  if (length(existing) && !identical(existing[[1L]]$values, values)) {
    warning("Overriding filter rule on '", column,
            "'; previous rule demoted to the log.", call. = FALSE)
    sfw <- .panel_receipt(sfw, "rule_demoted",
                          paste0(column, " in ",
                                 paste(utils::head(as.character(existing[[1L]]$values), 6L),
                                       collapse = ",")))
  }
  add_rule(sfw, name = paste0("filter:", column), type = "filter",
           column = column, op = "in", values = values)   # upsert by name
}

# ---- key resolution ---------------------------------------------------------

.panel_entity <- function(x, default = "EIN2") {
  k <- if (is_panel(x)) .sfw_key(x$sfw, "entity") else NA_character_
  if (is.na(k)) default else k
}
.panel_time <- function(x, default = "TAX_YEAR") {
  k <- if (is_panel(x)) .sfw_key(x$sfw, "time") else NA_character_
  if (is.na(k)) default else k
}
