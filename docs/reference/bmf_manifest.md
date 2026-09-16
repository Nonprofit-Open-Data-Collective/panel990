# Read the published BMF build manifest

The NCCS build publishes `_manifest.json` beside the data with the
vintage, build time, and the byte count, row count, and SHA-256 of each
file. The byte counts are used to verify completed downloads.

## Usage

``` r
bmf_manifest(
  url = .EFILE_BMF_MANIFEST_URL,
  timeout = 120,
  retry_max = 2L,
  verbose = TRUE
)
```

## Arguments

- url:

  Manifest URL.

- timeout:

  Download timeout in seconds.

- retry_max:

  Maximum attempts.

- verbose:

  Print progress messages.

## Value

A list parsed from the manifest, or `NULL` when it cannot be read
(including when the suggested package `jsonlite` is absent).
