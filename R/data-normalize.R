#' Normalize efile source encodings using form-aware rules
#'
#' @description
#' Interprets blank values according to a concordance. Applicable financial
#' blanks can become zero and applicable checkbox blanks can become `FALSE`.
#' A rule is never applied to a filing whose form is outside the field's scope.
#'
#' Checkbox values are matched case- and whitespace-insensitively against the
#' accepted vocabulary (`X`/`TRUE`/`T`/`1`/`Y`/`YES` -> `TRUE`;
#' `FALSE`/`F`/`0`/`N`/`NO` -> `FALSE`; blank -> `FALSE`). An in-scope, non-blank
#' value outside that set is coerced to `NA`, but first raises a **warning**
#' naming the field, the number of affected rows, and the unique offending
#' values -- an early signal of an upstream parsing problem. The same counts are
#' recorded in the audit's `unrecognized_count` / `unrecognized_values` columns.
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
  # Accepted checkbox vocabulary (compared case- and whitespace-insensitively).
  checkbox_true  <- c("X", "TRUE", "T", "1", "Y", "YES")
  checkbox_false <- c("FALSE", "F", "0", "N", "NO")
  as_checkbox <- function(x, applicable) {
    raw <- toupper(trimws(as.character(x)))
    value <- rep(NA, length(raw))
    value[applicable & (is.na(raw) | raw == "")] <- FALSE
    value[applicable & raw %in% checkbox_true]  <- TRUE
    value[applicable & raw %in% checkbox_false] <- FALSE
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
    unrecognized_count <- 0L
    unrecognized_values <- NA_character_

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

        # Flag in-scope, non-blank values outside the accepted T/F vocabulary
        # before coercion. These become NA and often signal an upstream parsing
        # error (e.g. a shifted column or a stray delimiter), so warn loudly and
        # record the offending values in the audit.
        raw <- toupper(trimws(as.character(out[[field]])))
        unrec <- applicable & !is_blank(out[[field]]) &
          !(raw %in% c(checkbox_true, checkbox_false))
        unrecognized_count <- sum(unrec)
        if (unrecognized_count > 0L) {
          unrec_vals <- sort(unique(trimws(as.character(out[[field]])[unrec])))
          unrecognized_values <- paste(unrec_vals, collapse = "|")
          shown <- paste(utils::head(unrec_vals, 10L), collapse = ", ")
          if (length(unrec_vals) > 10L)
            shown <- paste0(shown, ", +", length(unrec_vals) - 10L, " more")
          warning(sprintf(
            paste0("normalize(): checkbox field '%s' has %d value(s) in %d ",
                   "unrecognized categor%s outside the accepted T/F set ",
                   "(%s); set to NA. This may indicate an upstream parsing error."),
            field, unrecognized_count, length(unrec_vals),
            if (length(unrec_vals) == 1L) "y" else "ies", shown),
            call. = FALSE)
        }

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
      unrecognized_count = unrecognized_count,
      unrecognized_values = unrecognized_values,
      stringsAsFactors = FALSE
    )
  }

  normalization_audit <- do.call(rbind, audit_rows)
  if (isTRUE(audit))
    attr(out, "normalization_audit") <- normalization_audit
  out
}
