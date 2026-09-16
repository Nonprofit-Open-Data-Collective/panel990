# Complete panel spans by filling interior gaps

Turns every `segmented` organization into a `seamless` one by inserting
the missing interior years and filling their numeric fields, so each
organization is observed continuously across its own span. This is the
researcher-facing wrapper over
[`panel_impute()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_impute.md):
it fills gaps for **all** boundary types (not just panel-spanning
organizations) and interpolates by default.

## Usage

``` r
panel_complete(
  data,
  method = c("interpolate", "mean", "locf", "nocb"),
  types = c("persistent", "entrant", "exit", "transient"),
  max_gap_size = Inf,
  max_gap_count = Inf,
  vars = NULL,
  time = "TAX_YEAR",
  id = "EIN2",
  as_integers = FALSE,
  classification = NULL,
  reconcile = FALSE,
  reconcile_fixed = NULL,
  reconcile_section = NULL
)
```

## Arguments

- data:

  A panel data frame.

- method:

  Fill method: `"interpolate"` (linear, the default), `"mean"`, `"locf"`
  (carry forward), or `"nocb"` (carry backward).

- types:

  Panel types eligible for completion. Defaults to every span type; only
  `segmented` organizations have interior years to fill.

- max_gap_size, max_gap_count:

  Optional gap-size / gap-count limits per organization.

- vars:

  Numeric variables to fill; `NULL` selects numeric non-key fields.

- time:

  Panel-time column.

- id:

  Panel-ID column.

- as_integers:

  Round filled values for originally integer fields.

- classification:

  Optional classification from
  [`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md).

- reconcile:

  If `TRUE`, snap the newly filled rows to the accounting identities
  with
  [`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md)
  after imputation. Filling a whole row preserves linear identities, but
  rounding (`as_integers`) or an inconsistent bracketing observation can
  leave an imputed row off-balance; this corrects it with the least
  change.

- reconcile_fixed, reconcile_section:

  Passed to
  [`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md)
  when `reconcile = TRUE` (columns to hold fixed; identity sections to
  enforce).

## Value

The panel with interior gaps filled; inserted rows carry
`imputed_row = TRUE`.

## Details

Completion never extends past an organization's observed span – it fills
the holes, it does not extrapolate to the panel edges. Inserted rows are
flagged with `imputed_row`.

## See also

[`panel_impute()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_impute.md),
[`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md),
[`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md).
