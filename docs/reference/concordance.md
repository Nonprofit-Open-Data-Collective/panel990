# Construct a field-level data-normalization concordance

Creates field-level rules for interpreting blank source values. Data
normalization is distinct from panel imputation: it interprets source
encoding only and never creates missing organization-year rows.

Called with no arguments, `concordance()` returns the package's built-in
concordance for IRS 990 efile variables, derived from the IRS Efile
Master Concordance File (see
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md)).
Supply `field` and `blank_meaning` to build a custom concordance
instead.

## Usage

``` r
concordance(
  field = NULL,
  blank_meaning = NULL,
  forms = "*",
  table = NA_character_,
  notes = NA_character_
)
```

## Arguments

- field:

  Character vector of source field names. `NULL` (the default) returns
  the built-in 990 concordance.

- blank_meaning:

  Character vector containing `"implicit_zero"`, `"implicit_false"`, or
  `"literal_missing"`.

- forms:

  A character vector or list. Each rule supplies the applicable return
  types, such as `c("990", "990EZ")`. Character entries may use `|` as a
  separator. Use `"*"` for every form.

- table:

  Optional source-table name for auditing.

- notes:

  Optional explanatory notes.

## Value

A `concordance` data frame with a list-column named `forms`.

## See also

[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md)
for the underlying data,
[`fields_in_scope()`](https://nonprofit-open-data-collective.github.io/panel990/reference/fields_in_scope.md)
to select fields by form scope, and
[`normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/normalize.md)
to apply the rules.
