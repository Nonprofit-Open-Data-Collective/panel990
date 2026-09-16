# Select efile fields by form scope

Returns the variable names present on a given return form, using the
built-in
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md).
Useful for restricting a panel to fields available on both the full 990
and the 990EZ, which avoids conflating a structural blank (field absent
from the 990EZ) with a reported blank.

## Usage

``` r
fields_in_scope(form = c("both", "990", "990EZ", "all"))
```

## Arguments

- form:

  One of `"both"` (present on the full 990 and the 990EZ), `"990"`
  (present on the full 990), `"990EZ"` (present on the 990EZ), or
  `"all"`. Header and signature fields count as present on every form.

## Value

A character vector of `variable_name` values.

## See also

[`concordance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/concordance.md),
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md).
