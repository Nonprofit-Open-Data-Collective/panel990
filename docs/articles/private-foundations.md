# 5. Private foundations (990PF)

Private foundations file Form 990PF rather than the Form 990 or 990EZ.
NCCS publishes their efile data as a separate release with its own
tables, and `panel990` reads it through the same machinery as the 990
release. This tutorial covers what is different.

> The download chunks below are shown but **not executed** in this
> vignette; they require network access to the NCCS bucket. Run them in
> a live session.

## One release per source

Each NCCS release is published as two databases:

| Form family | Filers                                          | S3 prefix  |
|-------------|-------------------------------------------------|------------|
| `"990"`     | Form 990 and 990EZ, told apart by `RETURN_TYPE` | `efile_`   |
| `"990PF"`   | Form 990PF                                      | `efilepf_` |

A
[`data_source()`](https://nonprofit-open-data-collective.github.io/panel990/reference/data_source.md)
reads exactly one of them, chosen with `form`:

``` r
data_source(form = "990PF")$root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efilepf_v3_1/"
```

A panel never mixes the two. The 990PF financial statements are a
different structure from the 990 parts, not a relabelled copy of them,
so there is no single set of columns on which a foundation and a public
charity line up. Build 990 and 990PF panels separately.

## 990PF tables

The 990PF release has its own catalog. Its parts get their own `PF`
aliases, so no short name means one table in a 990 source and another in
a 990PF source:

``` r
pf <- table_catalog(form = "990PF")
pf[!is.na(pf$alias), ]
#>                                       table alias cardinality
#> 1                         F9-P00-T00-HEADER   P00         1x1
#> 8                         PF-P00-T00-HEADER  PF00         1x1
#> 9                PF-P01-T00-REVENUE-EXPENSE  PF01         1x1
#> 10                 PF-P02-T00-BALANCE-SHEET  PF02         1x1
#> 11 PF-P03-T00-NET-ASSET-FUND-BALANCE-CHANGE  PF03         1x1
```

`P00` is the one alias the two releases share, because both publish the
filing header under the same name, `F9-P00-T00-HEADER`. The 990PF
release also carries its own copies of the signature and Schedule B
tables.

Asking for a table from the other release is an error, raised before any
download starts:

``` r
resolve_tables("PF01", data_source())          # a 990 source
#> Error:
#> ! 990PF tables requested from a 990 source: PF01. Use panelize_pf() or data_source(form = "990PF").
resolve_tables("P08", data_source(form = "990PF"))
#> Error:
#> ! Not published in the 990PF release: P08. A 990PF source reads PF-* tables and the shared header, signature, and Schedule B tables; see table_catalog(form = "990PF").
```

## Building a panel

[`panelize_pf()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize_pf.md)
is
[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md)
with a 990PF source. It defaults to the 990PF header and the Part I and
Part II financial statements:

``` r
pf <- panelize_pf(years = 2021:2022, backend = "duckdb", cache = "none")
```

Everything else works as it does for a 990 panel: sample frames, the BMF
join, deduplication, and the provenance log. Retained downloads are
cached under `<path>/990PF/<year>/`, because the 990PF release reuses
the shared table names and its files must not overwrite the 990
release’s.

## Reading the 990PF financial statements

Part I (`PF01`) reports each line in up to four columns, marked by the
suffix:

| Suffix     | Column                                      |
|------------|---------------------------------------------|
| `_BOOKS`   | \(a\) revenue and expenses per books        |
| `_NET`     | \(b\) net investment income                 |
| `_ADJ_NET` | \(c\) adjusted net income                   |
| `_DISBMT`  | \(d\) disbursements for charitable purposes |

Part II (`PF02`) reports the balance sheet at beginning- and end-of-year
book value (`_BOY_BV`, `_EOY_BV`) and end-of-year fair market value
(`_EOY_FMV`). Part III (`PF03`) reconciles net assets from the beginning
to the end of the year.

The bundled `field_concordance_pf` describes every 990PF field, and
`financial_fields(form = "990PF")` lists the money fields in Parts
I-III:

``` r
head(financial_fields(form = "990PF"))
#> [1] "PF_01_EXCESS_REV_OVER_EXP_BOOKS" "PF_01_EXP_ACC_FEE_ADJ_NET"      
#> [3] "PF_01_EXP_ACC_FEE_BOOKS"         "PF_01_EXP_ACC_FEE_DISBMT"       
#> [5] "PF_01_EXP_ACC_FEE_NET"           "PF_01_EXP_COMP_OFF_ADJ_NET"
```

## Blanks and form scope

A 990PF return is one form, so form scope, which separates full-990 from
990EZ fields, does not apply. A sample frame that selects columns by a
990 scope such as `"both"` is an error in a 990PF panel; select by
`tables` or `vars` instead.

Blanks are common in the 990PF financial statements, and
[`panel_normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_normalize.md)
reads them the same way it does for the 990: a blank money field on a
filed return is zero, while a row with no financial data at all is left
untouched. The same call works for either kind of panel:

``` r
pf <- panel_normalize(pf)
```

## Accounting identities

`accounting_identities` includes 29 990PF identities, marked
`form_scope == "PF"`. They cover the Part I column totals, the Part II
balance-sheet equation and subtotals, and the Part III reconciliation
and its ties to Parts I and II.
[`accounting_check()`](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_check.md)
evaluates whichever identities have all their fields in the data, so the
call is the same as for a 990 panel:

``` r
accounting_check(panel_data(pf), section = "balance_sheet")
```

``` r
ids <- accounting_identities[accounting_identities$form_scope == "PF", ]
unique(ids[, c("identity", "section", "description")])[1:6, ]
#>                   identity  section
#> 235     pf_rev_total_books  revenue
#> 243       pf_rev_total_net  revenue
#> 249   pf_rev_total_adj_net  revenue
#> 257    pf_rev_gross_profit  revenue
#> 260 pf_excess_rev_over_exp  revenue
#> 263 pf_exp_operating_books expenses
#>                                                                  description
#> 235                      Part I total revenue (books) = sum of revenue lines
#> 243      Part I total revenue (net investment income) = sum of revenue lines
#> 249        Part I total revenue (adjusted net income) = sum of revenue lines
#> 257     Gross profit (books) = gross sales less returns - cost of goods sold
#> 260 Excess of revenue over expenses (books) = total revenue - total expenses
#> 263           Part I total operating expenses (books) = sum of expense lines
```
