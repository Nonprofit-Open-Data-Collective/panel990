# Field normalization concordance for IRS 990PF efile variables

The 990PF counterpart of
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md):
one row per research-database variable in the separate 990PF release
(`efilepf_`), covering the `PF-*` tables and the release's copies of the
shared header (`F9-P00`), signature (`F9-P02`), and Schedule B (`SB-*`)
tables. It is the basis for `concordance(form = "990PF")`.

## Usage

``` r
field_concordance_pf
```

## Format

A data frame with the same columns as
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md).
Here `variable_scope` is `PF` for every form field (Schedule B included,
since in this release it is filed with a 990PF), or `HD`/`SG` for header
and signature fields; `forms` is accordingly `"990PF"` or `"*"`.

## Source

concordance990, Nonprofit Open Data Collective / National Center for
Charitable Statistics, distributed under the Open Data Commons
Attribution License (ODC-By) v1.0.
<https://github.com/Nonprofit-Open-Data-Collective/concordance990>

## Details

Built by `data-raw/build-concordance.R` the same way as
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md),
from the 990PF database of concordance990:
`concordance990::concordance(form = "F990PF")`, which maps shared
attachments such as the reasonable-cause explanation to their 990PF
variables, and the flags of `concordance990::data_dictionary("F990PF")`.
Every numeric field in the 990PF financial statements (Parts I-III) is a
money field. A numeric field whose source rows carry no XSD type is
treated conservatively as `literal_missing` until concordance990 types
it.

## See also

[`concordance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/concordance.md),
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md),
[`financial_fields()`](https://nonprofit-open-data-collective.github.io/panel990/reference/financial_fields.md)
