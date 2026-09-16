# Identifier for a single retrieval run

Timestamp plus a process-unique token, used to name per-run log files so
repeated or concurrent runs never overwrite one another. Uses
[`tempfile()`](https://rdrr.io/r/base/tempfile.html) rather than the RNG
so package code leaves `.Random.seed` untouched.

## Usage

``` r
.p990_run_id()
```

## Value

A length-one character vector such as `"20260902T051200-1a2b3c"`.
