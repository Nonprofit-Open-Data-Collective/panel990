# Read efile CSVs through DuckDB

Internal backend used by
[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md).
Filters and projection are pushed into DuckDB before results are
collected into R.

## Usage

``` r
read_tables_duckdb(
  downloads,
  columns = NULL,
  filters = NULL,
  unique_rows = TRUE,
  timeout = 1800,
  retry_max = 3L
)
```

## Arguments

- downloads:

  A `download_result`.

- columns:

  Optional fields to retain.

- filters:

  Named list of accepted values.

- unique_rows:

  Remove exact duplicate rows.

- timeout:

  HTTP timeout in seconds applied to remote scans.

- retry_max:

  HTTP retries applied to remote scans.

## Details

Under `cache = "none"` the scan reads the CSVs straight from S3 through
the httpfs extension, which has its own HTTP settings and never sees R's
`timeout` option. `timeout` and `retry_max` are forwarded to httpfs so
the virtual scan honours the same limits as a cached download.
