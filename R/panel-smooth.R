#' Smooth numeric variables within panel IDs
#'
#' Replaces each selected field with a rolling weighted average taken within
#' each panel ID, ordered by `time`.
#'
#' @section Window alignment:
#' * `"center"` (default) averages the `window` *rows* centred on the focal
#'   row. Positions are counted by row, not calendar year, so a filing gap is
#'   bridged; at the ends of a series the fixed-width window slides inward, and
#'   IDs with fewer rows than `window` use all their rows. `window` must be odd.
#' * `"right"` is a trailing (backward-looking) window: for a row in year `t`
#'   it uses only rows whose `time` falls in `t - (window - 1)` through `t`.
#'   Years are counted on the calendar, so a missing filing year simply leaves
#'   a hole in the window -- it is never bridged by reaching further back --
#'   and no value later than `t` is ever used. Early rows use whatever of the
#'   window is observed.
#' * `"left"` is the forward-looking mirror: years `t` through
#'   `t + (window - 1)`.
#'
#' For `"right"` and `"left"`, `window` may be any positive integer and `time`
#' must be numeric (or coercible to numeric, such as `"2021"`).
#'
#' @section Weights:
#' Weights are assigned to the window's slots and then renormalized over the
#' values actually present.
#' * `"equal"`: every slot counts the same.
#' * `"half"`: the focal year gets 0.5; the other `window - 1` slots share the
#'   other 0.5 equally.
#' * `"decay"`: `0.5^distance`, where distance is in rows for `"center"` and
#'   in calendar years (`t - year` for `"right"`, `year - t` for `"left"`)
#'   otherwise.
#'
#' Missing values (`NA`/`NaN`) are dropped from each window and the remaining
#' weights renormalized, so a missing focal value is filled from its
#' neighbours; a window with nothing observed returns `NA`.
#'
#' @param data A panel data frame.
#' @param vars Numeric fields to smooth.
#' @param window Rolling-window width: an odd integer for `align = "center"`,
#'   any positive integer otherwise.
#' @param weights `"equal"`, `"half"`, or `"decay"`.
#' @param align `"center"` (default, row-based centred window), `"right"`
#'   (trailing calendar-year window, no future values), or `"left"`
#'   (forward-looking calendar-year window). See *Window alignment*.
#' @param time Panel-time column.
#' @param id Panel-ID column.
#' @param verbose Print progress.
#' @return Input rows in original order with selected fields smoothed.
#' @examples
#' df <- data.frame(EIN2 = "A", TAX_YEAR = c(2018, 2019, 2021, 2022),
#'                  revenue = c(10, 20, 30, 40))
#' # centred (row-based)
#' panel_smooth(df, "revenue", verbose = FALSE)$revenue
#' # trailing 3-year window; 2020 is missing, so 2021 uses 2019 and 2021 only
#' panel_smooth(df, "revenue", align = "right", verbose = FALSE)$revenue
#' @export
panel_smooth <- function(
    data, vars, window = 3, weights = c("equal", "half", "decay"),
    align = c("center", "left", "right"),
    time = "TAX_YEAR", id = "EIN2", verbose = TRUE
) {
  if (is_panel(data)) {
    a <- as.list(environment()); a[c("data", "id", "time")] <- NULL
    return(do.call(.panel_apply,
      c(list(data, panel_smooth, "panel_smooth"), list(stale = FALSE), a)))
  }
  weights <- match.arg(weights)
  align <- match.arg(align)
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!id %in% names(data)) stop("`id` column not found: ", id)
  if (!time %in% names(data)) stop("`time` column not found: ", time)
  if (!is.character(vars) || !length(vars)) stop("`vars` must name numeric fields.")
  missing <- setdiff(vars, names(data))
  if (length(missing)) stop("Variable(s) not found in data: ", paste(missing, collapse = ", "))
  if (any(!vapply(data[vars], is.numeric, logical(1L))))
    stop("Every field in `vars` must be numeric.")
  if (align == "center") {
    if (length(window) != 1L || is.na(window) || window < 1L || window %% 2L != 1L)
      stop("`window` must be an odd integer >= 1.")
  } else if (length(window) != 1L || is.na(window) || window < 1L || window %% 1 != 0) {
    stop("`window` must be an integer >= 1.")
  }
  if (window == 1L) return(as.data.frame(data))

  out <- as.data.frame(data)
  if (align != "center") {
    years <- suppressWarnings(as.numeric(as.character(out[[time]])))
    if (any(is.na(years) & !is.na(out[[time]])))
      stop("`time` must be numeric (calendar years) when `align` is \"",
           align, "\".")
  }
  groups <- split(seq_len(nrow(out)), out[[id]], drop = TRUE)
  if (verbose) message("Smoothing ", length(vars), " variable(s) across ",
                       length(groups), " panel ID(s), align = \"", align, "\".")
  for (rows in groups) {
    rows <- rows[order(out[[time]][rows])]
    if (align == "center") {
      for (variable in vars)
        out[[variable]][rows] <- .smooth_center(out[[variable]][rows], window, weights)
    } else {
      for (variable in vars)
        out[[variable]][rows] <- .smooth_calendar(
          out[[variable]][rows], years[rows], window, weights, align)
    }
  }
  rownames(out) <- NULL
  out
}

# Weighted mean of `values` with weights `w`, dropping NA/NaN and renormalizing.
.smooth_mean <- function(values, w) {
  keep <- !is.na(values)
  if (!any(keep)) NA_real_ else sum(values[keep] * w[keep]) / sum(w[keep])
}

# Row-based centred window (original behaviour, unchanged).
.smooth_center <- function(original, window, weights) {
  n <- length(original)
  width <- min(as.integer(window), n)
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
    smoothed[position] <- .smooth_mean(original[pos], raw_weights)
  }
  smoothed
}

# Calendar-year window: years t-(window-1)..t ("right") or t..t+(window-1)
# ("left"). Rows outside the window -- including any year beyond a filing gap --
# are never used.
.smooth_calendar <- function(original, years, window, weights, align) {
  n <- length(original)
  smoothed <- rep(NA_real_, n)
  for (position in seq_len(n)) {
    t <- years[position]
    if (is.na(t)) { smoothed[position] <- original[position]; next }
    distance <- if (align == "right") t - years else years - t
    pos <- which(!is.na(distance) & distance >= 0 & distance <= window - 1)
    d <- distance[pos]
    raw_weights <- switch(weights,
      equal = rep(1, length(pos)),
      half = ifelse(d == 0, 0.5, 0.5 / (window - 1)),
      decay = 0.5^d
    )
    smoothed[position] <- .smooth_mean(original[pos], raw_weights)
  }
  smoothed
}
