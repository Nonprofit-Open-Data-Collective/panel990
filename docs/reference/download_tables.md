# Download or reuse efile table files

The file format follows `source$format`, so a cache built from
`data_source(format = "parquet")` holds parquet and one built from the
default holds CSV. Both are read by
[`read_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/read_tables.md)
and
[`read_tables_duckdb()`](https://nonprofit-open-data-collective.github.io/panel990/reference/read_tables_duckdb.md),
which detect the format from the extension, so a cache may hold either
or both.

## Usage

``` r
download_tables(
  years,
  tables,
  source = data_source(),
  path = "PANEL990",
  cache = c("retain", "temporary"),
  overwrite = FALSE,
  retry_max = 3L,
  timeout = 1800,
  verbose = TRUE
)
```

## Arguments

- years:

  Integer tax years.

- tables:

  Aliases or literal canonical table names.

- source:

  An
  [`data_source()`](https://nonprofit-open-data-collective.github.io/panel990/reference/data_source.md)
  configuration.

- path:

  Cache directory used when `cache = "retain"`.

- cache:

  `"retain"` for a durable cache or `"temporary"` for a session
  temporary directory.

- overwrite:

  Download again even when a cached file exists.

- retry_max:

  Maximum attempts per remote file.

- timeout:

  Minimum per-attempt download timeout in seconds; raised automatically
  for large files. See the Timeouts section.

- verbose:

  Print per-file progress messages.

## Value

An `download_result` containing successful file paths, a structured
table-year manifest, the `run_id`, and the per-run `log_file`.

## Details

Each file is fetched by
[`.p990_fetch()`](https://nonprofit-open-data-collective.github.io/panel990/reference/dot-p990_fetch.md),
which raises the download timeout, retries with exponential backoff, and
discards partial files between attempts. Progress is reported as a START
line before each transfer begins and an OK/FAIL line when it settles, so
a stalled file is identifiable while it is still running.

Every call writes its own log under `<path>/logs` named for the run, so
repeated runs accumulate rather than overwrite. See
[`retrieval_log()`](https://nonprofit-open-data-collective.github.io/panel990/reference/retrieval_log.md).

## Timeouts

R's download timeout is a budget for an entire transfer, not a limit on
how long the connection may stall, so a fixed value silently imposes a
minimum transfer rate: the 2023 header table alone is 357 MB. `timeout`
is therefore treated as a floor. Each file is given at least `timeout`
seconds and at least as long as its `Content-Length` needs at 0.5 MB/s,
and a timeout the user raised globally with `options(timeout =)` or
`R_DEFAULT_INTERNET_TIMEOUT` is never lowered.
