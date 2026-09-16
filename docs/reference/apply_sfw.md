# Apply a sample frame to a data frame

Runs the frame's active rules in phase order – `subset`, `filter`,
`dedup`, `refresh`, then `select` – recording a per-step manifest as the
`"sfw_steps"` attribute. `check` and `view` rules are evaluated and
attached as `"sfw_checks"` / `"sfw_views"` without altering the data.
Ad-hoc `...` filters (e.g. `panel_type = "persistent"`) apply on top of
the stored rules.

## Usage

``` r
apply_sfw(df, sfw, ..., columns = TRUE, checks = TRUE, verbose = TRUE)
```

## Arguments

- df:

  A data frame.

- sfw:

  A sample frame.

- ...:

  Ad-hoc convenience filters.

- columns:

  Apply `select` rules? Default `TRUE`.

- checks:

  Evaluate `check`/`view` rules? Default `TRUE`.

- verbose:

  Print a one-line summary.

## Value

The filtered/selected data frame, with manifest attributes.
