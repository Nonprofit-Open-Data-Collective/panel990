# Prepare current-schema BMF data

Validates `EIN2`, resolves duplicate records using BMF vintage and
source, derives sentinel-aware `ruling_year`, and selects native fields.

## Usage

``` r
bmf_prepare(bmf, vars = .EFILE_BMF_VARS, strict = FALSE, verbose = TRUE)
```

## Arguments

- bmf:

  A data frame containing current-schema BMF data.

- vars:

  Fields to retain. Use `NULL` for every available field.

- strict:

  Error when requested fields are unavailable.

- verbose:

  Print preparation messages.

## Value

A data frame with one row per `EIN2` and a `bmf_diagnostics` attribute.
