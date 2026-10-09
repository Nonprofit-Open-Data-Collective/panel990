# Build a panel of 990PF filers

[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md)
for the 990PF release: private foundations, which file Form 990PF and
are published separately from Form 990 and 990EZ filers. The source is
`data_source(form = "990PF")`; every other argument passes through to
[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md),
so the panel is built, filtered, and logged the same way.

## Usage

``` r
panelize_pf(
  sfw = NULL,
  tables = c("PF00", "PF01", "PF02"),
  years,
  version = efile_version(),
  format = .efile_default_format(),
  root = NULL,
  ...
)
```

## Arguments

- sfw:

  Optional
  [`create_sfw()`](https://nonprofit-open-data-collective.github.io/panel990/reference/create_sfw.md)
  sample frame.

- tables:

  Aliases or literal 990PF table names. Defaults to the 990PF header and
  the Part I and Part II financial statements.

- years:

  Tax years.

- version:

  Published release, such as `"v3_1"`.

- format:

  Source file format, `"parquet"` or `"csv"`.

- root:

  Optional base URL or local directory holding a copy of the 990PF
  release; overrides `version`.

- ...:

  Further arguments to
  [`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md),
  such as `backend`, `cache`, `path`, or `bmf`.

## Value

A `panel` (see
[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md)).

## Details

The 990PF release has its own tables and aliases – see
`table_catalog(form = "990PF")`:

- `PF00` – `PF-P00-T00-HEADER` (990PF-specific header items).

- `PF01` – `PF-P01-T00-REVENUE-EXPENSE` (Part I). Each line is reported
  in up to four columns: `_BOOKS` (revenue and expenses per books),
  `_NET` (net investment income), `_ADJ_NET` (adjusted net income), and
  `_DISBMT` (disbursements for charitable purposes).

- `PF02` – `PF-P02-T00-BALANCE-SHEET` (Part II), with beginning- and
  end-of-year book value (`_BOY_BV`, `_EOY_BV`) and end-of-year fair
  market value (`_EOY_FMV`).

- `PF03` – `PF-P03-T00-NET-ASSET-FUND-BALANCE-CHANGE` (Part III).

- `P00` – `F9-P00-T00-HEADER`, the header shared with the 990 release.

A 990PF panel cannot be combined with 990 or 990EZ filers in one call,
and form scope does not apply: a frame whose `select` rule uses a 990
scope such as `"both"` is an error.

## See also

[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md),
[`data_source()`](https://nonprofit-open-data-collective.github.io/panel990/reference/data_source.md),
[`financial_fields()`](https://nonprofit-open-data-collective.github.io/panel990/reference/financial_fields.md).

## Examples

``` r
if (FALSE) { # \dontrun{
pf <- panelize_pf(years = 2021:2022, backend = "duckdb", cache = "none")
pf <- panel_normalize(pf)
accounting_check(pf$data, section = "balance_sheet")
} # }
```
