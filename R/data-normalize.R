#' Normalize efile source encodings using form-aware rules
#'
#' @description
#' Interprets blank values according to a concordance. Applicable financial
#' blanks can become zero and applicable checkbox blanks can become `FALSE`.
#' A rule is never applied to a filing whose form is outside the field's scope.
#'
#' This function does not perform statistical normalization and does not impute
#' missing panel years.
#'
#' @param data A data frame containing source fields and a return-type column.
#' @param concordance An object created by [concordance()].
#' @param form Name of the return-type column. Default `"RETURN_TYPE"`.
#' @param audit Logical. Attach a rule-level audit table as the
#'   `"normalization_audit"` attribute. Default `TRUE`.
#' @param strict Logical. If `TRUE`, error when a concordance field is absent;
#'   otherwise report it in the audit. Default `FALSE`.
#'
#' @return A data frame with source blanks normalized only where rules apply.
#' @export
normalize <- function(
    data,
    concordance,
    form = "RETURN_TYPE",
    audit = TRUE,
    strict = FALSE
) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!inherits(concordance, "concordance"))
    stop("`concordance` must be created by concordance().")
  if (!form %in% names(data)) stop("Form column not found: ", form)
  if (!is.logical(audit) || length(audit) != 1L || is.na(audit))
    stop("`audit` must be TRUE or FALSE.")
  if (!is.logical(strict) || length(strict) != 1L || is.na(strict))
    stop("`strict` must be TRUE or FALSE.")

  out <- data
  filing_form <- toupper(trimws(as.character(out[[form]])))
  audit_rows <- vector("list", nrow(concordance))

  is_blank <- function(x) is.na(x) | trimws(as.character(x)) == ""
  as_checkbox <- function(x, applicable) {
    raw <- toupper(trimws(as.character(x)))
    value <- rep(NA, length(raw))
    value[applicable & (is.na(raw) | raw == "")] <- FALSE
    value[applicable & raw %in% c("X", "TRUE", "T", "1", "Y", "YES")] <- TRUE
    value[applicable & raw %in% c("FALSE", "F", "0", "N", "NO")] <- FALSE
    value
  }

  for (i in seq_len(nrow(concordance))) {
    field <- concordance$field[[i]]
    rule <- concordance$blank_meaning[[i]]
    forms <- concordance$forms[[i]]
    present <- field %in% names(out)

    if (!present && isTRUE(strict))
      stop("Concordance field not found in data: ", field)

    applicable <- if ("*" %in% forms) rep(TRUE, nrow(out)) else
      filing_form %in% toupper(forms)
    changed <- 0L
    applicable_blanks <- 0L
    out_of_scope_blanks <- 0L

    if (present) {
      blank <- is_blank(out[[field]])
      applicable_blanks <- sum(blank & applicable)
      out_of_scope_blanks <- sum(blank & !applicable)

      if (rule == "implicit_zero") {
        change <- blank & applicable
        out[[field]][change] <- 0
        changed <- sum(change)
      } else if (rule == "implicit_false") {
        before_blank <- blank & applicable
        out[[field]] <- as_checkbox(out[[field]], applicable)
        changed <- sum(before_blank)
      }
    }

    audit_rows[[i]] <- data.frame(
      field = field,
      blank_meaning = rule,
      field_present = present,
      applicable_rows = sum(applicable),
      applicable_blanks = applicable_blanks,
      values_normalized = changed,
      out_of_scope_blanks = out_of_scope_blanks,
      stringsAsFactors = FALSE
    )
  }

  normalization_audit <- do.call(rbind, audit_rows)
  if (isTRUE(audit))
    attr(out, "normalization_audit") <- normalization_audit
  out
}
