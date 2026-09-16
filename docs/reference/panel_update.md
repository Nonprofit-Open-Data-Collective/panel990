# Refresh panel-membership labels

Re-classifies a panel after row-changing steps (imputation,
deduplication) so the `panel_type`/`panel_spell` labels are current –
without filtering. On a bare data frame it appends fresh labels via
[`panel_label()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_label.md).

## Usage

``` r
panel_update(x)
```

## Arguments

- x:

  A
  [panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md)
  or a data frame.

## Value

The panel with labels refreshed (or the labeled data frame).

## See also

[`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md),
[`panel_filter()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_filter.md).
