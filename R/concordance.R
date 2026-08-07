#' Construct a field-level data-normalization concordance
#'
#' @description
#' Creates field-level rules for interpreting blank source values. Data
#' normalization is distinct from panel imputation: it interprets source
#' encoding only and never creates missing organization-year rows.
#'
#' Called with no arguments, `concordance()` returns the package's built-in
#' concordance for IRS 990 efile variables, derived from the IRS Efile Master
#' Concordance File (see [field_concordance]). Supply `field` and
#' `blank_meaning` to build a custom concordance instead.
#'
#' @param field Character vector of source field names. `NULL` (the default)
#'   returns the built-in 990 concordance.
#' @param blank_meaning Character vector containing `"implicit_zero"`,
#'   `"implicit_false"`, or `"literal_missing"`.
#' @param forms A character vector or list. Each rule supplies the applicable
#'   return types, such as `c("990", "990EZ")`. Character entries may use `|`
#'   as a separator. Use `"*"` for every form.
#' @param table Optional source-table name for auditing.
#' @param notes Optional explanatory notes.
#'
#' @return A `concordance` data frame with a list-column named `forms`.
#' @seealso [field_concordance] for the underlying data, [fields_in_scope()] to
#'   select fields by form scope, and [normalize()] to apply the rules.
#' @export
concordance <- function(
    field = NULL,
    blank_meaning = NULL,
    forms = "*",
    table = NA_character_,
    notes = NA_character_
) {
  if (is.null(field)) {
    fc <- .field_concordance()
    return(.concordance_build(
      field = fc$variable_name,
      blank_meaning = fc$blank_meaning,
      forms = fc$forms,
      table = fc$rdb_table,
      notes = fc$description
    ))
  }
  .concordance_build(field, blank_meaning, forms, table, notes)
}

.concordance_build <- function(
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

# Load the bundled field concordance without relying on lazy-data binding,
# keeping R CMD check free of "no visible binding" notes.
.field_concordance <- function() {
  env <- new.env(parent = emptyenv())
  utils::data("field_concordance", package = "panel990", envir = env)
  env$field_concordance
}

#' Select efile fields by form scope
#'
#' Returns the variable names present on a given return form, using the built-in
#' [field_concordance]. Useful for restricting a panel to fields available on
#' both the full 990 and the 990EZ, which avoids conflating a structural blank
#' (field absent from the 990EZ) with a reported blank.
#'
#' @param form One of `"both"` (present on the full 990 and the 990EZ),
#'   `"990"` (present on the full 990), `"990EZ"` (present on the 990EZ), or
#'   `"all"`. Header and signature fields count as present on every form.
#' @return A character vector of `variable_name` values.
#' @seealso [concordance()], [field_concordance].
#' @export
fields_in_scope <- function(form = c("both", "990", "990EZ", "all")) {
  form <- match.arg(form)
  fc <- .field_concordance()
  keep <- switch(
    form,
    both    = fc$variable_scope %in% c("PZ", "HD", "SG"),
    "990"   = fc$variable_scope %in% c("PC", "PZ", "HD", "SG"),
    "990EZ" = fc$variable_scope %in% c("EZ", "PZ", "HD", "SG"),
    all     = rep(TRUE, nrow(fc))
  )
  sort(unique(fc$variable_name[keep]))
}
