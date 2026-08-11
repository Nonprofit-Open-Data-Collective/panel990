# Financial normalization: interpret blank core-990 financial fields as zero,
# form-scoped, protecting non-filer (all-missing) rows. The researcher-facing
# counterpart to fiscal's sanitize_financials(); the general blank-interpretation
# engine is normalize() + concordance().

.pn_is_blank <- function(x) {
  if (is.numeric(x)) return(is.na(x))
  is.na(x) | trimws(as.character(x)) == ""
}

# 990EZ filers: RETURN_TYPE == "990EZ", or (fallback) Part I revenue present
# while the Part VIII total is absent.
.pn_detect_ez <- function(data, form) {
  if (form %in% names(data))
    return(toupper(trimws(as.character(data[[form]]))) == "990EZ")
  has1 <- "F9_01_REV_TOT_CY" %in% names(data)
  has8 <- "F9_08_REV_TOT_TOT" %in% names(data)
  if (has1 && has8)
    return(!is.na(data[["F9_01_REV_TOT_CY"]]) & is.na(data[["F9_08_REV_TOT_TOT"]]))
  rep(FALSE, nrow(data))
}

#' Core 990 financial fields
#'
#' Money fields eligible for zero-imputation. `"core"` (default) restricts to the
#' primary financial statements -- Part I summary and Parts VIII--XI (revenue,
#' expenses, balance sheet, reconciliation) -- where a blank on the filed form
#' unambiguously means zero. `"all"` returns every money field (including
#' schedules), where a blank may instead mean "schedule not filed".
#'
#' @param fields `"core"` (default) or `"all"`.
#' @param scope Optional form-scope filter (`"PC"`, `"PZ"`, `"EZ"`, `"HD"`,
#'   `"SG"`).
#' @return A character vector of `variable_name`s.
#' @seealso [panel_normalize()], [field_concordance].
#' @export
financial_fields <- function(fields = c("core", "all"), scope = NULL) {
  fields <- match.arg(fields)
  fc <- .field_concordance()
  keep <- fc$money_field
  if (fields == "core") keep <- keep & grepl("^F9-P(01|08|09|10|11)-", fc$rdb_table)
  if (!is.null(scope)) keep <- keep & fc$variable_scope %in% scope
  fc$variable_name[keep]
}

#' Normalize blank financial fields to zero, form-scoped
#'
#' Interprets blank core-990 financial cells as zero, respecting form scope and
#' protecting non-filer rows:
#' \itemize{
#'   \item both-form (`PZ`) fields are zeroed for every filer;
#'   \item full-990-only (`PC`) fields are zeroed only for non-990EZ filers (they
#'     are out of scope on the 990EZ and left `NA`);
#'   \item rows with **no** financial data at all (a non-filer / shell record)
#'     are left untouched -- no fabricated zeros.
#' }
#'
#' By default only the curated core financial statements are touched; text,
#' dates, counts, and checkboxes are left to [normalize()]. Given a
#' [panel][as_panel] the step is logged.
#'
#' @param data A data frame of 990 fields, or a [panel][as_panel].
#' @param fields `"core"` (default) or `"all"` (see [financial_fields()]).
#' @param form Name of the return-type column. Default `"RETURN_TYPE"`.
#' @param verbose Print a summary.
#' @return `data` with in-scope blank financial fields set to zero; a
#'   `"normalize_audit"` attribute records what was changed.
#' @seealso [financial_fields()], [normalize()], [panel_impute()].
#' @export
panel_normalize <- function(data, fields = c("core", "all"),
                            form = "RETURN_TYPE", verbose = TRUE) {
  if (is_panel(data)) {
    a <- as.list(environment()); a$data <- NULL
    return(do.call(.panel_apply,
      c(list(data, panel_normalize, "panel_normalize"),
        list(stale = FALSE, id_arg = NULL, time_arg = NULL), a)))
  }
  fields <- match.arg(fields)
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  data <- as.data.frame(data)
  ez <- .pn_detect_ez(data, form)

  pz  <- intersect(financial_fields(fields, scope = c("PZ", "HD", "SG")), names(data))
  pc  <- intersect(financial_fields(fields, scope = "PC"), names(data))
  ezf <- intersect(financial_fields(fields, scope = "EZ"), names(data))

  present <- unique(c(pz, pc, ezf))
  all_na <- if (length(present))
    rowSums(!is.na(data[, present, drop = FALSE])) == 0 else rep(FALSE, nrow(data))

  n_zeroed <- 0L
  zero_group <- function(vars, applicable) {
    for (v in vars) {
      r <- .pn_is_blank(data[[v]]) & applicable & !all_na
      if (any(r)) { data[r, v] <- 0; n_zeroed <- n_zeroed + sum(r) }
    }
    data
  }
  data <- zero_group(pz, rep(TRUE, nrow(data)))
  data <- zero_group(pc, !ez)
  data <- zero_group(ezf, ez)

  attr(data, "normalize_audit") <- list(
    fields = fields, financial_fields = length(present), values_zeroed = n_zeroed,
    all_missing_rows = sum(all_na), ez_rows = sum(ez))
  if (verbose)
    message("panel_normalize: zeroed ", n_zeroed, " blank(s) across ",
            length(present), " financial field(s); ", sum(all_na),
            " all-missing row(s) left untouched.")
  data
}
