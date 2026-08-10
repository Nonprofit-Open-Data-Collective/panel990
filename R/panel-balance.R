#' Trim a panel to a balanced rectangle
#'
#' Reduces a panel to a balanced set: a block of years in which every retained
#' organization is observed in every retained year. Balancing *trims* (drops
#' organizations and/or years) -- the complement of [panel_complete()], which
#' fills gaps instead.
#'
#' The year window is the trade-off lever. A wide window keeps more years but
#' fewer organizations; a narrow one keeps more organizations. Two strategies:
#' \describe{
#'   \item{`"window"`}{Balance over `years` (or, by default, the full observed
#'     range): keep only organizations observed in every one of those years, and
#'     drop the other years.}
#'   \item{`"max_rectangle"`}{Search contiguous year windows (within `years` if
#'     given) and pick the one that maximizes retained observations
#'     (organizations x years), subject to `min_years`.}
#' }
#'
#' @param data A panel data frame.
#' @param years Candidate years. `NULL` uses the full observed range.
#' @param strategy `"window"` (default) or `"max_rectangle"`.
#' @param min_years Minimum number of years a balanced block must span.
#' @param id Panel-ID column.
#' @param time Panel-time column.
#' @return The balanced rows, with a `"balance"` attribute listing the retained
#'   years and the organization keep/drop counts.
#' @seealso [panel_complete()], [panel_filter()], [panel_describe()].
#' @export
panel_balance <- function(data, years = NULL,
                          strategy = c("window", "max_rectangle"),
                          min_years = 2L, id = "EIN2", time = "TAX_YEAR") {
  strategy <- match.arg(strategy)
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!id %in% names(data)) stop("ID column not found: ", id)
  if (!time %in% names(data)) stop("Time column not found: ", time)
  data <- as.data.frame(data)

  pairs <- unique(data[!is.na(data[[id]]) & !is.na(data[[time]]),
                       c(id, time), drop = FALSE])
  if (nrow(pairs) == 0L) stop("No non-missing ID/time observations found.")
  obs_years <- sort(unique(pairs[[time]]))
  universe <- if (is.null(years)) obs_years else
    sort(unique(intersect(years, obs_years)))
  if (!length(universe)) stop("None of the requested `years` were observed.")

  present <- split(pairs[[time]], pairs[[id]])   # org -> observed years
  covers <- function(w) names(present)[vapply(present,
    function(y) all(w %in% y), logical(1L))]

  if (strategy == "window") {
    target_years <- universe
    if (length(target_years) < min_years)
      warning("Balanced window spans fewer than `min_years` years.")
  } else {
    best <- NULL; best_area <- -1L; n <- length(universe)
    for (i in seq_len(n)) for (j in i:n) {
      w <- universe[i:j]
      if (length(w) < min_years) next
      area <- length(covers(w)) * length(w)
      if (area > best_area || (area == best_area &&
                               (is.null(best) || length(w) > length(best)))) {
        best_area <- area; best <- w
      }
    }
    if (is.null(best))
      stop("No window of at least ", min_years, " years balances any organizations.")
    target_years <- best
  }

  keep_orgs <- covers(target_years)
  out <- data[data[[id]] %in% keep_orgs & data[[time]] %in% target_years, ,
              drop = FALSE]
  rownames(out) <- NULL
  attr(out, "balance") <- list(
    years = target_years, n_years = length(target_years),
    orgs_kept = length(keep_orgs),
    orgs_dropped = length(present) - length(keep_orgs)
  )
  out
}
