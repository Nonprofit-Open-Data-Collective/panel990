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
#'     `PZ` (both forms), `HD` (header), `SG` (signature block).}
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
#' Built from the IRS Efile Master Concordance File by
#' `data-raw/build-concordance.R`. Blank meanings are assigned by type: numeric
#' money fields (by XSD type) become `implicit_zero`; checkboxes become
#' `implicit_false`; text, dates, and non-money numerics become
#' `literal_missing`. Conflicting source metadata is resolved by preferring the
#' current schema version, then the most frequent value.
#'
#' @source IRS Efile Master Concordance File, Nonprofit Open Data Collective /
#'   National Center for Charitable Statistics, distributed under the Open Data
#'   Commons Attribution License (ODC-By) v1.0.
#'   <https://github.com/Nonprofit-Open-Data-Collective/irs-efile-master-concordance-file>
#' @seealso [concordance()], [fields_in_scope()]
"field_concordance"
