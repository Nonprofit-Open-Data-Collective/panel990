# Core 990 financial fields

Money fields eligible for zero-imputation. `"core"` (default) restricts
to the primary financial statements – Part I summary and Parts VIII–XI
(revenue, expenses, balance sheet, reconciliation) – where a blank on
the filed form unambiguously means zero. `"all"` returns every money
field (including schedules), where a blank may instead mean "schedule
not filed".

## Usage

``` r
financial_fields(fields = c("core", "all"), scope = NULL)
```

## Arguments

- fields:

  `"core"` (default) or `"all"`.

- scope:

  Optional form-scope filter (`"PC"`, `"PZ"`, `"EZ"`, `"HD"`, `"SG"`).

## Value

A character vector of `variable_name`s.

## See also

[`panel_normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_normalize.md),
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md).
