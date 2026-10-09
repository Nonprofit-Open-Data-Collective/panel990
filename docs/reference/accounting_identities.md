# Accounting-identity registry for IRS 990 and 990PF financial fields

The linear accounting identities that hold among the financial fields of
the full Form 990 – the revenue (Part VIII), functional-expenses (Part
IX), and balance-sheet (Part X) sections – and of the Form 990PF
financial statements (Parts I-III): column splits, subtotals,
net-of-expense lines, grand totals, the balance-sheet equation, and the
ties between parts. Each identity is a linear combination of fields that
must equal zero; the registry is stored in long form and drives
[`accounting_check()`](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_check.md)
and
[`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md).
An identity is evaluated only when all of its fields are columns of the
data, so 990 identities never apply to a 990PF panel and the reverse.

## Usage

``` r
accounting_identities
```

## Format

A data frame with one row per (identity, variable):

- identity:

  Identity name, e.g. `rev_contributions_subtotal`. 990PF identities are
  prefixed `pf_`.

- section:

  `"revenue"`, `"expenses"`, `"balance_sheet"`, or (990PF Part III)
  `"net_assets"`.

- form_scope:

  Form the identity applies to: `"PC"` (the full 990) or `"PF"` (the
  990PF).

- type:

  `column`, `subtotal`, `net`, `grand_total`, `balance`, or `tie` (an
  equality between parts of the 990PF).

- description:

  Human-readable statement of the identity.

- variable:

  An ef2 `variable_name` appearing in the identity.

- coefficient:

  Its coefficient (identity holds when the weighted sum is 0).

## Details

A curated, high-confidence set built by
`data-raw/build-accounting-identities.R`, with every variable validated
against the concordance for its form:

- Form 990: 58 identities over 214 fields of
  [field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md)
  (21 revenue, 32 expense, 5 balance-sheet). Only identities whose
  structure is unambiguous from the ef2 naming are included; vertical
  sums that would require 1xm write-in detail (expense line 24) or that
  hit form-version variants (balance-sheet cash lines) are deliberately
  omitted.

- Form 990PF: 29 identities over 174 fields of
  [field_concordance_pf](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance_pf.md)
  (5 revenue, 8 expense, 11 balance-sheet, 5 net-asset), each holding
  for at least 98% of 2021-2022 filings after
  [`panel_normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_normalize.md).
  Net investment income and adjusted net income are omitted because the
  form floors them at zero.

## See also

[`accounting_check()`](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_check.md),
[`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md)
