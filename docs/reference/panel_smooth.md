# Smooth numeric variables within panel IDs

Smooth numeric variables within panel IDs

## Usage

``` r
panel_smooth(
  data,
  vars,
  window = 3,
  weights = c("equal", "half", "decay"),
  time = "TAX_YEAR",
  id = "EIN2",
  verbose = TRUE
)
```

## Arguments

- data:

  A panel data frame.

- vars:

  Numeric fields to smooth.

- window:

  Odd rolling-window width.

- weights:

  `"equal"`, `"half"`, or `"decay"`.

- time:

  Panel-time column.

- id:

  Panel-ID column.

- verbose:

  Print progress.

## Value

Input rows in original order with selected fields smoothed.
