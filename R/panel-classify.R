.EFILE_PANEL_TYPES <- c("full", "entry", "exit", "interior", "empty")
.EFILE_SPELL_BALANCE <- c("contiguous", "fragmented")

.efile_classify_pattern <- function(observed, panel_years) {
  observed <- sort(unique(observed))
  panel_years <- sort(unique(panel_years))
  if (length(observed) == 0L) return(list(
    panel_type = "empty", panel_spell_balance = NA_character_,
    panel_gap_count = NA_integer_, panel_gap_size_max = NA_integer_
  ))

  positions <- match(observed, panel_years)
  first <- min(positions)
  last <- max(positions)
  span <- last - first + 1L
  contiguous <- span == length(positions)
  touches_first <- first == 1L
  touches_last <- last == length(panel_years)
  panel_type <- if (touches_first && touches_last) "full" else
    if (!touches_first && touches_last) "entry" else
      if (touches_first && !touches_last) "exit" else "interior"

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
    panel_spell_balance = if (contiguous) "contiguous" else "fragmented",
    panel_gap_count = as.integer(gap_count),
    panel_gap_size_max = as.integer(gap_size)
  )
}

#' Classify panel coverage and internal gaps
#'
#' Assigns each observed ID a boundary type (`full`, `entry`, `exit`, or
#' `interior`) and spell balance (`contiguous` or `fragmented`).
#'
#' @param data A panel data frame.
#' @param time Name of the panel-time column.
#' @param id Name of the panel-ID column.
#' @param append_classification Append classification fields to every input row.
#' @param return_classification Attach the per-ID classification to the summary.
#' @param print_table Print the year-by-type summary.
#' @return Either the input data with classification columns or a year-by-type
#'   summary carrying a `classification` attribute.
#' @export
panel_describe <- function(
    data,
    time = "TAX_YEAR",
    id = "EIN2",
    append_classification = FALSE,
    return_classification = TRUE,
    print_table = TRUE
) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!time %in% names(data)) stop("Time column not found: ", time)
  if (!id %in% names(data)) stop("ID column not found: ", id)
  data <- as.data.frame(data)

  pairs <- unique(data[!is.na(data[[id]]) & !is.na(data[[time]]),
                       c(id, time), drop = FALSE])
  if (nrow(pairs) == 0L) stop("No non-missing ID/time observations found.")
  panel_years <- sort(unique(pairs[[time]]))
  split_years <- split(pairs[[time]], pairs[[id]])
  classified <- lapply(split_years, .efile_classify_pattern,
                       panel_years = panel_years)
  details <- do.call(rbind, lapply(classified, as.data.frame,
                                   stringsAsFactors = FALSE))
  class_df <- stats::setNames(
    data.frame(names(split_years), stringsAsFactors = FALSE),
    id
  )
  class_df$panel_year_first <- vapply(split_years, min, panel_years[[1]])
  class_df$panel_year_last <- vapply(split_years, max, panel_years[[1]])
  class_df$panel_year_count <- vapply(split_years, function(x) length(unique(x)),
                                      integer(1L))
  class_df <- cbind(class_df, details)

  typed <- merge(pairs, class_df[, c(id, "panel_type"), drop = FALSE],
                 by = id, all.x = TRUE, sort = FALSE)
  counts <- table(factor(typed[[time]], levels = panel_years),
                  factor(typed$panel_type, levels = .EFILE_PANEL_TYPES))
  count_df <- as.data.frame.matrix(counts, stringsAsFactors = FALSE)
  summary <- data.frame(year = panel_years, count_df, check.names = FALSE,
                        row.names = NULL)

  if (print_table) print(summary, row.names = FALSE)
  if (append_classification) {
    input <- data
    old <- intersect(setdiff(names(class_df), id), names(input))
    if (length(old)) input[old] <- NULL
    input$.efile_order__ <- seq_len(nrow(input))
    out <- merge(input, class_df, by = id, all.x = TRUE, sort = FALSE)
    out <- out[order(out$.efile_order__), , drop = FALSE]
    out$.efile_order__ <- NULL
    rownames(out) <- NULL
    return(out)
  }
  if (return_classification) attr(summary, "classification") <- class_df
  summary
}
