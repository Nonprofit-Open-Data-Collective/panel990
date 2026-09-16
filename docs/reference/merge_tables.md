# Merge efile tables using explicit filing keys

Merge efile tables using explicit filing keys

## Usage

``` r
merge_tables(
  reads,
  keys = .EFILE_FILING_KEYS,
  include_many = FALSE,
  collision = c("error", "prefix"),
  verbose = TRUE
)
```

## Arguments

- reads:

  Result from
  [`read_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/read_tables.md).

- keys:

  Candidate join keys. Every merge uses the shared subset and requires
  at least one key.

- include_many:

  Join `1xm` and supplemental tables. Default `FALSE`.

- collision:

  `"error"` or `"prefix"` for shared non-key field names.

- verbose:

  Print per-join progress messages.

## Value

An `merge_result` containing one merged data frame per year, a table
manifest, and a join manifest.
