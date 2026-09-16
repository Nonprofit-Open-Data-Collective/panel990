# Select one filing per organization-year

Prefers non-group and non-partial filings, then amended filings, then
the most recent timestamp. At least one filing is retained per
organization-year.

## Usage

``` r
panel_deduplicate(
  data,
  id = "EIN2",
  year = "TAX_YEAR",
  group = "RETURN_GROUP_X",
  partial = "RETURN_PARTIAL_X",
  amended = "RETURN_AMENDED_X",
  timestamp = "RETURN_TIME_STAMP",
  verbose = TRUE
)

deduplicate(
  data,
  id = "EIN2",
  year = "TAX_YEAR",
  group = "RETURN_GROUP_X",
  partial = "RETURN_PARTIAL_X",
  amended = "RETURN_AMENDED_X",
  timestamp = "RETURN_TIME_STAMP",
  verbose = TRUE
)
```

## Arguments

- data:

  A filing data frame.

- id:

  Organization identifier column.

- year:

  Filing-year column.

- group:

  Group-return flag column.

- partial:

  Partial-return flag column.

- amended:

  Amended-return flag column; use `NULL` to disable.

- timestamp:

  Filing timestamp column.

- verbose:

  Print a summary.

## Value

A data frame with at most one row per ID-year (or the panel, given a
[panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md)).
`deduplicate()` is a deprecated alias.
