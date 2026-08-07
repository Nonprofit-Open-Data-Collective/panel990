#' Construct and validate an efile data-normalization concordance
#'
#' @description
#' Creates field-level rules for interpreting blank source values. Data
#' normalization is distinct from panel imputation: it interprets source
#' encoding only and never creates missing organization-year rows.
#'
#' @param field Character vector of source field names.
#' @param blank_meaning Character vector containing `"implicit_zero"`,
#'   `"implicit_false"`, or `"literal_missing"`.
#' @param forms A character vector or list. Each rule supplies the applicable
#'   return types, such as `c("990", "990EZ")`. Character entries may use `|`
#'   as a separator. Use `"*"` for every form.
#' @param table Optional source-table name for auditing.
#' @param notes Optional explanatory notes.
#'
#' @return An `concordance` data frame with a list-column named `forms`.
#' @export
concordance <- function(
    field,
    blank_meaning,
    forms = "*",
    table = NA_character_,
    notes = NA_character_
) {
  n <- length(field)
  if (!is.character(field) || n == 0L || anyNA(field) || any(!nzchar(field)))
    stop("`field` must contain non-empty field names.")

  recycle <- function(x, name) {
    if (length(x) == 1L) rep(x, n) else if (length(x) == n) x else
      stop("`", name, "` must have length 1 or length(field).")
  }

  blank_meaning <- recycle(blank_meaning, "blank_meaning")
  table <- recycle(table, "table")
  notes <- recycle(notes, "notes")
  valid <- c("implicit_zero", "implicit_false", "literal_missing")
  bad <- setdiff(blank_meaning, valid)
  if (length(bad) > 0L)
    stop("Unknown `blank_meaning`: ", paste(bad, collapse = ", "))

  if (is.list(forms)) {
    if (length(forms) == 1L && n > 1L) forms <- rep(forms, n)
    if (length(forms) != n)
      stop("`forms` must have length 1 or length(field).")
    forms <- lapply(forms, function(x) unique(trimws(as.character(x))))
  } else {
    forms <- recycle(forms, "forms")
    forms <- lapply(strsplit(forms, "\\|", fixed = FALSE), trimws)
  }

  if (any(vapply(forms, function(x) length(x) == 0L || anyNA(x) ||
                 any(!nzchar(x)), logical(1L))))
    stop("Every `forms` rule must contain at least one non-empty form.")
  if (anyDuplicated(field))
    stop("Each concordance `field` must appear only once.")

  out <- data.frame(
    field = field,
    blank_meaning = blank_meaning,
    table = table,
    notes = notes,
    stringsAsFactors = FALSE
  )
  out$forms <- forms
  out <- out[, c("field", "blank_meaning", "forms", "table", "notes")]
  class(out) <- c("concordance", class(out))
  out
}
