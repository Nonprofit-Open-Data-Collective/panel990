# Panel membership classification shared by panel_describe(), panel_label(),
# panel_filter(), panel_impute(), and the sample-frame classifier.
#
# Two orthogonal dimensions:
#   panel_type  (boundary: which edges of the panel window the org touches)
#     persistent - present at the first AND last panel year (spans the window)
#     entrant    - enters after the first year, present through the last
#     exit       - present from the first year, gone before the last
#     transient  - only interior years (enters late and leaves early)
#     empty      - no observations
#   panel_spell (continuity of the observed years within the org's span)
#     seamless   - consecutive years, no interior gaps
#     segmented  - one or more interior years missing
# A gapped entrant, for example, is panel_type = "entrant", panel_spell =
# "segmented". A "balanced" organization is persistent + seamless.

.PANEL_TYPES <- c("persistent", "entrant", "exit", "transient", "empty")
.PANEL_SPELL <- c("seamless", "segmented")

.panel_classify_pattern <- function(observed, panel_years) {
  observed <- sort(unique(observed))
  panel_years <- sort(unique(panel_years))
  if (length(observed) == 0L) return(list(
    panel_type = "empty", panel_spell = NA_character_,
    panel_gap_count = NA_integer_, panel_gap_size_max = NA_integer_
  ))

  positions <- match(observed, panel_years)
  first <- min(positions)
  last <- max(positions)
  span <- last - first + 1L
  contiguous <- span == length(positions)
  touches_first <- first == 1L
  touches_last <- last == length(panel_years)
  panel_type <- if (touches_first && touches_last) "persistent"
    else if (!touches_first && touches_last) "entrant"
    else if (touches_first && !touches_last) "exit"
    else "transient"

  if (contiguous) {
    gap_count <- 0L
    gap_size <- 0L
  } else {
    presence <- as.integer(first:last %in% positions)
    runs <- rle(presence)
    gaps <- runs$lengths[runs$values == 0L]
    gap_count <- length(gaps)
    gap_size <- if (length(gaps)) max(gaps) else 0L
  }
  list(
    panel_type = panel_type,
    panel_spell = if (contiguous) "seamless" else "segmented",
    panel_gap_count = as.integer(gap_count),
    panel_gap_size_max = as.integer(gap_size)
  )
}

# Per-organization classification data frame (one row per id). Carries the panel
# years vector as an attribute.
.panel_classify <- function(data, time, id) {
  if (!id %in% names(data)) stop("ID column not found: ", id)
  if (!time %in% names(data)) stop("Time column not found: ", time)
  pairs <- unique(data[!is.na(data[[id]]) & !is.na(data[[time]]),
                       c(id, time), drop = FALSE])
  if (nrow(pairs) == 0L) stop("No non-missing ID/time observations found.")
  panel_years <- sort(unique(pairs[[time]]))
  split_years <- split(pairs[[time]], pairs[[id]])
  classified <- lapply(split_years, .panel_classify_pattern,
                       panel_years = panel_years)
  details <- do.call(rbind, lapply(classified, as.data.frame,
                                   stringsAsFactors = FALSE))
  class_df <- stats::setNames(
    data.frame(names(split_years), stringsAsFactors = FALSE), id)
  class_df$panel_year_first <- vapply(split_years, min, panel_years[[1]])
  class_df$panel_year_last  <- vapply(split_years, max, panel_years[[1]])
  class_df$panel_year_count <- vapply(split_years,
                                      function(x) length(unique(x)), integer(1L))
  class_df <- cbind(class_df, details)
  rownames(class_df) <- NULL
  attr(class_df, "panel_years") <- panel_years
  class_df
}

# Accept a precomputed classification (data frame, or object carrying a
# "classification" attribute), or compute one from data.
.panel_resolve_classification <- function(classification, data, time, id) {
  if (is.null(classification)) return(.panel_classify(data, time, id))
  attached <- attr(classification, "classification", exact = TRUE)
  if (!is.null(attached)) classification <- attached
  if (!is.data.frame(classification))
    stop("`classification` must be a data frame.")
  miss <- setdiff(c(id, "panel_type"), names(classification))
  if (length(miss))
    stop("Classification missing column(s): ", paste(miss, collapse = ", "))
  classification
}

