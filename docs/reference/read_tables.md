# Read acquired efile tables

The format of each cached file is detected from its extension, so a CSV
cache and a parquet cache both read through this function.

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

## Details

Deduplication runs on a `data.table`. Base
[`duplicated()`](https://rdrr.io/r/base/duplicated.html) on a wide
`data.frame` pastes every row into a string and dominates the cost of
this step – on a 555k x 80 header table it takes roughly 47 seconds
against under a second here, for identical results.

## Deduplication and pushdown

Full-row deduplication needs every column and every row, so it has to
happen before the projection and cannot be pushed into a parquet scan.
With `unique_rows = FALSE` the `columns` projection and the `filters`
restriction are instead pushed into the read, which on a parquet source
prunes row groups rather than scanning them; the source dimensions
reported in the manifest still describe the whole file, read from its
footer. The efile build emits no exact duplicate rows, so on a current
release `unique_rows = FALSE` is both faster and equivalent.
