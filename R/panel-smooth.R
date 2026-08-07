#' Smooth numeric variables within panel IDs
#'
#' @param data A panel data frame.
#' @param vars Numeric fields to smooth.
#' @param window Odd rolling-window width.
#' @param weights `"equal"`, `"half"`, or `"decay"`.
#' @param time Panel-time column.
#' @param id Panel-ID column.
#' @param verbose Print progress.
#' @return Input rows in original order with selected fields smoothed.
#' @export
panel_smooth <- function(
    data, vars, window = 3, weights = c("equal", "half", "decay"),
    time = "TAX_YEAR", id = "EIN2", verbose = TRUE
) {
  weights <- match.arg(weights)
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!id %in% names(data)) stop("`id` column not found: ", id)
  if (!time %in% names(data)) stop("`time` column not found: ", time)
  if (!is.character(vars) || !length(vars)) stop("`vars` must name numeric fields.")
  missing <- setdiff(vars, names(data))
  if (length(missing)) stop("Variable(s) not found in data: ", paste(missing, collapse = ", "))
  if (any(!vapply(data[vars], is.numeric, logical(1L))))
    stop("Every field in `vars` must be numeric.")
  if (length(window) != 1L || is.na(window) || window < 1L || window %% 2L == 0L)
    stop("`window` must be an odd integer >= 1.")
  if (window == 1L) return(as.data.frame(data))

  out <- as.data.frame(data)
  groups <- split(seq_len(nrow(out)), out[[id]], drop = TRUE)
  if (verbose) message("Smoothing ", length(vars), " variable(s) across ",
                       length(groups), " panel ID(s).")
  for (rows in groups) {
    rows <- rows[order(out[[time]][rows])]
    n <- length(rows)
    width <- min(as.integer(window), n)
    for (variable in vars) {
      original <- out[[variable]][rows]
      smoothed <- rep(NA_real_, n)
      for (position in seq_len(n)) {
        start <- max(1L, min(position - floor(width / 2), n - width + 1L))
        pos <- start:(start + width - 1L)
        distance <- abs(pos - position)
        raw_weights <- switch(weights,
          equal = rep(1, width),
          half = if (width == 1L) 1 else {
            w <- rep(0.5 / (width - 1L), width)
            w[which.min(distance)] <- 0.5
            w
          },
          decay = 0.5^distance
        )
        values <- original[pos]
        values[is.nan(values)] <- NA_real_
        keep <- !is.na(values)
        smoothed[position] <- if (!any(keep)) NA_real_ else
          sum(values[keep] * raw_weights[keep]) / sum(raw_weights[keep])
      }
      out[[variable]][rows] <- smoothed
    }
  }
  rownames(out) <- NULL
  out
}
