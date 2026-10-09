# Select efile fields by form scope

Returns the variable names present on a given return form, using the
built-in
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md).
Useful for restricting a panel to fields available on both the full 990
and the 990EZ, which avoids conflating a structural blank (field absent
from the 990EZ) with a reported blank.

## Usage

``` r
fields_in_scope(form = c("both", "990", "990EZ", "all", "990PF"))
```

## Arguments

- form:

  One of `"both"` (present on the full 990 and the 990EZ), `"990"`
  (present on the full 990), `"990EZ"` (present on the 990EZ), `"all"`
  (every 990-release variable), or `"990PF"` (every 990PF-release
  variable). Header and signature fields count as present on every form.

## Value

A character vector of `variable_name` values.

## Details

Form scope is a 990-release concept. A 990PF return is one form, so the
990PF release has no structural blanks of this kind; `"990PF"` simply
returns every variable in
[field_concordance_pf](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance_pf.md).

## See also

[`concordance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/concordance.md),
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md),
[field_concordance_pf](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance_pf.md).
