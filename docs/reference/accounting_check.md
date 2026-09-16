# Check 990 rows against accounting identities

Evaluates the bundled
[accounting_identities](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_identities.md)
against each row of a panel and reports the residual of every identity
that can be evaluated (all of its variables present as columns). A
residual is `total - sum(parts)`; it should be zero.

## Usage

``` r
accounting_check(
  data,
  section = NULL,
  id = "EIN2",
  time = "TAX_YEAR",
  tol = 1,
  violations_only = TRUE
)
```

## Arguments

- data:

  A data frame of 990 financial fields (e.g. a merged panel).

- section:

  Identity sections to check (`"revenue"`, `"expenses"`,
  `"balance_sheet"`). `NULL` (default) checks all.

- id, time:

  Identifier columns carried onto the report (if present).

- tol:

  Absolute tolerance for calling a residual a violation.

- violations_only:

  Return only the rows that violate an identity (default `TRUE`);
  `FALSE` returns every evaluated identity.

## Value

A data frame with one row per (record, identity): the id/time keys,
`identity`, `residual`, and `ok`.

## See also

[`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md),
[accounting_identities](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_identities.md).
