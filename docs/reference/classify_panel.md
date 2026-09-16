# Classify panel membership and store it as label rules

Runs
[`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md)
on `df` and adds two `label` rules keyed by entity: `panel_type`
(`persistent`/`entrant`/`exit`/`transient`/`empty`) and `panel_spell`
(`seamless`/`segmented`). Filter on them via, e.g.,
`apply_sfw(df, sfw, panel_type = "persistent")`.

## Usage

``` r
classify_panel(sfw, df, method = c("describe"))
```

## Arguments

- sfw:

  A sample frame.

- df:

  A panel data frame with the frame's entity and time key columns.

- method:

  Classifier to use. Currently `"describe"`.

## Value

The updated sample frame.
