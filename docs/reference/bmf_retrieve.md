# Retrieve and prepare the NCCS unified BMF

Retrieval strategy is chosen by `format`:

## Usage

``` r
bmf_retrieve(
  source = NULL,
  vars = .EFILE_BMF_VARS,
  eins = NULL,
  states = NULL,
  format = c("auto", "parquet", "states", "csv"),
  cache = c("retain", "temporary"),
  path = "PANEL990",
  overwrite = FALSE,
  timeout = 3600,
  retry_max = 3L,
  strict = FALSE,
  verbose = TRUE
)
```

## Arguments

- source:

  Optional override: a URL, local file path, or in-memory data frame.
  `NULL` (default) uses the published NCCS release.

- vars:

  Native BMF fields to retain.

- eins:

  Optional `EIN2` values used to filter before preparation.

- states:

  Optional postal codes limiting retrieval to those state marts.
  Supplying this implies `format = "states"`. See
  [`bmf_states()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_states.md).

- format:

  Retrieval strategy; see details.

- cache:

  `"retain"` to keep downloads under `path`, or `"temporary"` for a
  session temporary directory.

- path:

  Cache directory used when `cache = "retain"`.

- overwrite:

  Download again even when a cached file exists.

- timeout:

  Minimum per-attempt download timeout in seconds; raised automatically
  for large files. See
  [`download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.md).

- retry_max:

  Maximum attempts per file.

- strict:

  Error when requested fields are unavailable.

- verbose:

  Print retrieval and preparation messages.

## Value

A prepared BMF data frame with a `bmf_diagnostics` attribute.

## Details

- `"parquet"` downloads the single unified parquet file (~640 MB) and
  reads it with DuckDB or arrow, projecting only the requested columns.

- `"states"` downloads the per-state CSV marts (6-380 MB each) and
  stacks them. Stacking is a plain row bind, not a join, so it is cheap;
  this is the fallback when no parquet reader is installed, and the way
  to retrieve a subset of states. **The state marts are a separate,
  lagging build**, not a partition of the unified file: at the 2026_08
  release they stack to 3,687,435 rows against the unified 3,698,124,
  and their `bmf_vintage_ym` runs about a month behind. Retrieving all
  states this way emits a warning to that effect. Prefer parquet when
  the vintage matters.

- `"csv"` downloads the single unified CSV (~3.6 GB). Slowest, and only
  worth using when neither of the above is possible.

- `"auto"` (default) uses `"parquet"` when DuckDB or arrow is available
  and `"states"` otherwise, or whenever `states` is supplied.

Every transfer is retried with exponential backoff and verified against
the published `_manifest.json` byte count where one exists. Each call
writes a per-run log under `<path>/logs`; see
[`retrieval_log()`](https://nonprofit-open-data-collective.github.io/panel990/reference/retrieval_log.md).
