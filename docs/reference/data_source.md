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
  format = .EFILE_FORMAT,
  aliases = .EFILE_ALIASES
)
```

## Arguments

- root:

  Base URL or local directory containing table-year files. `NULL`
  (default) builds the URL for `version`.

- version:

  Published release, such as `"v2_2"` (the current default) or `"v2_1"`.
  Ignored when `root` is supplied.

- format:

  Source file format: `"csv"` (the current default) or `"parquet"`. See
  the Source format section.

- aliases:

  Named character vector mapping short aliases to table names.

## Value

An `data_source` object carrying `root`, `version`, `format`, and
`aliases`.

## Source format

A release publishes each table-year under one stem in two formats, so
`format` is an extension swap on an otherwise identical URL. Parquet
pays off for *selective* reads and only there: the files are sorted by
`EIN2` with non-overlapping row-group statistics, so an entity
restriction prunes row groups and a column projection reads only the
chunks it needs. Reading a whole table is no faster than reading the
CSV. The gain is largest without a local cache
(`panelize(cache = "none")`), where pruning turns a whole-file transfer
into a few range requests.

Parquet stores every efile column as a string. The read paths therefore
cast numeric fields using the types declared in
[field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md),
rather than inferring them the way `fread()` and `read_csv_auto()` do.
Declared types are the more reliable of the two, but they are not
identical to the inferred ones: a parquet read returns `ORG_EIN` as text
(preserving leading zeros), and leaves dates, timestamps, and checkboxes
as source strings.

## Examples

``` r
data_source()                          # current release, CSV
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_2/"
#> 
#> $version
#> [1] "v2_2"
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
#> attr(,"class")
#> [1] "data_source"
data_source(version = "v2_1")          # pin the previous release
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_1/"
#> 
#> $version
#> [1] "v2_1"
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
#> attr(,"class")
#> [1] "data_source"
data_source(format = "parquet")        # same release, parquet files
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_2/"
#> 
#> $version
#> [1] "v2_2"
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
#> attr(,"class")
#> [1] "data_source"
```
