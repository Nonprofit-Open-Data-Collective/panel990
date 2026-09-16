# Describe panel coverage and membership

Classifies each organization on two axes – `panel_type` (boundary:
`persistent`, `entrant`, `exit`, `transient`, `empty`) and `panel_spell`
(continuity: `seamless`, `segmented`) – and summarizes the panel. See
[`panel_label()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_label.md)
to append the classification to rows and
[`panel_filter()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_filter.md)
to select organizations.

## Usage

``` r
panel_describe(x, ...)

# S3 method for class 'data.frame'
panel_describe(
  x,
  time = "TAX_YEAR",
  id = "EIN2",
  by_year = TRUE,
  print = TRUE,
  ...
)

# S3 method for class 'panel'
panel_describe(x, print = TRUE, ...)
```

## Arguments

- x:

  A panel data frame or a
  [panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md).

- ...:

  Passed to methods.

- time:

  Name of the panel-time column.

- id:

  Name of the panel-ID column.

- by_year:

  Include the org-years-by-type breakdown. Default `TRUE`.

- print:

  Print the summary. Default `TRUE`.

## Value

For a data frame, invisibly a `panel_summary` object carrying the
per-organization classification as its `"classification"` attribute; for
a panel, the panel with labels refreshed.

## Details

Given a
[panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md)
it also stores the classification as label rules on the frame, marks the
labels current, and logs the step.
