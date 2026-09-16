# Read acquired efile CSV tables

Deduplication runs on a `data.table`. Base
[`duplicated()`](https://rdrr.io/r/base/duplicated.html) on a wide
`data.frame` pastes every row into a string and dominates the cost of
this step – on a 555k x 80 header table it takes roughly 47 seconds
against under a second here, for identical results.

## Usage

``` r
read_tables(
  downloads,
  columns = NULL,
  filters = NULL,
  unique_rows = TRUE,
  verbose = TRUE
)
```

## Arguments

- downloads:

  Result from
  [`download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.md).

- columns:

  Optional fields to retain; join keys should be included.

- filters:

  Named list of accepted values, such as `list(EIN2 = eins)`.

- unique_rows:

  Remove exact duplicate rows.

- verbose:

  Print per-table progress messages.

## Value

An `read_result` with named tables and an augmented manifest.
