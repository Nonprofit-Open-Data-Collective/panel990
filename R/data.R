#' Field-scope and normalization concordance for IRS 990 efile variables
#'
#' One row per research-database variable produced by the ef2 processing of the
#' IRS 990 efile XML files. It records each field's form scope and the intended
#' interpretation of a blank source value, and is the basis for the built-in
#' concordance returned by [concordance()].
#'
#' @format A data frame with one row per `variable_name` and the columns:
#' \describe{
#'   \item{variable_name}{Research-database field name (matches ef2 table columns).}
#'   \item{description}{Field description from the 990 forms.}
#'   \item{variable_scope}{Form scope: `PC` (full 990 only), `EZ` (990EZ only),
#'     `PZ` (both forms), `HD` (header), `SG` (signature block). For main-form
#'     fields this is derived from where the variable's xpaths live
#'     (`IRS990/`, `IRS990EZ/`, or both) across all schema versions.}
#'   \item{scope_mcf}{Scope as flagged in the source concordance, kept for
#'     audit. It marks some single-form fields `PZ` (e.g. Part X cash and
#'     investments, which the 990EZ reports only as a combined line).}
#'   \item{form_type}{Originating form of the mapped xpath.}
#'   \item{data_type_simple}{Simplified R type: `numeric`, `checkbox`, `text`, `date`.}
#'   \item{data_type_xsd}{XSD schema type (e.g. `USAmountType`), used to detect money fields.}
#'   \item{money_field}{`TRUE` when a numeric field holds a US dollar amount.}
#'   \item{blank_meaning}{How to read an in-scope blank: `implicit_zero`
#'     (blank money amount is 0), `implicit_false` (blank checkbox is `FALSE`),
#'     or `literal_missing` (text, dates, and non-money numerics such as counts,
#'     ratios, and identifiers).}
#'   \item{forms}{Applicable return forms as a `|`-separated string
#'     (`"990"`, `"990EZ"`, `"990|990EZ"`, or `"*"`), derived from `variable_scope`.}
#'   \item{rdb_table}{Primary ef2 table for the field.}
#'   \item{rdb_tables_all}{All ef2 tables containing the field (`;`-separated).}
#'   \item{rdb_relationship}{Table cardinality: `ONE` (1x1) or `MANY` (1xm).}
#'   \item{current_version}{`TRUE` when the field appears in a current XSD schema.}
#'   \item{n_xpaths}{Number of source xpath rows collapsed into this variable.}
#'   \item{scope_conflict, type_conflict}{`TRUE` when source rows disagreed on
#'     scope or type and a value was chosen by the build rule.}
#' }
#'
#' @details
#' Built from the concordance990 xpath concordance (the successor to the IRS
#' Efile Master Concordance File) by `data-raw/build-concordance.R`, keeping
#' the 990/990EZ tables and excluding the separate 990PF (`PF-*`) tables. Blank meanings are assigned by type: numeric
#' money fields (by XSD type) become `implicit_zero`; checkboxes become
#' `implicit_false`; text, dates, and non-money numerics become
#' `literal_missing`. Conflicting source metadata is resolved by preferring the
#' current schema version, then the most frequent value.
#'
#' @source concordance990, Nonprofit Open Data Collective / National Center
#'   for Charitable Statistics, distributed under the Open Data Commons
#'   Attribution License (ODC-By) v1.0.
#'   <https://github.com/Nonprofit-Open-Data-Collective/concordance990>
#' @seealso [concordance()], [fields_in_scope()], [field_concordance_pf]
"field_concordance"

#' Field normalization concordance for IRS 990PF efile variables
#'
#' The 990PF counterpart of [field_concordance]: one row per research-database
#' variable in the separate 990PF release (`efilepf_`), covering the `PF-*`
#' tables and the release's copies of the shared header (`F9-P00`), signature
#' (`F9-P02`), and Schedule B (`SB-*`) tables. It is the basis for
#' `concordance(form = "990PF")`.
#'
#' @format A data frame with the same columns as [field_concordance]. Here
#'   `variable_scope` is `PF` for every form field (Schedule B included, since
#'   in this release it is filed with a 990PF), or `HD`/`SG` for header and
#'   signature fields; `forms` is accordingly `"990PF"` or `"*"`.
#'
#' @details
#' Built by `data-raw/build-concordance.R` from the same concordance990 source
#' and with the same type, money, and blank-meaning rules as
#' [field_concordance]. Money fields are detected from the XSD amount types;
#' every numeric field in the 990PF financial statements (Parts I-III) is a
#' money field. Some numeric fields whose source rows carry no XSD type -- a
#' handful of supporting-statement amounts among them -- are treated
#' conservatively as `literal_missing`.
#'
#' @source concordance990, Nonprofit Open Data Collective / National Center
#'   for Charitable Statistics, distributed under the Open Data Commons
#'   Attribution License (ODC-By) v1.0.
#'   <https://github.com/Nonprofit-Open-Data-Collective/concordance990>
#' @seealso [concordance()], [field_concordance], [financial_fields()]
"field_concordance_pf"

#' Accounting-identity registry for IRS 990 and 990PF financial fields
#'
#' The linear accounting identities that hold among the financial fields of
#' the full Form 990 -- the revenue (Part VIII), functional-expenses (Part IX),
#' and balance-sheet (Part X) sections -- and of the Form 990PF financial
#' statements (Parts I-III): column splits, subtotals, net-of-expense lines,
#' grand totals, the balance-sheet equation, and the ties between parts. Each
#' identity is a linear combination of fields that must equal zero; the
#' registry is stored in long form and drives [accounting_check()] and
#' [reconcile()]. An identity is evaluated only when all of its fields are
#' columns of the data, so 990 identities never apply to a 990PF panel and the
#' reverse.
#'
#' @format A data frame with one row per (identity, variable):
#' \describe{
#'   \item{identity}{Identity name, e.g. `rev_contributions_subtotal`. 990PF
#'     identities are prefixed `pf_`.}
#'   \item{section}{`"revenue"`, `"expenses"`, `"balance_sheet"`, or (990PF
#'     Part III) `"net_assets"`.}
#'   \item{form_scope}{Form the identity applies to: `"PC"` (the full 990) or
#'     `"PF"` (the 990PF).}
#'   \item{type}{`column`, `subtotal`, `net`, `grand_total`, `balance`, or
#'     `tie` (an equality between parts of the 990PF).}
#'   \item{description}{Human-readable statement of the identity.}
#'   \item{variable}{An ef2 `variable_name` appearing in the identity.}
#'   \item{coefficient}{Its coefficient (identity holds when the weighted sum is 0).}
#' }
#'
#' @details
#' A curated, high-confidence set built by
#' `data-raw/build-accounting-identities.R`, with every variable validated
#' against the concordance for its form:
#' \itemize{
#'   \item Form 990: 58 identities over 214 fields of [field_concordance] (21
#'     revenue, 32 expense, 5 balance-sheet). Only identities whose structure
#'     is unambiguous from the ef2 naming are included; vertical sums that
#'     would require 1xm write-in detail (expense line 24) or that hit
#'     form-version variants (balance-sheet cash lines) are deliberately
#'     omitted.
#'   \item Form 990PF: 29 identities over 174 fields of [field_concordance_pf]
#'     (5 revenue, 8 expense, 11 balance-sheet, 5 net-asset), each holding for
#'     at least 98% of 2021-2022 filings after [panel_normalize()]. Net
#'     investment income and adjusted net income are omitted because the form
#'     floors them at zero.
#' }
#'
#' @seealso [accounting_check()], [reconcile()]
"accounting_identities"
