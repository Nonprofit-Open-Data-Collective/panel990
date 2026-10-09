# Core 990 financial fields

Money fields eligible for zero-imputation. `"core"` (default) restricts
to the primary financial statements, where a blank on the filed form
unambiguously means zero. `"all"` returns every money field (including
schedules), where a blank may instead mean "schedule not filed".

## Usage

``` r
financial_fields(fields = c("core", "all"), scope = NULL, form = "990")
```

## Arguments

- fields:

  `"core"` (default) or `"all"`.

- scope:

  Optional form-scope filter (`"PC"`, `"PZ"`, `"EZ"`, `"HD"`, `"SG"`, or
  `"PF"`).

- form:

  Form family: `"990"` (default) or `"990PF"`.

## Value

A character vector of `variable_name`s.

## Details

The core statements depend on the form family:

- `"990"`: Part I summary and Parts VIII–XI (revenue, expenses, balance
  sheet, reconciliation).

- `"990PF"`: Parts I–III (revenue and expenses, balance sheet, changes
  in net assets), in every column the form reports (books, net
  investment income, adjusted net income, disbursements; book and fair
  market value).

## See also

[`panel_normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_normalize.md),
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md),
[field_concordance_pf](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance_pf.md).

## Examples

``` r
length(financial_fields())
#> [1] 329
head(financial_fields(form = "990PF"))
#> [1] "PF_01_EXCESS_REV_OVER_EXP_BOOKS" "PF_01_EXP_ACC_FEE_ADJ_NET"      
#> [3] "PF_01_EXP_ACC_FEE_BOOKS"         "PF_01_EXP_ACC_FEE_DISBMT"       
#> [5] "PF_01_EXP_ACC_FEE_NET"           "PF_01_EXP_COMP_OFF_ADJ_NET"     
```
