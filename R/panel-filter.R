#' Select panel organizations by membership type
#'
#' Keeps the rows of organizations whose panel classification matches the given
#' criteria. The classification is computed from `data` automatically unless a
#' precomputed one is supplied.
#'
#' Given a [panel][as_panel], the labels are refreshed first if they are stale
#' (unless `assume_fresh = TRUE`), the selection is recorded as a rule, the step
#' is logged, and the panel is returned.
#'
#' @param x A panel data frame or a [panel][as_panel].
#' @param panel_type Panel types to keep (`persistent`, `entrant`, `exit`,
#'   `transient`, `empty`). `NULL` keeps all types.
#' @param spell Spell continuity values to keep (`seamless`, `segmented`).
#'   `NULL` keeps all.
#' @param min_obs Minimum number of observed years per organization. `NULL`
#'   applies no minimum.
#' @param classification Optional precomputed classification (from
#'   [panel_describe()]); computed from `x` when `NULL`.
#' @param time Name of the panel-time column.
#' @param id Name of the panel-ID column.
#' @param assume_fresh For a panel, skip the label-freshness check. Default
#'   `FALSE`.
#' @param ... Passed to methods.
#' @return For a data frame, the selected rows; for a panel, the panel.
#' @seealso [panel_describe()], [panel_label()].
#' @export
panel_filter <- function(x, ...) UseMethod("panel_filter")

#' @rdname panel_filter
#' @export
panel_filter.data.frame <- function(x, panel_type = NULL, spell = NULL,
                                    min_obs = NULL, classification = NULL,
                                    time = "TAX_YEAR", id = "EIN2", ...) {
  data <- x
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

#' @rdname panel_filter
#' @export
panel_filter.panel <- function(x, panel_type = NULL, spell = NULL,
                               min_obs = NULL, assume_fresh = FALSE, ...) {
  entity <- .panel_entity(x); time <- .panel_time(x)
  if (!isTRUE(x$fresh) && !isTRUE(assume_fresh))
    x <- panel_describe(x, print = FALSE)     # refresh stale labels

  before <- dim(x$data)
  if (!is.null(panel_type))
    x$sfw <- .panel_govern_filter(x$sfw, "panel_type", panel_type)
  if (!is.null(spell))
    x$sfw <- .panel_govern_filter(x$sfw, "panel_spell", spell)

  x$data <- panel_filter.data.frame(x$data, panel_type = panel_type,
                                    spell = spell, min_obs = min_obs,
                                    time = time, id = entity)
  detail <- paste(c(
    if (!is.null(panel_type)) paste0("type=", paste(panel_type, collapse = ",")),
    if (!is.null(spell)) paste0("spell=", paste(spell, collapse = ",")),
    if (!is.null(min_obs)) paste0("min_obs=", min_obs)), collapse = "; ")
  x$sfw <- .panel_receipt(x$sfw, "panel_filter", detail, before, dim(x$data))
  invisible(x)
}
