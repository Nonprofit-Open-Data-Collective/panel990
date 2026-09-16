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
  unique_rows = TRUE
)
```
