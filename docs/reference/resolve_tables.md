# Resolve aliases and literal efile table names

Any non-empty literal table name is accepted, allowing newly published
and user-specified tables without a package update.

## Usage

``` r
resolve_tables(tables, source = data_source())
```

## Arguments

- tables:

  Character vector of aliases or canonical table names.

- source:

  An
  [`data_source()`](https://nonprofit-open-data-collective.github.io/panel990/reference/data_source.md)
  configuration.

## Value

A data frame containing request, table, alias status, cardinality, and
whether the resolved name is in the canonical
[`table_catalog()`](https://nonprofit-open-data-collective.github.io/panel990/reference/table_catalog.md).
