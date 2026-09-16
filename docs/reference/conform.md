# Check whether a data frame conforms to a sample frame

Verifies that no row violates any `subset`/`filter` rule, that key
columns are present, and reports `check` rules. Use it to enforce the
"contract" at any point.

## Usage

``` r
conform(df, sfw, verbose = TRUE)
```

## Arguments

- df:

  A data frame.

- sfw:

  A sample frame.

- verbose:

  Print a summary.

## Value

Invisibly, a list: `conformant`, `rows_total`, `rows_violating`,
`missing_keys`, `checks`.
