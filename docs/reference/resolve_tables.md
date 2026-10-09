# Resolve aliases and literal efile table names

Any non-empty literal table name is accepted, allowing newly published
and user-specified tables without a package update – except that a table
from the other form family is an error: `PF-*` tables exist only in the
990PF release, and the 990PF release holds only `PF-*` tables plus its
copies of the shared header, signature, and Schedule B tables.

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
