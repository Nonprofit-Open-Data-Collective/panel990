#' Filter a panel by type and spell balance
#'
#' @param data A panel data frame.
#' @param classification A per-ID classification, a classification summary, or
#'   data with appended classification columns.
#' @param keep Panel types to retain.
#' @param spell_balance Spell-balance values to retain.
#' @param id Name of the ID column.
#' @return Filtered input rows.
#' @export
panel_filter <- function(
    data,
    classification,
    keep = .EFILE_PANEL_TYPES,
    spell_balance = .EFILE_SPELL_BALANCE,
    id = "EIN2"
) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!id %in% names(data)) stop("ID column not found: ", id)
  data <- as.data.frame(data)
  if (!is.data.frame(classification))
    stop("`classification` must be a data frame.")
  attached <- attr(classification, "classification", exact = TRUE)
  if (!is.null(attached)) classification <- attached
  required <- c(id, "panel_type", "panel_spell_balance")
  missing <- setdiff(required, names(classification))
  if (length(missing))
    stop("Classification missing column(s): ", paste(missing, collapse = ", "))

  validate <- function(x, valid, arg) {
    if (!is.character(x) || !length(x) || anyNA(x))
      stop("`", arg, "` must be a non-empty character vector.")
    bad <- setdiff(x, valid)
    if (length(bad)) stop("Unknown `", arg, "`: ", paste(bad, collapse = ", "))
    unique(x)
  }
  keep <- validate(keep, .EFILE_PANEL_TYPES, "keep")
  spell_balance <- validate(spell_balance, .EFILE_SPELL_BALANCE,
                            "spell_balance")
  selected <- classification$panel_type %in% keep &
    classification$panel_spell_balance %in% spell_balance
  ids <- classification[[id]][selected & !is.na(selected)]
  data[data[[id]] %in% ids, , drop = FALSE]
}
