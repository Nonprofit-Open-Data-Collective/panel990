# Download or reuse efile table CSV files

Each file is fetched by
[`.p990_fetch()`](https://nonprofit-open-data-collective.github.io/panel990/reference/dot-p990_fetch.md),
which raises the download timeout, retries with exponential backoff, and
discards partial files between attempts. Progress is reported as a START
line before each transfer begins and an OK/FAIL line when it settles, so
a stalled file is identifiable while it is still running.

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

  Download timeout in seconds, per attempt.

- verbose:

  Print per-file progress messages.

## Value

An `download_result` containing successful file paths, a structured
table-year manifest, the `run_id`, and the per-run `log_file`.

## Details

Every call writes its own log under `<path>/logs` named for the run, so
repeated runs accumulate rather than overwrite. See
[`retrieval_log()`](https://nonprofit-open-data-collective.github.io/panel990/reference/retrieval_log.md).
