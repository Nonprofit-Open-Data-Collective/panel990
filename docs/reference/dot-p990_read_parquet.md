# Read a parquet file, projecting columns and pushing row filters down

Column projection and an `IN` filter are applied during the scan, so a
selective read touches only the column chunks and row groups it needs.
The efile files are sorted by `EIN2`, which is what makes an entity
restriction prune row groups rather than scan them.

## Usage

``` r
.p990_read_parquet(
  path,
  columns = NULL,
  filters = NULL,
  engine = .p990_parquet_engine(),
  con = NULL
)
```

## Arguments

- path:

  Local path or URL.

- columns:

  Fields to retain; `NULL` reads every column.

- filters:

  Named list of accepted values, such as `list(EIN2 = eins)`.

- engine:

  `"duckdb"` or `"arrow"`.

- con:

  Optional open DuckDB connection to reuse across a read loop.

## Value

A data frame of character columns, uncast. Callers apply
[`.p990_coerce()`](https://nonprofit-open-data-collective.github.io/panel990/reference/dot-p990_coerce.md).
