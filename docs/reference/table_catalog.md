# Catalog of canonical efile tables

Returns the full reference set of NCCS efile tables (Form 990/990EZ core
and Schedules A-R), each with its join cardinality and short alias where
one is defined. Cardinality is derived from the table's T-number: `1x1`
(one row per filing, T00), `1xm` (repeating rows, T01-T98), or
`supplemental` (free-text, T99).

## Usage

``` r
table_catalog(cardinality = c("all", "1x1", "1xm", "supplemental"))
```

## Arguments

- cardinality:

  Filter to `"all"` (default), `"1x1"`, `"1xm"`, or `"supplemental"`.

## Value

A data frame with columns `table`, `alias` (NA when none), and
`cardinality`, one row per canonical table.
