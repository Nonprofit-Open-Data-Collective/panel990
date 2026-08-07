#' Insert and fill missing panel years
#'
#' Inserts missing years within eligible observed ID spans. Numeric fields are
#' filled with the mean of the nearest observations bracketing each gap.
#'
#' @param data A panel data frame.
#' @param classification Optional classification from [panel_describe()].
#' @param types Boundary types eligible for imputation.
#' @param max_gap_size Maximum single gap length.
#' @param max_gap_count Maximum number of gaps per ID.
#' @param vars Numeric variables to fill; `NULL` selects numeric non-key fields.
#' @param time Panel-time column.
#' @param id Panel-ID column.
#' @param as_integers Round values for originally integer fields.
#' @return A panel with inserted rows identified by `imputed_row`.
#' @export
panel_impute <- function(
    data, classification = NULL, types = "full",
    max_gap_size = Inf, max_gap_count = Inf, vars = NULL,
    time = "TAX_YEAR", id = "EIN2", as_integers = FALSE
) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!id %in% names(data)) stop("ID column not found: ", id)
  if (!time %in% names(data)) stop("Time column not found: ", time)
  data <- as.data.frame(data)
  class_cols <- c("panel_type", "panel_spell_balance", "panel_gap_count",
                  "panel_gap_size_max", "panel_year_first", "panel_year_last")
  if (is.null(classification)) {
    if (all(class_cols %in% names(data))) {
      classification <- unique(data[, c(id, class_cols), drop = FALSE])
    } else {
      summary <- panel_describe(data, time = time, id = id,
                                      print_table = FALSE)
      classification <- attr(summary, "classification")
    }
  } else {
    attached <- attr(classification, "classification", exact = TRUE)
    if (!is.null(attached)) classification <- attached
  }
  needed <- c(id, class_cols)
  missing <- setdiff(needed, names(classification))
  if (length(missing)) stop("Classification missing: ", paste(missing, collapse = ", "))
  bad_types <- setdiff(types, .EFILE_PANEL_TYPES)
  if (length(bad_types)) stop("Unknown panel type(s): ", paste(bad_types, collapse = ", "))
  eligible <- classification[
    classification$panel_type %in% types &
      classification$panel_spell_balance == "fragmented" &
      classification$panel_gap_size_max <= max_gap_size &
      classification$panel_gap_count <= max_gap_count, , drop = FALSE]
  if (!nrow(eligible)) return(data)

  if (is.null(vars)) {
    vars <- names(data)[vapply(data, is.numeric, logical(1L))]
    vars <- setdiff(vars, c(time, grep("^panel_", names(data), value = TRUE)))
  }
  if (!is.character(vars) || !length(vars) || any(!vars %in% names(data)))
    stop("`vars` must name numeric fields in `data`.")
  if (any(!vapply(data[vars], is.numeric, logical(1L))))
    stop("Every field in `vars` must be numeric.")
  integer_vars <- vars[vapply(data[vars], is.integer, logical(1L))]
  panel_years <- sort(unique(data[[time]][!is.na(data[[time]])]))
  added <- list()

  for (i in seq_len(nrow(eligible))) {
    key <- eligible[[id]][[i]]
    rows <- data[data[[id]] == key & !is.na(data[[time]]), , drop = FALSE]
    rows <- rows[order(rows[[time]]), , drop = FALSE]
    span <- panel_years[panel_years >= min(rows[[time]]) &
                          panel_years <= max(rows[[time]])]
    for (missing_year in setdiff(span, rows[[time]])) {
      prior <- rows[rows[[time]] < missing_year, , drop = FALSE]
      following <- rows[rows[[time]] > missing_year, , drop = FALSE]
      if (!nrow(prior) || !nrow(following)) next
      prior <- prior[which.max(prior[[time]]), , drop = FALSE]
      following <- following[which.min(following[[time]]), , drop = FALSE]
      new <- data[1L, , drop = FALSE]
      new[1, ] <- NA
      new[[id]] <- key
      new[[time]] <- missing_year
      for (variable in vars) {
        endpoints <- c(prior[[variable]], following[[variable]])
        value <- if (all(is.na(endpoints))) NA_real_ else mean(endpoints, na.rm = TRUE)
        if (as_integers && variable %in% integer_vars && !is.na(value))
          value <- as.integer(round(value))
        new[[variable]] <- value
      }
      added[[length(added) + 1L]] <- new
    }
  }
  data$imputed_row <- if ("imputed_row" %in% names(data))
    as.logical(data$imputed_row) else FALSE
  if (length(added)) {
    inserted <- do.call(rbind, added)
    inserted$imputed_row <- TRUE
    data <- rbind(data, inserted)
  }
  data <- data[order(data[[id]], data[[time]]), , drop = FALSE]
  rownames(data) <- NULL
  data
}
