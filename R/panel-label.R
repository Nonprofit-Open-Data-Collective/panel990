#' Label rows with panel membership
#'
#' Appends the per-organization panel classification (`panel_type`,
#' `panel_spell`, first/last/count and gap metrics) to every input row,
#' preserving row order.
#'
#' @param data A panel data frame.
#' @param time Name of the panel-time column.
#' @param id Name of the panel-ID column.
#' @param classification Optional precomputed classification (from
#'   [panel_describe()]); computed from `data` when `NULL`.
#' @return `data` with panel classification columns appended.
#' @seealso [panel_describe()], [panel_filter()].
#' @export
panel_label <- function(data, time = "TAX_YEAR", id = "EIN2",
                        classification = NULL) {
  if (is_panel(data)) {
    a <- as.list(environment()); a[c("data", "id", "time")] <- NULL
    return(do.call(.panel_apply,
      c(list(data, panel_label, "panel_label"), list(stale = FALSE), a)))
  }
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!id %in% names(data)) stop("ID column not found: ", id)
  data <- as.data.frame(data)
  cls <- .panel_resolve_classification(classification, data, time, id)
  attr(cls, "panel_years") <- NULL

  add_cols <- setdiff(names(cls), id)
  input <- data
  old <- intersect(add_cols, names(input))
  if (length(old)) input[old] <- NULL
  input$.panel_order__ <- seq_len(nrow(input))
  out <- merge(input, cls, by = id, all.x = TRUE, sort = FALSE)
  out <- out[order(out$.panel_order__), , drop = FALSE]
  out$.panel_order__ <- NULL
  rownames(out) <- NULL
  out
}
