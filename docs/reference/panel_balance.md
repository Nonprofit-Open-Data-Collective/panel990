# Trim a panel to a balanced rectangle

Reduces a panel to a balanced set: a block of years in which every
retained organization is observed in every retained year. Balancing
*trims* (drops organizations and/or years) – the complement of
[`panel_complete()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_complete.md),
which fills gaps instead.

## Usage

``` r
panel_balance(
  data,
  years = NULL,
  strategy = c("window", "max_rectangle"),
  min_years = 2L,
  id = "EIN2",
  time = "TAX_YEAR"
)
```

## Arguments

- data:

  A panel data frame.

- years:

  Candidate years. `NULL` uses the full observed range.

- strategy:

  `"window"` (default) or `"max_rectangle"`.

- min_years:

  Minimum number of years a balanced block must span.

- id:

  Panel-ID column.

- time:

  Panel-time column.

## Value

The balanced rows, with a `"balance"` attribute listing the retained
years and the organization keep/drop counts.

## Details

The year window is the trade-off lever. A wide window keeps more years
but fewer organizations; a narrow one keeps more organizations. Two
strategies:

- `"window"`:

  Balance over `years` (or, by default, the full observed range): keep
  only organizations observed in every one of those years, and drop the
  other years.

- `"max_rectangle"`:

  Search contiguous year windows (within `years` if given) and pick the
  one that maximizes retained observations (organizations x years),
  subject to `min_years`.

## See also

[`panel_complete()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_complete.md),
[`panel_filter()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_filter.md),
[`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md).
