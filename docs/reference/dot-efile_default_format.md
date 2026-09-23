# Default source format for this session

`.EFILE_FORMAT`, unless it is parquet and no parquet reader is
installed: `duckdb` and `arrow` are only suggested, and a parquet
default that fails at read time would break every call that did not ask
for a format. That case falls back to CSV and says so once per session.

## Usage

``` r
.efile_default_format()
```

## Value

`"csv"` or `"parquet"`.
