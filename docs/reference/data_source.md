# Create an efile source configuration

The NCCS efile release is versioned. Leave `root` as `NULL` to point at
a published release by `version`, or pass `root` explicitly to read from
a local directory or a mirror, in which case `version` is recorded as
`NA`.

## Usage

``` r
data_source(
  root = NULL,
  version = .EFILE_VERSION,
  format = .efile_default_format(),
  aliases = NULL,
  form = "990"
)
```

## Arguments

- root:

  Base URL or local directory containing table-year files. `NULL`
  (default) builds the URL for `version`.

- version:

  Published release, such as `"v3_1"` (the current default) or `"v2_3"`.
  Ignored when `root` is supplied.

- format:

  Source file format: `"parquet"` (the default, when a parquet reader is
  installed) or `"csv"`. See the Source format section.

- aliases:

  Named character vector mapping short aliases to table names. `NULL`
  (default) uses the form family's aliases: `P00`, `P01`, `P08`-`P12`
  and `A01` for `"990"`; `P00` and `PF00`-`PF03` for `"990PF"`.

- form:

  Form family: `"990"` (default, Form 990 and 990EZ filers) or `"990PF"`
  (private foundations). See the Form family section.

## Value

An `data_source` object carrying `root`, `version`, `format`, `aliases`,
and `form`.

## Form family

Each release is published as two separate databases, and a source reads
exactly one of them:

- `form = "990"` (the default): full Form 990 and 990EZ filers together,
  told apart by `RETURN_TYPE`.

- `form = "990PF"`: private foundations filing Form 990PF.

The two are not combined in one panel: the 990PF financial statements
have a different structure from the 990 parts. The form family sets the
URL prefix (`efile_` or `efilepf_`), the default `aliases`, the
[`table_catalog()`](https://nonprofit-open-data-collective.github.io/panel990/reference/table_catalog.md),
and the cache subdirectory used by
[`download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.md).
[`panelize_pf()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize_pf.md)
builds a panel from the 990PF release.

## Source format

A release publishes each table-year under one stem in two formats, so
`format` is an extension swap on an otherwise identical URL. Parquet is
the default: it is an eighth of the bytes to transfer, and it pays off
most for *selective* reads, because the files are sorted by `EIN2` with
non-overlapping row-group statistics, so an entity restriction prunes
row groups and a column projection reads only the chunks it needs.
Reading a whole table is no faster than reading the CSV. The gain is
largest without a local cache (`panelize(cache = "none")`), where
pruning turns a whole-file transfer into a few range requests.

Parquet stores every efile column as a string. The read paths therefore
cast numeric fields using the types declared in
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md),
rather than inferring them the way `fread()` and `read_csv_auto()` do.
Declared types are the more reliable of the two, but they are not
identical to the inferred ones: a parquet read returns `ORG_EIN` and the
other EIN, phone, and code fields as text (preserving leading zeros),
and leaves dates, timestamps, and checkboxes as source strings.

Reading parquet needs the suggested package `duckdb` or `arrow`. When
neither is installed the default falls back to `"csv"` with a message;
an explicit `format = "parquet"` is kept and fails at read time instead.

## Examples

``` r
data_source()                          # current release, parquet
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v3_1/"
#> 
#> $version
#> [1] "v3_1"
#> 
#> $format
#> [1] "parquet"
#> 
#> $aliases
#>                                P00                                P01 
#>                "F9-P00-T00-HEADER"               "F9-P01-T00-SUMMARY" 
#>                                P08                                P09 
#>               "F9-P08-T00-REVENUE"              "F9-P09-T00-EXPENSES" 
#>                                P10                                P11 
#>         "F9-P10-T00-BALANCE-SHEET"                "F9-P11-T00-ASSETS" 
#>                                P12                                A01 
#>   "F9-P12-T00-FINANCIAL-REPORTING" "SA-P01-T00-PUBLIC-CHARITY-STATUS" 
#> 
#> $form
#> [1] "990"
#> 
#> attr(,"class")
#> [1] "data_source"
data_source(version = "v2_3")          # pin the previous release
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_3/"
#> 
#> $version
#> [1] "v2_3"
#> 
#> $format
#> [1] "parquet"
#> 
#> $aliases
#>                                P00                                P01 
#>                "F9-P00-T00-HEADER"               "F9-P01-T00-SUMMARY" 
#>                                P08                                P09 
#>               "F9-P08-T00-REVENUE"              "F9-P09-T00-EXPENSES" 
#>                                P10                                P11 
#>         "F9-P10-T00-BALANCE-SHEET"                "F9-P11-T00-ASSETS" 
#>                                P12                                A01 
#>   "F9-P12-T00-FINANCIAL-REPORTING" "SA-P01-T00-PUBLIC-CHARITY-STATUS" 
#> 
#> $form
#> [1] "990"
#> 
#> attr(,"class")
#> [1] "data_source"
data_source(format = "csv")            # same release, CSV files
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v3_1/"
#> 
#> $version
#> [1] "v3_1"
#> 
#> $format
#> [1] "csv"
#> 
#> $aliases
#>                                P00                                P01 
#>                "F9-P00-T00-HEADER"               "F9-P01-T00-SUMMARY" 
#>                                P08                                P09 
#>               "F9-P08-T00-REVENUE"              "F9-P09-T00-EXPENSES" 
#>                                P10                                P11 
#>         "F9-P10-T00-BALANCE-SHEET"                "F9-P11-T00-ASSETS" 
#>                                P12                                A01 
#>   "F9-P12-T00-FINANCIAL-REPORTING" "SA-P01-T00-PUBLIC-CHARITY-STATUS" 
#> 
#> $form
#> [1] "990"
#> 
#> attr(,"class")
#> [1] "data_source"
data_source(form = "990PF")            # the 990PF release
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efilepf_v3_1/"
#> 
#> $version
#> [1] "v3_1"
#> 
#> $format
#> [1] "parquet"
#> 
#> $aliases
#>                                        P00 
#>                        "F9-P00-T00-HEADER" 
#>                                       PF00 
#>                        "PF-P00-T00-HEADER" 
#>                                       PF01 
#>               "PF-P01-T00-REVENUE-EXPENSE" 
#>                                       PF02 
#>                 "PF-P02-T00-BALANCE-SHEET" 
#>                                       PF03 
#> "PF-P03-T00-NET-ASSET-FUND-BALANCE-CHANGE" 
#> 
#> $form
#> [1] "990PF"
#> 
#> attr(,"class")
#> [1] "data_source"
```
