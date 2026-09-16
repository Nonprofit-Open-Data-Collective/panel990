# Report a panel's provenance ledger

Renders the sample frame's log – one row per executed step – as a
manifest: the step, its criteria, and the rows/columns before and after,
with dropped counts and percentages.

## Usage

``` r
manifest(x)
```

## Arguments

- x:

  A `panel` or a `sfw`.

## Value

A data frame provenance report (empty if nothing has been logged).
