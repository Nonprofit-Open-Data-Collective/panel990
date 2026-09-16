# Accounting-identity registry for IRS 990 financial fields

The linear accounting identities that hold among 990 financial fields
across the revenue (Part VIII), functional-expenses (Part IX), and
balance-sheet (Part X) sections – column splits, subtotals,
net-of-expense lines, the revenue grand total, and the balance-sheet
equation. Each identity is a linear combination of fields that must
equal zero; the registry is stored in long form and drives
[`accounting_check()`](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_check.md)
and
[`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md).

## Usage

``` r
accounting_identities
```

## Format

A data frame with one row per (identity, variable):

- identity:

  Identity name, e.g. `rev_contributions_subtotal`.

- section:

  `"revenue"`, `"expenses"`, or `"balance_sheet"`.

- form_scope:

  Form the identity applies to (`"PC"`, the full 990).

- type:

  `column`, `subtotal`, `net`, or `grand_total`.

- description:

  Human-readable statement of the identity.

- variable:

  An ef2 `variable_name` appearing in the identity.

- coefficient:

  Its coefficient (identity holds when the weighted sum is 0).

## Details

A curated, high-confidence set of 58 identities over 214 fields (21
revenue, 32 expense, 5 balance-sheet), built by
`data-raw/build-accounting-identities.R` and validated against
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md).
Only identities whose structure is unambiguous from the ef2 naming are
included; vertical sums that would require 1xm write-in detail (expense
line 24) or that hit form-version variants (balance-sheet cash lines)
are deliberately omitted.

## See also

[`accounting_check()`](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_check.md),
[`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md)
