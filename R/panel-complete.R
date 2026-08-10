#' Complete panel spans by filling interior gaps
#'
#' Turns every `segmented` organization into a `seamless` one by inserting the
#' missing interior years and filling their numeric fields, so each
#' organization is observed continuously across its own span. This is the
#' researcher-facing wrapper over [panel_impute()]: it fills gaps for **all**
#' boundary types (not just panel-spanning organizations) and interpolates by
#' default.
#'
#' Completion never extends past an organization's observed span -- it fills the
#' holes, it does not extrapolate to the panel edges. Inserted rows are flagged
#' with `imputed_row`.
#'
#' @param data A panel data frame.
#' @param method Fill method: `"interpolate"` (linear, the default), `"mean"`,
#'   `"locf"` (carry forward), or `"nocb"` (carry backward).
#' @param types Panel types eligible for completion. Defaults to every span
#'   type; only `segmented` organizations have interior years to fill.
#' @param max_gap_size,max_gap_count Optional gap-size / gap-count limits per
#'   organization.
#' @param vars Numeric variables to fill; `NULL` selects numeric non-key fields.
#' @param time Panel-time column.
#' @param id Panel-ID column.
#' @param as_integers Round filled values for originally integer fields.
#' @param classification Optional classification from [panel_describe()].
#' @return The panel with interior gaps filled; inserted rows carry
#'   `imputed_row = TRUE`.
#' @seealso [panel_impute()], [panel_describe()].
#' @export
panel_complete <- function(
    data,
    method = c("interpolate", "mean", "locf", "nocb"),
    types = c("persistent", "entrant", "exit", "transient"),
    max_gap_size = Inf, max_gap_count = Inf, vars = NULL,
    time = "TAX_YEAR", id = "EIN2", as_integers = FALSE,
    classification = NULL
) {
  method <- match.arg(method)
  panel_impute(
    data, classification = classification, types = types, method = method,
    max_gap_size = max_gap_size, max_gap_count = max_gap_count, vars = vars,
    time = time, id = id, as_integers = as_integers
  )
}
