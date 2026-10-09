# Declared efile type of each field

Parquet stores every efile column as a string, so a read needs an
external statement of which fields are numeric. This is that statement:
the 16 structural filing columns from `.EFILE_KEY_TYPES`, and every form
variable from `data_type_simple` in
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md)
and
[field_concordance_pf](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance_pf.md).
The two releases' variable names do not collide except on the shared
header, signature, and Schedule B fields, where the concordances agree,
so one lookup serves both and the read paths need not know the form
family.

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
