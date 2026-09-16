# Label rows with panel membership

Appends the per-organization panel classification (`panel_type`,
`panel_spell`, first/last/count and gap metrics) to every input row,
preserving row order.

## Usage

``` r
panel_label(data, time = "TAX_YEAR", id = "EIN2", classification = NULL)
```

## Arguments

- data:

  A panel data frame.

- time:

  Name of the panel-time column.

- id:

  Name of the panel-ID column.

- classification:

  Optional precomputed classification (from
  [`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md));
  computed from `data` when `NULL`.

## Value

`data` with panel classification columns appended.

## See also

[`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md),
[`panel_filter()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_filter.md).
