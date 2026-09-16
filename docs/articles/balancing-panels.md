# Balancing a panel

[`panel_balance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_balance.md)
trims a panel to a **balanced rectangle** – a block of years in which
every retained organization is observed in every retained year. It is
the complement of
[`panel_complete()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_complete.md):
completion *fills* gaps to reach a full rectangle, balancing *drops*
organizations and years to reach one.

![panel_balance() trimming a mixed panel to its largest fully observed
block of organizations and years](figures/panel-balance.svg)

panel_balance() trimming a mixed panel to its largest fully observed
block of organizations and years

``` r
df <- data.frame(
  EIN2     = c(rep("A", 4), rep("B", 4), rep("C", 3), rep("D", 2)),
  TAX_YEAR = c(2019:2022,   2019:2022,   2019:2021,   c(2019, 2020))
)
```

`A` and `B` are observed all four years; `C` misses 2022; `D` only
appears in 2019–2020.

## The year window is the trade-off

A **wider** window keeps more years but fewer organizations; a
**narrower** one keeps more organizations. By default
[`panel_balance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_balance.md)
uses the full observed range – the strictest balance:

``` r
full <- panel_balance(df)
unique(full$EIN2)          # only orgs present in all of 2019-2022
#> [1] "A" "B"
attr(full, "balance")
#> $years
#> [1] 2019 2020 2021 2022
#> 
#> $n_years
#> [1] 4
#> 
#> $orgs_kept
#> [1] 2
#> 
#> $orgs_dropped
#> [1] 2
```

Restrict the window and more organizations qualify:

``` r
win <- panel_balance(df, years = 2019:2021)
unique(win$EIN2)           # C now qualifies; D still does not
#> [1] "A" "B" "C"
```

## Let it find the largest block

If you would rather have the package pick the window that retains the
most data (organizations x years), use `strategy = "max_rectangle"`:

``` r
best <- panel_balance(df, strategy = "max_rectangle")
attr(best, "balance")[c("years", "orgs_kept")]
#> $years
#> [1] 2019 2020 2021
#> 
#> $orgs_kept
#> [1] 3
```

Here the 3-year x 3-organization block (2019–2021, A/B/C = 9
observations) beats the full 4-year x 2-organization block (8), so that
is what it returns. `min_years` sets a floor on how short a balanced
window may be.

## Notes

The `"balance"` attribute always records the retained years and the
keep/drop counts. If no organization spans the window, the result is
simply empty (zero rows) rather than an error – a useful signal that
your window is too demanding. And because balancing only *selects* rows,
run
[`deduplicate()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_deduplicate.md)
first if an organization can have more than one filing per year, so each
cell of the rectangle is a single record.