#' Describe panel coverage and membership
#'
#' Classifies each organization on two axes -- `panel_type` (boundary:
#' `persistent`, `entrant`, `exit`, `transient`, `empty`) and `panel_spell`
#' (continuity: `seamless`, `segmented`) -- and summarizes the panel. See
#' [panel_label()] to append the classification to rows and [panel_filter()] to
#' select organizations.
#'
#' Given a [panel][as_panel] it also stores the classification as label rules on
#' the frame, marks the labels current, and logs the step.
#'
#' @param x A panel data frame or a [panel][as_panel].
#' @param time Name of the panel-time column.
#' @param id Name of the panel-ID column.
#' @param by_year Include the org-years-by-type breakdown. Default `TRUE`.
#' @param print Print the summary. Default `TRUE`.
#' @param ... Passed to methods.
#' @return For a data frame, invisibly a `panel_summary` object carrying the
#'   per-organization classification as its `"classification"` attribute; for a
#'   panel, the panel with labels refreshed.
#' @export
panel_describe <- function(x, ...) UseMethod("panel_describe")

#' @rdname panel_describe
#' @export
panel_describe.data.frame <- function(x, time = "TAX_YEAR", id = "EIN2",
                                      by_year = TRUE, print = TRUE, ...) {
  data <- as.data.frame(x)
  class_df <- .panel_classify(data, time, id)
  panel_years <- attr(class_df, "panel_years")

  tt <- factor(class_df$panel_type, levels = .PANEL_TYPES)
  ss <- factor(class_df$panel_spell, levels = .PANEL_SPELL)
  ct <- as.data.frame.matrix(table(tt, ss))
  by_type <- data.frame(panel_type = rownames(ct), ct, check.names = FALSE,
                        row.names = NULL, stringsAsFactors = FALSE)
  by_type$total <- as.integer(table(tt))
  by_type$pct <- round(100 * by_type$total / sum(by_type$total), 1)
  by_type <- by_type[by_type$total > 0L, , drop = FALSE]
  rownames(by_type) <- NULL

  by_year_df <- NULL
  if (isTRUE(by_year)) {
    pairs <- unique(data[!is.na(data[[id]]) & !is.na(data[[time]]),
                         c(id, time), drop = FALSE])
    typed <- merge(pairs, class_df[, c(id, "panel_type")], by = id,
                   all.x = TRUE, sort = FALSE)
    counts <- table(factor(typed[[time]], levels = panel_years),
                    factor(typed$panel_type, levels = .PANEL_TYPES))
    cm <- as.data.frame.matrix(counts, stringsAsFactors = FALSE)
    cm <- cm[, colSums(cm) > 0L, drop = FALSE]
    by_year_df <- data.frame(year = panel_years, cm, check.names = FALSE,
                             row.names = NULL)
  }

  out <- structure(list(
    n_orgs = nrow(class_df), n_years = length(panel_years),
    years = panel_years, by_type = by_type, by_year = by_year_df
  ), class = "panel_summary")
  attr(out, "classification") <- class_df
  if (isTRUE(print)) print(out)
  invisible(out)
}

#' @rdname panel_describe
#' @export
panel_describe.panel <- function(x, print = TRUE, ...) {
  entity <- .panel_entity(x); time <- .panel_time(x)
  before <- dim(x$data)
  panel_describe.data.frame(x$data, time = time, id = entity, print = print)
  x$sfw <- classify_panel(x$sfw, x$data)      # store panel_type/panel_spell labels
  x$fresh <- TRUE
  x$sfw <- .panel_receipt(x$sfw, "panel_describe", "classified panel",
                          before, before)
  invisible(x)
}

#' @export
print.panel_summary <- function(x, ...) {
  cat("<panel_summary>  ", x$n_orgs, " orgs x ", x$n_years, " years (",
      min(x$years), "-", max(x$years), ")\n", sep = "")
  cat("\npanel types (org counts by spell):\n")
  print(x$by_type, row.names = FALSE)
  if (!is.null(x$by_year)) {
    cat("\norg-years by type:\n")
    print(x$by_year, row.names = FALSE)
  }
  invisible(x)
}
