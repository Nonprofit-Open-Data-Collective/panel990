# Merge native BMF fields onto efile data

Merge native BMF fields onto efile data

## Usage

``` r
bmf_merge(
  data,
  source = NULL,
  vars = .EFILE_BMF_VARS,
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

- data:

  Efile data containing `EIN2`.

- source:

  Optional BMF override: URL, local path, or data frame.

- vars:

  Native BMF fields to retain.

- states:

  Optional state marts to restrict retrieval to.

- format:

  Retrieval strategy; see
  [`bmf_retrieve()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_retrieve.md).

- cache:

  `"retain"` or `"temporary"`.

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

  Print retrieval and join messages.

## Value

The input rows with native BMF fields appended and a `bmf_diagnostics`
attribute.
