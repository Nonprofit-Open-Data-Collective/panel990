# Open a DuckDB connection for parquet reads

A read loop should open one connection and pass it down rather than let
each file create its own: starting an instance per table-year repeats
the setup cost and prints duckdb's extension-directory notice once per
file.

## Usage

``` r
.p990_parquet_con()
```

## Value

A DBI connection. The caller is responsible for disconnecting.
