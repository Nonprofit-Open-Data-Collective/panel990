# Catalog of canonical efile tables

Returns the full reference set of NCCS efile tables in one form family's
release, each with its join cardinality and short alias where one is
defined: Form 990/990EZ core and Schedules A-R for `"990"`, or the 990PF
parts and supporting statements (plus the shared header, signature, and
Schedule B tables) for `"990PF"`. Cardinality is derived from the
table's T-number: `1x1` (one row per filing, T00), `1xm` (repeating
rows, T01-T98), or `supplemental` (free-text, T99). In the 990PF release
the `PF-P99-Txx` supporting-statement tables are numbered by statement,
so `T00` is `1x1` and the rest are `1xm`.

## Usage

``` r
table_catalog(
  cardinality = c("all", "1x1", "1xm", "supplemental"),
  form = "990"
)
```

## Arguments

- cardinality:

  Filter to `"all"` (default), `"1x1"`, `"1xm"`, or `"supplemental"`.

- form:

  Form family: `"990"` (default) or `"990PF"`.

## Value

A data frame with columns `table`, `alias` (NA when none), and
`cardinality`, one row per canonical table.

## Examples

``` r
table_catalog("1x1")
#>                                             table alias cardinality
#> 1                               F9-P00-T00-HEADER   P00         1x1
#> 2                              F9-P01-T00-SUMMARY   P01         1x1
#> 3                           F9-P01-T00-SUMMARY-EZ  <NA>         1x1
#> 4                            F9-P02-T00-SIGNATURE  <NA>         1x1
#> 5                              F9-P03-T00-MISSION  <NA>         1x1
#> 6                          F9-P03-T00-PROGRAM-ONE  <NA>         1x1
#> 7                        F9-P03-T00-PROGRAM-THREE  <NA>         1x1
#> 8                          F9-P03-T00-PROGRAM-TWO  <NA>         1x1
#> 9                             F9-P03-T00-PROGRAMS  <NA>         1x1
#> 10                  F9-P04-T00-REQUIRED-SCHEDULES  <NA>         1x1
#> 11               F9-P04-T00-REQUIRED-SCHEDULES-EZ  <NA>         1x1
#> 12                    F9-P05-T00-OTHER-IRS-FILING  <NA>         1x1
#> 13                          F9-P06-T00-GOVERNANCE  <NA>         1x1
#> 14                       F9-P06-T00-GOVERNANCE-EZ  <NA>         1x1
#> 15                       F9-P07-T00-DIR-TRUST-KEY  <NA>         1x1
#> 16                             F9-P08-T00-REVENUE   P08         1x1
#> 17                            F9-P09-T00-EXPENSES   P09         1x1
#> 18                       F9-P10-T00-BALANCE-SHEET   P10         1x1
#> 19                              F9-P11-T00-ASSETS   P11         1x1
#> 20                 F9-P12-T00-FINANCIAL-REPORTING   P12         1x1
#> 21                              SA-P00-T00-HEADER  <NA>         1x1
#> 22               SA-P01-T00-PUBLIC-CHARITY-STATUS   A01         1x1
#> 23                SA-P02-T00-SUPPORT_SCHEDULE_170  <NA>         1x1
#> 24                SA-P03-T00-SUPPORT_SCHEDULE_509  <NA>         1x1
#> 25                        SA-P04-T00-SUPPORT-ORGS  <NA>         1x1
#> 26                        SA-P05-T00-SUPPORT-ORGS  <NA>         1x1
#> 27                              SB-P00-T00-HEADER  <NA>         1x1
#> 28               SB-P03-T00-EXCLUSIVELY-RELIGIOUS  <NA>         1x1
#> 29                               SC-P01-T00-LOBBY  <NA>         1x1
#> 30                               SC-P02-T00-LOBBY  <NA>         1x1
#> 31                               SC-P03-T00-LOBBY  <NA>         1x1
#> 32        SD-P01-T00-ORGS-DONOR-ADVISED-FUNDS-OTH  <NA>         1x1
#> 33                   SD-P02-T00-CONSERV-EASEMENTS  <NA>         1x1
#> 34  SD-P03-T00-ORGS-COLLECT-ART-HIST-TREASURE-OTH  <NA>         1x1
#> 35       SD-P04-T00-ESCROW-CUSTODIAL-ARRANGEMENTS  <NA>         1x1
#> 36                           SD-P05-T00-ENDOWMENT  <NA>         1x1
#> 37                     SD-P06-T00-LAND-BLDG-EQUIP  <NA>         1x1
#> 38         SD-P07-T00-INVESTMENTS-OTH-DERIVATIVES  <NA>         1x1
#> 39              SD-P07-T00-INVESTMENTS-OTH-EQUITY  <NA>         1x1
#> 40              SD-P07-T00-INVESTMENTS-SECURITIES  <NA>         1x1
#> 41               SD-P08-T00-INVESTMENTS-PROG-RLTD  <NA>         1x1
#> 42                          SD-P09-T00-OTH-ASSETS  <NA>         1x1
#> 43                     SD-P10-T00-OTH-LIABILITIES  <NA>         1x1
#> 44              SD-P11-T00-RECONCILIATION-REVENUE  <NA>         1x1
#> 45             SD-P12-T00-RECONCILIATION-EXPENSES  <NA>         1x1
#> 46            SD-P99-T00-RECONCILIATION-NETASSETS  <NA>         1x1
#> 47                             SE-P01-T00-SCHOOLS  <NA>         1x1
#> 48                           SF-P01-T00-FRGN-ACTS  <NA>         1x1
#> 49                     SF-P02-T00-FRGN-ORG-GRANTS  <NA>         1x1
#> 50                      SF-P04-T00-FRGN-INTERESTS  <NA>         1x1
#> 51                     SF-P99-T00-FRGN-ORG-GRANTS  <NA>         1x1
#> 52                    SG-P01-T00-FUNDRAISING-ACTS  <NA>         1x1
#> 53                  SG-P02-T00-FUNDRAISING-EVENTS  <NA>         1x1
#> 54                              SG-P03-T00-GAMING  <NA>         1x1
#> 55        SH-P01-T00-FAP-COMMUNITY-BENEFIT-POLICY  <NA>         1x1
#> 56        SH-P02-T00-FAP-COMMUNITY-BENEFIT-POLICY  <NA>         1x1
#> 57        SH-P03-T00-FAP-COMMUNITY-BENEFIT-POLICY  <NA>         1x1
#> 58        SH-P05-T00-FAP-COMMUNITY-BENEFIT-POLICY  <NA>         1x1
#> 59                         SI-P01-T00-GRANTS-INFO  <NA>         1x1
#> 60                SI-P02-T00-GRANTS-US-ORGS-GOVTS  <NA>         1x1
#> 61                SI-P99-T00-GRANTS-US-ORGS-GOVTS  <NA>         1x1
#> 62                        SJ-P01-T00-COMPENSATION  <NA>         1x1
#> 63              SL-P01-T00-EXCESS-BENEFIT-TRANSAC  <NA>         1x1
#> 64               SL-P02-T00-LOANS-INTERESTED-PERS  <NA>         1x1
#> 65               SM-P01-T00-NONCASH-CONTRIBUTIONS  <NA>         1x1
#> 66 SN-P01-T00-LIQUIDATION-TERMINATION-DISSOLUTION  <NA>         1x1
#> 67               SN-P02-T00-DISPOSITION-OF-ASSETS  <NA>         1x1
#> 68 SN-P99-T00-LIQUIDATION-TERMINATION-DISSOLUTION  <NA>         1x1
#> 69              SR-P05-T00-TRANSACTIONS-RLTD-ORGS  <NA>         1x1
table_catalog(form = "990PF")
#>                                            table alias cardinality
#> 1                              F9-P00-T00-HEADER   P00         1x1
#> 2                           F9-P02-T00-SIGNATURE  <NA>         1x1
#> 3                              SB-P00-T00-HEADER  <NA>         1x1
#> 4                        SB-P01-T01-CONTRIBUTORS  <NA>         1xm
#> 5                    SB-P02-T01-NONCASH-PROPERTY  <NA>         1xm
#> 6               SB-P03-T00-EXCLUSIVELY-RELIGIOUS  <NA>         1x1
#> 7               SB-P03-T01-EXCLUSIVELY-RELIGIOUS  <NA>         1xm
#> 8                              PF-P00-T00-HEADER  PF00         1x1
#> 9                     PF-P01-T00-REVENUE-EXPENSE  PF01         1x1
#> 10                      PF-P02-T00-BALANCE-SHEET  PF02         1x1
#> 11      PF-P03-T00-NET-ASSET-FUND-BALANCE-CHANGE  PF03         1x1
#> 12 PF-P04-T00-INVEST-INCOME-TAX-CAPITAL-GAINLOSS  <NA>         1x1
#> 13 PF-P04-T01-INVEST-INCOME-TAX-CAPITAL-GAINLOSS  <NA>         1xm
#> 14        PF-P05-T00-NET-INVEST-INCOME-TAX-4940E  <NA>         1x1
#> 15           PF-P06-T00-INVEST-INCOME-EXCISE-TAX  <NA>         1x1
#> 16                         PF-P07-T00-ACTIVITIES  <NA>         1x1
#> 17                    PF-P07-T00-ACTIVITIES-4720  <NA>         1x1
#> 18           PF-P08-T00-COMPENSATION-CONTRACTORS  <NA>         1x1
#> 19               PF-P08-T00-COMPENSATION-HIGHEST  <NA>         1x1
#> 20                       PF-P08-T01-COMPENSATION  <NA>         1xm
#> 21               PF-P08-T02-COMPENSATION-HIGHEST  <NA>         1xm
#> 22           PF-P08-T03-COMPENSATION-CONTRACTORS  <NA>         1xm
#> 23           PF-P09-T00-PROG-RELATED-INVESTMENTS  <NA>         1x1
#> 24              PF-P09-T01-CHARITABLE-ACTIVITIES  <NA>         1xm
#> 25           PF-P09-T02-PROG-RELATED-INVESTMENTS  <NA>         1xm
#> 26          PF-P10-T00-MINIMUM-INVESTMENT-RETURN  <NA>         1x1
#> 27               PF-P11-T00-DISTRIBUTABLE-AMOUNT  <NA>         1x1
#> 28           PF-P12-T00-QUALIFYING-DISTRIBUTIONS  <NA>         1x1
#> 29               PF-P13-T00-UNDISTRIBUTED-INCOME  <NA>         1x1
#> 30      PF-P14-T00-PRIVATE-OPERATING-FOUNDATIONS  <NA>         1x1
#> 31                 PF-P15-T00-SUPPLEMENTARY-INFO  <NA>         1x1
#> 32    PF-P15-T00-SUPPLEMENTARY-INFO-GRANT-FUTURE  <NA>         1x1
#> 33      PF-P15-T00-SUPPLEMENTARY-INFO-GRANT-PAID  <NA>         1x1
#> 34      PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID  <NA>         1xm
#> 35    PF-P15-T02-SUPPLEMENTARY-INFO-GRANT-FUTURE  <NA>         1xm
#> 36       PF-P15-T03-SUPPLEMENTARY-INFO-GRANT-APP  <NA>         1xm
#> 37              PF-P16-T00-INCOME-PRODUCING-ACTS  <NA>         1x1
#> 38              PF-P16-T01-INCOME-PRODUCING-ACTS  <NA>         1xm
#> 39              PF-P16-T02-INCOME-PRODUCING-ACTS  <NA>         1xm
#> 40   PF-P16-T03-ACTS-RELATIONSHIP-EXEMPT-PURPOSE  <NA>         1xm
#> 41                      PF-P17-T00-RELATIONSHIPS  <NA>         1x1
#> 42             PF-P17-T00-TRANSFERS-TRANSACTIONS  <NA>         1x1
#> 43             PF-P17-T01-TRANSFERS-TRANSACTIONS  <NA>         1xm
#> 44                      PF-P17-T02-RELATIONSHIPS  <NA>         1xm
#> 45                         PF-P99-T00-AUXILLIARY  <NA>         1x1
#> 46                           PF-P99-T01-ACC-FEES  <NA>         1xm
#> 47                    PF-P99-T03-PROG-INVEST-OTH  <NA>         1xm
#> 48                       PF-P99-T04-AMORTIZATION  <NA>         1xm
#> 49                      PF-P99-T06-FUND-BORROWED  <NA>         1xm
#> 50                               PF-P99-T09-COMP  <NA>         1xm
#> 51                         PF-P99-T10-COMP-KONTR  <NA>         1xm
#> 52                             PF-P99-T11-DEPREC  <NA>         1xm
#> 53                        PF-P99-T12-DISSOLUTION  <NA>         1xm
#> 54                          PF-P99-T14-COMP-EMPL  <NA>         1xm
#> 55                 PF-P99-T16-EXP-RESPONSIBILITY  <NA>         1xm
#> 56                    PF-P99-T19-SALE-NONPUB-SEC  <NA>         1xm
#> 57                     PF-P99-T20-SALE-OTH-ASSET  <NA>         1xm
#> 58                       PF-P99-T21-SALE-PUB-SEC  <NA>         1xm
#> 59                  PF-P99-T22-SUPPLEMENTAL-INFO  <NA>         1xm
#> 60                   PF-P99-T23-INVEST-CORP-BOND  <NA>         1xm
#> 61                  PF-P99-T24-INVEST-CORP-STOCK  <NA>         1xm
#> 62                    PF-P99-T25-INVEST-GOVT-SEC  <NA>         1xm
#> 63                        PF-P99-T26-INVEST-LAND  <NA>         1xm
#> 64                         PF-P99-T27-INVEST-OTH  <NA>         1xm
#> 65                           PF-P99-T28-LAND-ETC  <NA>         1xm
#> 66                         PF-P99-T29-LEGAL-FEES  <NA>         1xm
#> 67                           PF-P99-T31-LOAN-OFF  <NA>         1xm
#> 68                           PF-P99-T32-MTG-NOTE  <NA>         1xm
#> 69                          PF-P99-T33-ASSET-OTH  <NA>         1xm
#> 70                    PF-P99-T34-NETASSET-CHANGE  <NA>         1xm
#> 71                       PF-P99-T35-DECREASE-OTH  <NA>         1xm
#> 72                            PF-P99-T36-EXP-OTH  <NA>         1xm
#> 73                         PF-P99-T37-INCOME-OTH  <NA>         1xm
#> 74                       PF-P99-T38-INCREASE-OTH  <NA>         1xm
#> 75                           PF-P99-T39-LIAB-OTH  <NA>         1xm
#> 76                 PF-P99-T40-NOTE-LOAN-OTH-LONG  <NA>         1xm
#> 77                PF-P99-T41-NOTE-LOAN-OTH-SHORT  <NA>         1xm
#> 78                      PF-P99-T42-PROF-FEES-OTH  <NA>         1xm
#> 79                            PF-P99-T43-OFF-OTH  <NA>         1xm
#> 80                           PF-P99-T46-SALE-INV  <NA>         1xm
#> 81                        PF-P99-T48-CONTRIBUTOR  <NA>         1xm
#> 82                              PF-P99-T49-TAXES  <NA>         1xm
#> 83                   PF-P99-T51-TRANSFER-FROM-CE  <NA>         1xm
#> 84                     PF-P99-T52-TRANSFER-TO-CE  <NA>         1xm
```
