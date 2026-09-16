# Fetch one remote or local resource, retrying on failure

Raises the download timeout for the duration of the call (the R default
of 60 seconds is far too short for multi-GB sources), retries with
exponential backoff, deletes partial files between attempts, and
verifies the byte count against `expected_bytes` when a published
manifest supplies one.

## Usage

``` r
.p990_fetch(
  url,
  destination,
  timeout = 1800,
  retry_max = 3L,
  expected_bytes = NA_real_,
  label = basename(destination),
  overwrite = FALSE,
  backoff = 5,
  verbose = TRUE
)
```

## Arguments

- url:

  Remote URL or local file path.

- destination:

  Local destination path.

- timeout:

  Per-attempt timeout in seconds.

- retry_max:

  Maximum attempts.

- expected_bytes:

  Optional expected size used as an integrity check.

- label:

  Human-readable name used in progress messages.

- overwrite:

  Re-fetch even when the destination already exists.

- backoff:

  Seconds before the second attempt; doubles thereafter.

- verbose:

  Print START/OK/FAIL messages.

## Value

A list with `status`, `attempts`, `bytes`, `seconds`, and `error`.
