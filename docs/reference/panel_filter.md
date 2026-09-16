# Select panel organizations by membership type

Keeps the rows of organizations whose panel classification matches the
given criteria. The classification is computed from `data` automatically
unless a precomputed one is supplied.

## Usage

``` r
panel_filter(x, ...)

# S3 method for class 'data.frame'
panel_filter(
  x,
  panel_type = NULL,
  spell = NULL,
  min_obs = NULL,
  classification = NULL,
  time = "TAX_YEAR",
  id = "EIN2",
  ...
)

# S3 method for class 'panel'
panel_filter(
  x,
  panel_type = NULL,
  spell = NULL,
  min_obs = NULL,
  assume_fresh = FALSE,
  ...
)
```

## Arguments

- x:

  A panel data frame or a
  [panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md).

- ...:

  Passed to methods.

- panel_type:

  Panel types to keep (`persistent`, `entrant`, `exit`, `transient`,
  `empty`). `NULL` keeps all types.

- spell:

  Spell continuity values to keep (`seamless`, `segmented`). `NULL`
  keeps all.

- min_obs:

  Minimum number of observed years per organization. `NULL` applies no
  minimum.

- classification:

  Optional precomputed classification (from
  [`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md));
  computed from `x` when `NULL`.

- time:

  Name of the panel-time column.

- id:

  Name of the panel-ID column.

- assume_fresh:

  For a panel, skip the label-freshness check. Default `FALSE`.

## Value

For a data frame, the selected rows; for a panel, the panel.

## Details

Given a
[panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md),
the labels are refreshed first if they are stale (unless
`assume_fresh = TRUE`), the selection is recorded as a rule, the step is
logged, and the panel is returned.

## See also

[`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md),
[`panel_label()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_label.md).
