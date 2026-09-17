# Source dimensions of a parquet file without reading it

Row count and column count come from the file footer and schema, so they
are free. This lets a read push its projection into the scan and still
report the true source width in the manifest.

## Usage

``` r
.p990_parquet_dims(path, engine = .p990_parquet_engine(), con = NULL)
```

## Arguments

- path:

  Local path or URL.

- engine:

  `"duckdb"` or `"arrow"`.

- con:

  Optional open DuckDB connection to reuse.

## Value

A list with `rows` and `cols`.
