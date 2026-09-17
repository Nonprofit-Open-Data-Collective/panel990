# Declared efile type of each field

Parquet stores every efile column as a string, so a read needs an
external statement of which fields are numeric. This is that statement:
the 16 structural filing columns from `.EFILE_KEY_TYPES`, and every form
variable from `field_concordance$data_type_simple`.

## Usage

``` r
.p990_efile_types(fields = NULL)
```

## Arguments

- fields:

  Optional character vector to restrict the result to.

## Value

A named character vector of `variable_name` -\> efile type, one of
`"numeric"`, `"integer"`, `"checkbox"`, `"text"`, or `"date"`.

## Details

Using the concordance makes the parquet types *declared* rather than
inferred, which is the one respect in which the parquet path is better
than the CSV path: `read_csv_auto()` and `fread()` guess from the first
rows and disagree with each other on real tables.
