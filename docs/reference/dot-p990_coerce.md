# Cast character columns to their declared efile types

Applied to parquet reads, where every column arrives as a string. Fields
with no declared type – user-supplied columns, tables newer than the
concordance – are left exactly as read.

## Usage

``` r
.p990_coerce(df, types = .p990_efile_types(names(df)), label = NULL)
```

## Arguments

- df:

  A data frame of character columns.

- types:

  Named type vector, defaulting to
  [`.p990_efile_types()`](https://nonprofit-open-data-collective.github.io/panel990/reference/dot-p990_efile_types.md).

- label:

  Table name used in warning messages.

## Value

`df` with numeric fields cast.

## Details

A value that is neither blank nor parseable is a signal that the
upstream build wrote something unexpected into a numeric column, so it
warns rather than failing quietly, in the same spirit as
[`normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/normalize.md).
