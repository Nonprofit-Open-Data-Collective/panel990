# Read efile tables through DuckDB

Internal backend used by
[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md).
Filters and projection are pushed into DuckDB before results are
collected into R. The scan expression follows the file extension, so a
CSV and a parquet cache read through the same code path; see
`.efile_duckdb_scan()`.

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

Under `cache = "none"` the scan reads straight from S3 through the
httpfs extension, which has its own HTTP settings and never sees R's
`timeout` option. `timeout` and `retry_max` are forwarded to httpfs so
the virtual scan honours the same limits as a cached download. This is
where parquet earns its keep: projection and an `EIN2` restriction
become column-chunk and row-group range requests instead of a whole-file
transfer.

## Deduplication and projection

`unique_rows = TRUE` compiles to `SELECT DISTINCT *`, which needs every
column and therefore prevents the projection from being pushed into the
scan. On a parquet source that is the difference between reading the
columns you asked for and reading all of them. The efile build emits no
exact duplicate rows, so `unique_rows = FALSE` is the faster and
equivalent choice on a current release.
