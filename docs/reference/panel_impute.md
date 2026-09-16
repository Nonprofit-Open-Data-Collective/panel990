# Insert and fill missing panel years

Inserts missing years within eligible observed ID spans and fills
numeric fields from the nearest observations bracketing each gap. See
[`panel_complete()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_complete.md)
for the researcher-facing wrapper that completes every segmented span.

## Usage

``` r
panel_impute(
  data,
  classification = NULL,
  types = "persistent",
  method = c("mean", "interpolate", "locf", "nocb"),
  max_gap_size = Inf,
  max_gap_count = Inf,
  vars = NULL,
  time = "TAX_YEAR",
  id = "EIN2",
  as_integers = FALSE
)
```

## Arguments

- data:

  A panel data frame.

- classification:

  Optional classification from
  [`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md).

- types:

  Panel types eligible for imputation. Default `"persistent"` (the
  panel-spanning type); only `segmented` organizations actually have
  interior years to fill.

- method:

  Fill method: `"mean"` (average of the bracketing observations),
  `"interpolate"` (linear between them), `"locf"` (carry the prior value
  forward), or `"nocb"` (carry the next value backward).

- max_gap_size:

  Maximum single gap length.

- max_gap_count:

  Maximum number of gaps per ID.

- vars:

  Numeric variables to fill; `NULL` selects numeric non-key fields.

- time:

  Panel-time column.

- id:

  Panel-ID column.

- as_integers:

  Round values for originally integer fields.

## Value

A panel with inserted rows identified by `imputed_row`.
