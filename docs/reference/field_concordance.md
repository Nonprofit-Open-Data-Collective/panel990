# Field-scope and normalization concordance for IRS 990 efile variables

One row per research-database variable produced by the ef2 processing of
the IRS 990 efile XML files. It records each field's form scope and the
intended interpretation of a blank source value, and is the basis for
the built-in concordance returned by
[`concordance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/concordance.md).

## Usage

``` r
field_concordance
```

## Format

A data frame with one row per `variable_name` and the columns:

- variable_name:

  Research-database field name (matches ef2 table columns).

- description:

  Field description from the 990 forms.

- variable_scope:

  Form scope: `PC` (full 990 only), `EZ` (990EZ only), `PZ` (both
  forms), `HD` (header), `SG` (signature block). For main-form fields
  this is derived from where the variable's xpaths live (`IRS990/`,
  `IRS990EZ/`, or both) across all schema versions.

- scope_mcf:

  Scope as flagged in the source concordance, kept for audit. It marks
  some single-form fields `PZ` (e.g. Part X cash and investments, which
  the 990EZ reports only as a combined line).

- form_type:

  Originating form of the mapped xpath.

- data_type_simple:

  Simplified R type: `numeric`, `checkbox`, `text`, `date`.

- data_type_xsd:

  XSD schema type (e.g. `USAmountType`), used to detect money fields.

- money_field:

  `TRUE` when a numeric field holds a US dollar amount.

- blank_meaning:

  How to read an in-scope blank: `implicit_zero` (blank money amount is
  0), `implicit_false` (blank checkbox is `FALSE`), or `literal_missing`
  (text, dates, and non-money numerics such as counts, ratios, and
  identifiers).

- forms:

  Applicable return forms as a `|`-separated string (`"990"`, `"990EZ"`,
  `"990|990EZ"`, or `"*"`), derived from `variable_scope`.

- rdb_table:

  Primary ef2 table for the field.

- rdb_tables_all:

  All ef2 tables containing the field (`;`-separated).

- rdb_relationship:

  Table cardinality: `ONE` (1x1) or `MANY` (1xm).

- current_version:

  `TRUE` when the field appears in a current XSD schema.

- n_xpaths:

  Number of source xpath rows collapsed into this variable.

- scope_conflict, type_conflict:

  `TRUE` when source rows disagreed on scope or type and a value was
  chosen by the build rule.

## Source

concordance990, Nonprofit Open Data Collective / National Center for
Charitable Statistics, distributed under the Open Data Commons
Attribution License (ODC-By) v1.0.
<https://github.com/Nonprofit-Open-Data-Collective/concordance990>

## Details

Built by `data-raw/build-concordance.R` from the concordance990 package
(the successor to the IRS Efile Master Concordance File): the xpaths of
the 990/990EZ database, `concordance990::concordance(form = "F990")`,
and each variable's money flag and blank meaning from
`concordance990::data_dictionary("F990")`, so panel990 reads blank cells
by the same rule as the other partner packages: numeric money fields (by
XSD type) are `implicit_zero`; checkboxes are `implicit_false`; text,
dates, and non-money numerics are `literal_missing`. Other conflicting
source metadata is resolved by preferring the current schema version,
then the most frequent value.

## See also

[`concordance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/concordance.md),
[`fields_in_scope()`](https://nonprofit-open-data-collective.github.io/panel990/reference/fields_in_scope.md),
[field_concordance_pf](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance_pf.md)
