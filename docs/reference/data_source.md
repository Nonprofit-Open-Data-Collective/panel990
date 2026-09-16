# Create an efile source configuration

The NCCS efile release is versioned. Leave `root` as `NULL` to point at
a published release by `version`, or pass `root` explicitly to read from
a local directory or a mirror, in which case `version` is recorded as
`NA`.

## Usage

``` r
data_source(root = NULL, version = .EFILE_VERSION, aliases = .EFILE_ALIASES)
```

## Arguments

- root:

  Base URL or local directory containing table-year CSV files. `NULL`
  (default) builds the URL for `version`.

- version:

  Published release, such as `"v2_2"` (the current default) or `"v2_1"`.
  Ignored when `root` is supplied.

- aliases:

  Named character vector mapping short aliases to table names.

## Value

An `data_source` object carrying `root`, `version`, and `aliases`.

## Examples

``` r
data_source()                   # current release
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_2/"
#> 
#> $version
#> [1] "v2_2"
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
data_source(version = "v2_1")   # pin the previous release
#> $root
#> [1] "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_1/"
#> 
#> $version
#> [1] "v2_1"
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
