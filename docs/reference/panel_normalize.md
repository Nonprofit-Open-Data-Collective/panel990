# Normalize blank financial fields to zero, form-scoped

Interprets blank core financial cells as zero, respecting form scope and
protecting non-filer rows:

- both-form (`PZ`) fields are zeroed for every 990 and 990EZ filer;

- full-990-only (`PC`) fields are zeroed only for full 990 filers (they
  are out of scope on the 990EZ and left `NA`);

- 990PF (`PF`) fields are zeroed only for 990PF filers, so the same call
  serves a panel from either release (see
  [`panelize_pf()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize_pf.md));

- rows with **no** financial data at all (a non-filer / shell record)
  are left untouched – no fabricated zeros.

## Usage

``` r
panel_normalize(
  data,
  fields = c("core", "all"),
  form = "RETURN_TYPE",
  verbose = TRUE
)
```

## Arguments

- data:

  A data frame of 990 fields, or a
  [panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md).

- fields:

  `"core"` (default) or `"all"` (see
  [`financial_fields()`](https://nonprofit-open-data-collective.github.io/panel990/reference/financial_fields.md)).

- form:

  Name of the return-type column. Default `"RETURN_TYPE"`.

- verbose:

  Print a summary.

## Value

`data` with in-scope blank financial fields set to zero; a
`"normalize_audit"` attribute records what was changed.

## Details

By default only the curated core financial statements are touched; text,
dates, counts, and checkboxes are left to
[`normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/normalize.md).
Given a
[panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md)
the step is logged.

## See also

[`financial_fields()`](https://nonprofit-open-data-collective.github.io/panel990/reference/financial_fields.md),
[`normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/normalize.md),
[`panel_impute()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_impute.md).
