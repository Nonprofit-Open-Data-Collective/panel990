# Reconcile 990 rows to accounting identities with the least change

Adjusts values as little as possible (weighted least squares) so that
each row satisfies the bundled
[accounting_identities](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_identities.md).
Columns named in `fixed` are held exactly; among the rest, `weights` set
how resistant each variable is to change (larger = moves less). Only
rows with no missing values in the relevant fields are reconciled.

## Usage

``` r
reconcile(
  data,
  section = NULL,
  fixed = NULL,
  weights = NULL,
  rows = NULL,
  id = "EIN2",
  time = "TAX_YEAR"
)
```

## Arguments

- data:

  A data frame of 990 financial fields.

- section:

  Identity sections to enforce. `NULL` (default) uses all.

- fixed:

  Character vector of columns to hold fixed (e.g. reported totals).

- weights:

  Optional named vector of per-variable weights (default equal).

- rows:

  Rows to reconcile: a logical/integer index. Default is rows where
  `imputed_row` is `TRUE` if that column exists, otherwise all rows.

- id, time:

  Identifier columns (unused by the math; kept for symmetry).

## Value

`data` with reconciled values; an `"reconciled"` attribute records how
many rows were adjusted and how many were skipped for missing values.

## See also

[`accounting_check()`](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_check.md),
[`panel_complete()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_complete.md).
