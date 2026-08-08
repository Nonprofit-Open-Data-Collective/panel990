#' Select panel organizations by membership type
#'
#' Keeps the rows of organizations whose panel classification matches the given
#' criteria. The classification is computed from `data` automatically unless a
#' precomputed one is supplied.
#'
#' @param data A panel data frame.
#' @param panel_type Panel types to keep (`persistent`, `entrant`, `exit`,
#'   `transient`, `empty`). `NULL` keeps all types.
#' @param spell Spell continuity values to keep (`seamless`, `segmented`).
#'   `NULL` keeps all.
#' @param min_obs Minimum number of observed years per organization. `NULL`
#'   applies no minimum.
#' @param classification Optional precomputed classification (from
#'   [panel_describe()]); computed from `data` when `NULL`.
#' @param time Name of the panel-time column.
#' @param id Name of the panel-ID column.
#' @return The rows of `data` for the selected organizations.
#' @seealso [panel_describe()], [panel_label()].
#' @export
panel_filter <- function(data, panel_type = NULL, spell = NULL, min_obs = NULL,
                         classification = NULL, time = "TAX_YEAR", id = "EIN2") {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!id %in% names(data)) stop("ID column not found: ", id)
  data <- as.data.frame(data)
  cls <- .panel_resolve_classification(classification, data, time, id)

  validate <- function(x, valid, arg) {
    if (!is.character(x) || !length(x) || anyNA(x))
      stop("`", arg, "` must be a non-empty character vector.")
    bad <- setdiff(x, valid)
    if (length(bad)) stop("Unknown `", arg, "`: ", paste(bad, collapse = ", "))
    unique(x)
  }
  sel <- rep(TRUE, nrow(cls))
  if (!is.null(panel_type)) {
    panel_type <- validate(panel_type, .PANEL_TYPES, "panel_type")
    sel <- sel & cls$panel_type %in% panel_type
  }
  if (!is.null(spell)) {
    spell <- validate(spell, .PANEL_SPELL, "spell")
    sel <- sel & cls$panel_spell %in% spell
  }
  if (!is.null(min_obs)) sel <- sel & cls$panel_year_count >= min_obs

  ids <- cls[[id]][sel & !is.na(sel)]
  out <- data[data[[id]] %in% ids, , drop = FALSE]
  rownames(out) <- NULL
  out
}
