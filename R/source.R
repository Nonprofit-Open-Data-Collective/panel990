# The published efile release is versioned in the S3 prefix. Keep the bucket
# and the version separate so callers can move between releases without
# rebuilding the URL by hand; `.EFILE_VERSION` is only the default.
.EFILE_BUCKET <- "https://nccs-efile.s3.us-east-1.amazonaws.com/public/"
.EFILE_VERSION <- "v2_3"

# Each release is published as two databases under sibling prefixes: Form 990
# and 990EZ filers together under efile_, and 990PF filers under efilepf_. A
# source reads exactly one of them; the two are never mixed in one panel.
.EFILE_FORMS <- c("990", "990PF")
.EFILE_PREFIX <- c("990" = "efile_", "990PF" = "efilepf_")

.efile_version_root <- function(version, form = "990") {
  paste0(.EFILE_BUCKET, .EFILE_PREFIX[[form]], version, "/")
}

.EFILE_ROOT <- .efile_version_root(.EFILE_VERSION)

#' Normalize a form-family string
#'
#' @param form User-supplied form family.
#' @return `"990"` or `"990PF"`.
#' @keywords internal
.efile_form <- function(form) {
  if (!is.character(form) || length(form) != 1L || is.na(form) || !nzchar(form))
    stop("`form` must be one of: ", paste(.EFILE_FORMS, collapse = ", "))
  out <- toupper(gsub("[[:space:]-]", "", form))
  if (out %in% c("PF", "990PF")) return("990PF")
  if (out == "990") return("990")
  if (out == "990EZ")
    stop("990EZ filers are published with full 990 filers; use `form = \"990\"` ",
         "and filter on RETURN_TYPE.")
  stop("`form` must be one of: ", paste(.EFILE_FORMS, collapse = ", "),
       "; received \"", form, "\".")
}

.EFILE_ALIASES <- c(
  P00 = "F9-P00-T00-HEADER",
  P01 = "F9-P01-T00-SUMMARY",
  P08 = "F9-P08-T00-REVENUE",
  P09 = "F9-P09-T00-EXPENSES",
  P10 = "F9-P10-T00-BALANCE-SHEET",
  P11 = "F9-P11-T00-ASSETS",
  P12 = "F9-P12-T00-FINANCIAL-REPORTING",
  A01 = "SA-P01-T00-PUBLIC-CHARITY-STATUS"
)

# Canonical NCCS efile table names (Form 990/990EZ core + Schedules A-R). This
# is a reference catalog: resolve_tables() still accepts any literal name so
# newly published tables work without a package update, but membership here
# flags a request as `known` and powers table_catalog().
.EFILE_TABLES <- c(
  # Form 990 / 990EZ core
  "F9-P00-T00-HEADER",
  "F9-P00-T01-AFFILIATE-LISTING",
  "F9-P01-T00-SUMMARY",
  "F9-P01-T00-SUMMARY-EZ",
  "F9-P02-T00-SIGNATURE",
  "F9-P03-T00-MISSION",
  "F9-P03-T00-PROGRAM-ONE",
  "F9-P03-T00-PROGRAM-THREE",
  "F9-P03-T00-PROGRAM-TWO",
  "F9-P03-T00-PROGRAMS",
  "F9-P03-T01-PROGRAMS-OTHER",
  "F9-P03-T02-PROGRAMS-EZ",
  "F9-P04-T00-REQUIRED-SCHEDULES",
  "F9-P04-T00-REQUIRED-SCHEDULES-EZ",
  "F9-P05-T00-OTHER-IRS-FILING",
  "F9-P06-T00-GOVERNANCE",
  "F9-P06-T00-GOVERNANCE-EZ",
  "F9-P07-T00-DIR-TRUST-KEY",
  "F9-P07-T01-COMPENSATION",
  "F9-P07-T01-COMPENSATION-HCE-EZ",
  "F9-P07-T02-CONTRACTORS",
  "F9-P08-T00-REVENUE",
  "F9-P08-T01-REVENUE-PROGRAMS",
  "F9-P08-T02-REVENUE-MISC",
  "F9-P09-T00-EXPENSES",
  "F9-P09-T01-EXPENSES-OTHER",
  "F9-P10-T00-BALANCE-SHEET",
  "F9-P11-T00-ASSETS",
  "F9-P12-T00-FINANCIAL-REPORTING",
  # Schedule A
  "SA-P00-T00-HEADER",
  "SA-P01-T00-PUBLIC-CHARITY-STATUS",
  "SA-P01-T01-PUBLIC-CHARITY-STATUS",
  "SA-P01-T02-HOSPITAL-NAME-ADDRESS",
  "SA-P01-T03-AGRI-RESEARCH-UNIV",
  "SA-P02-T00-SUPPORT_SCHEDULE_170",
  "SA-P03-T00-SUPPORT_SCHEDULE_509",
  "SA-P04-T00-SUPPORT-ORGS",
  "SA-P05-T00-SUPPORT-ORGS",
  "SA-P06-T99-SUPPLEMENTAL-INFO",
  # Schedule B
  "SB-P00-T00-HEADER",
  "SB-P01-T01-CONTRIBUTORS",
  "SB-P02-T01-NONCASH-PROPERTY",
  "SB-P03-T00-EXCLUSIVELY-RELIGIOUS",
  "SB-P03-T01-EXCLUSIVELY-RELIGIOUS",
  # Schedule C
  "SC-P01-T00-LOBBY",
  "SC-P01-T01-POLITICAL-ORGS-INFO",
  "SC-P02-T00-LOBBY",
  "SC-P02-T01-AFFILIATED-GROUP",
  "SC-P03-T00-LOBBY",
  "SC-P04-T99-SUPPLEMENTAL-INFO",
  # Schedule D
  "SD-P01-T00-ORGS-DONOR-ADVISED-FUNDS-OTH",
  "SD-P02-T00-CONSERV-EASEMENTS",
  "SD-P03-T00-ORGS-COLLECT-ART-HIST-TREASURE-OTH",
  "SD-P04-T00-ESCROW-CUSTODIAL-ARRANGEMENTS",
  "SD-P05-T00-ENDOWMENT",
  "SD-P06-T00-LAND-BLDG-EQUIP",
  "SD-P07-T00-INVESTMENTS-OTH-DERIVATIVES",
  "SD-P07-T00-INVESTMENTS-OTH-EQUITY",
  "SD-P07-T00-INVESTMENTS-SECURITIES",
  "SD-P07-T01-INVESTMENTS-OTH-SECURITIES",
  "SD-P08-T00-INVESTMENTS-PROG-RLTD",
  "SD-P08-T01-INVESTMENTS-PROG-RLTD",
  "SD-P09-T00-OTH-ASSETS",
  "SD-P09-T01-OTH-ASSETS",
  "SD-P10-T00-OTH-LIABILITIES",
  "SD-P10-T01-OTH-LIABILITIES",
  "SD-P11-T00-RECONCILIATION-REVENUE",
  "SD-P12-T00-RECONCILIATION-EXPENSES",
  "SD-P13-T99-SUPPLEMENTAL-INFO",
  "SD-P99-T00-RECONCILIATION-NETASSETS",
  # Schedule E
  "SE-P01-T00-SCHOOLS",
  "SE-P02-T99-SUPPLEMENTAL-INFO",
  # Schedule F
  "SF-P01-T00-FRGN-ACTS",
  "SF-P01-T01-FRGN-ACTS-BY-REGION",
  "SF-P02-T00-FRGN-ORG-GRANTS",
  "SF-P02-T01-FRGN-ORG-GRANTS",
  "SF-P03-T01-FRGN-INDIV-GRANTS",
  "SF-P04-T00-FRGN-INTERESTS",
  "SF-P05-T99-EXPLANATION-TEXT",
  "SF-P99-T00-FRGN-ORG-GRANTS",
  # Schedule G
  "SG-P01-T00-FUNDRAISING-ACTS",
  "SG-P01-T01-FUNDRAISERS-INFO",
  "SG-P02-T00-FUNDRAISING-EVENTS",
  "SG-P03-T00-GAMING",
  "SG-P04-T99-SUPPLEMENTAL-INFO",
  # Schedule H
  "SH-P01-T00-FAP-COMMUNITY-BENEFIT-POLICY",
  "SH-P02-T00-FAP-COMMUNITY-BENEFIT-POLICY",
  "SH-P03-T00-FAP-COMMUNITY-BENEFIT-POLICY",
  "SH-P04-T01-COMPANY-JOINT-VENTURES",
  "SH-P05-T00-FAP-COMMUNITY-BENEFIT-POLICY",
  "SH-P05-T01-HOSPITAL-FACILITY",
  "SH-P05-T02-NON-HOSPITAL-FACILITY",
  "SH-P05-T03-FACILITY-POLICIES-PRACTICES",
  "SH-P05-T99-SUPPLEMENTAL-INFO",
  "SH-P06-T99-SUPPLEMENTAL-INFO",
  "SH-P99-T01-FAP-COMMUNITY-BENEFIT-POLICY",
  # Schedule I
  "SI-P01-T00-GRANTS-INFO",
  "SI-P02-T00-GRANTS-US-ORGS-GOVTS",
  "SI-P02-T01-GRANTS-US-ORGS-GOVTS",
  "SI-P03-T01-GRANTS-US-INDIV",
  "SI-P04-T99-SUPPLEMENTAL-INFO",
  "SI-P99-T00-GRANTS-US-ORGS-GOVTS",
  # Schedule J
  "SJ-P01-T00-COMPENSATION",
  "SJ-P02-T01-COMPENSATION-DTK",
  "SJ-P03-T99-SUPPLEMENTAL-INFO",
  # Schedule K
  "SK-P01-T01-BOND-ISSUES",
  "SK-P02-T01-BOND-PROCEEDS",
  "SK-P03-T01-BOND-PRIVATE-BIZ-USE",
  "SK-P04-T01-BOND-ARBITRAGE",
  "SK-P05-T01-PROCEDURE-CORRECTIVE-ACT",
  "SK-P06-T99-SUPPLEMENTAL-INFO",
  # Schedule L
  "SL-P01-T00-EXCESS-BENEFIT-TRANSAC",
  "SL-P01-T01-EXCESS-BENEFIT-TRANSAC",
  "SL-P02-T00-LOANS-INTERESTED-PERS",
  "SL-P02-T01-LOANS-INTERESTED-PERS",
  "SL-P03-T01-GRANTS-INTERESTED-PERS",
  "SL-P04-T01-BIZ-TRANSAC-INTERESTED-PERS",
  "SL-P05-T99-SUPPLEMENTAL-INFO",
  # Schedule M
  "SM-P01-T00-NONCASH-CONTRIBUTIONS",
  "SM-P01-T01-NONCASH-CONTRIBUTIONS",
  "SM-P02-T99-SUPPLEMENTAL-INFO",
  # Schedule N
  "SN-P01-T00-LIQUIDATION-TERMINATION-DISSOLUTION",
  "SN-P01-T01-LIQUIDATION-TERMINATION-DISSOLUTION",
  "SN-P02-T00-DISPOSITION-OF-ASSETS",
  "SN-P02-T01-DISPOSITION-OF-ASSETS",
  "SN-P03-T99-SUPPLEMENTAL-INFO",
  "SN-P99-T00-LIQUIDATION-TERMINATION-DISSOLUTION",
  # Schedule O
  "SO-P00-T99-SUPPLEMENTAL-INFO",
  # Schedule R
  "SR-P01-T01-ID-DISREGARDED-ENTITIES",
  "SR-P02-T01-ID-RLTD-TAX-EXEMPED-ORGS",
  "SR-P03-T01-ID-RLTD-ORGS-TAXABLE-PARTNERSHIP",
  "SR-P04-T01-ID-RLTD-ORGS-TAXABLE-CORPORATION",
  "SR-P05-T00-TRANSACTIONS-RLTD-ORGS",
  "SR-P05-T01-TRANSACTIONS-RLTD-ORGS",
  "SR-P06-T01-UNRLTD-ORGS-TAXABLE-PARTNERSHIP",
  "SR-P07-T99-SUPPLEMENTAL-INFO"
)

# Aliases for the 990PF release. PF parts get their own PF-prefixed names so
# that no alias means one table in a 990 source and another in a PF source.
# P00 is the exception that proves the rule: F9-P00-T00-HEADER is published
# under the same name in both releases, so the alias means the same table.
.EFILE_ALIASES_PF <- c(
  P00  = "F9-P00-T00-HEADER",
  PF00 = "PF-P00-T00-HEADER",
  PF01 = "PF-P01-T00-REVENUE-EXPENSE",
  PF02 = "PF-P02-T00-BALANCE-SHEET",
  PF03 = "PF-P03-T00-NET-ASSET-FUND-BALANCE-CHANGE"
)

# Canonical NCCS efile table names in the 990PF release: the PF-* tables plus
# the release's own copies of the shared header, signature, and Schedule B
# tables.
.EFILE_TABLES_PF <- c(
  # Shared with the 990 release
  "F9-P00-T00-HEADER",
  "F9-P02-T00-SIGNATURE",
  "SB-P00-T00-HEADER",
  "SB-P01-T01-CONTRIBUTORS",
  "SB-P02-T01-NONCASH-PROPERTY",
  "SB-P03-T00-EXCLUSIVELY-RELIGIOUS",
  "SB-P03-T01-EXCLUSIVELY-RELIGIOUS",
  # Form 990PF parts
  "PF-P00-T00-HEADER",
  "PF-P01-T00-REVENUE-EXPENSE",
  "PF-P02-T00-BALANCE-SHEET",
  "PF-P03-T00-NET-ASSET-FUND-BALANCE-CHANGE",
  "PF-P04-T00-INVEST-INCOME-TAX-CAPITAL-GAINLOSS",
  "PF-P04-T01-INVEST-INCOME-TAX-CAPITAL-GAINLOSS",
  "PF-P05-T00-NET-INVEST-INCOME-TAX-4940E",
  "PF-P06-T00-INVEST-INCOME-EXCISE-TAX",
  "PF-P07-T00-ACTIVITIES",
  "PF-P07-T00-ACTIVITIES-4720",
  "PF-P08-T00-COMPENSATION-CONTRACTORS",
  "PF-P08-T00-COMPENSATION-HIGHEST",
  "PF-P08-T01-COMPENSATION",
  "PF-P08-T02-COMPENSATION-HIGHEST",
  "PF-P08-T03-COMPENSATION-CONTRACTORS",
  "PF-P09-T00-PROG-RELATED-INVESTMENTS",
  "PF-P09-T01-CHARITABLE-ACTIVITIES",
  "PF-P09-T02-PROG-RELATED-INVESTMENTS",
  "PF-P10-T00-MINIMUM-INVESTMENT-RETURN",
  "PF-P11-T00-DISTRIBUTABLE-AMOUNT",
  "PF-P12-T00-QUALIFYING-DISTRIBUTIONS",
  "PF-P13-T00-UNDISTRIBUTED-INCOME",
  "PF-P14-T00-PRIVATE-OPERATING-FOUNDATIONS",
  "PF-P15-T00-SUPPLEMENTARY-INFO",
  "PF-P15-T00-SUPPLEMENTARY-INFO-GRANT-FUTURE",
  "PF-P15-T00-SUPPLEMENTARY-INFO-GRANT-PAID",
  "PF-P15-T01-SUPPLEMENTARY-INFO-GRANT-PAID",
  "PF-P15-T02-SUPPLEMENTARY-INFO-GRANT-FUTURE",
  "PF-P15-T03-SUPPLEMENTARY-INFO-GRANT-APP",
  "PF-P16-T00-INCOME-PRODUCING-ACTS",
  "PF-P16-T01-INCOME-PRODUCING-ACTS",
  "PF-P16-T02-INCOME-PRODUCING-ACTS",
  "PF-P16-T03-ACTS-RELATIONSHIP-EXEMPT-PURPOSE",
  "PF-P17-T00-RELATIONSHIPS",
  "PF-P17-T00-TRANSFERS-TRANSACTIONS",
  "PF-P17-T01-TRANSFERS-TRANSACTIONS",
  "PF-P17-T02-RELATIONSHIPS",
  # Form 990PF supporting statements
  "PF-P99-T00-AUXILLIARY",
  "PF-P99-T01-ACC-FEES",
  "PF-P99-T03-PROG-INVEST-OTH",
  "PF-P99-T04-AMORTIZATION",
  "PF-P99-T06-FUND-BORROWED",
  "PF-P99-T09-COMP",
  "PF-P99-T10-COMP-KONTR",
  "PF-P99-T11-DEPREC",
  "PF-P99-T12-DISSOLUTION",
  "PF-P99-T14-COMP-EMPL",
  "PF-P99-T16-EXP-RESPONSIBILITY",
  "PF-P99-T19-SALE-NONPUB-SEC",
  "PF-P99-T20-SALE-OTH-ASSET",
  "PF-P99-T21-SALE-PUB-SEC",
  "PF-P99-T22-SUPPLEMENTAL-INFO",
  "PF-P99-T23-INVEST-CORP-BOND",
  "PF-P99-T24-INVEST-CORP-STOCK",
  "PF-P99-T25-INVEST-GOVT-SEC",
  "PF-P99-T26-INVEST-LAND",
  "PF-P99-T27-INVEST-OTH",
  "PF-P99-T28-LAND-ETC",
  "PF-P99-T29-LEGAL-FEES",
  "PF-P99-T31-LOAN-OFF",
  "PF-P99-T32-MTG-NOTE",
  "PF-P99-T33-ASSET-OTH",
  "PF-P99-T34-NETASSET-CHANGE",
  "PF-P99-T35-DECREASE-OTH",
  "PF-P99-T36-EXP-OTH",
  "PF-P99-T37-INCOME-OTH",
  "PF-P99-T38-INCREASE-OTH",
  "PF-P99-T39-LIAB-OTH",
  "PF-P99-T40-NOTE-LOAN-OTH-LONG",
  "PF-P99-T41-NOTE-LOAN-OTH-SHORT",
  "PF-P99-T42-PROF-FEES-OTH",
  "PF-P99-T43-OFF-OTH",
  "PF-P99-T46-SALE-INV",
  "PF-P99-T48-CONTRIBUTOR",
  "PF-P99-T49-TAXES",
  "PF-P99-T51-TRANSFER-FROM-CE",
  "PF-P99-T52-TRANSFER-TO-CE"
)

.efile_aliases_for <- function(form) {
  if (identical(form, "990PF")) .EFILE_ALIASES_PF else .EFILE_ALIASES
}

.efile_tables_for <- function(form) {
  if (identical(form, "990PF")) .EFILE_TABLES_PF else .EFILE_TABLES
}

#' Create an efile source configuration
#'
#' The NCCS efile release is versioned. Leave `root` as `NULL` to point at a
#' published release by `version`, or pass `root` explicitly to read from a
#' local directory or a mirror, in which case `version` is recorded as `NA`.
#'
#' @section Form family:
#' Each release is published as two separate databases, and a source reads
#' exactly one of them:
#' \itemize{
#'   \item `form = "990"` (the default): full Form 990 and 990EZ filers
#'     together, told apart by `RETURN_TYPE`.
#'   \item `form = "990PF"`: private foundations filing Form 990PF.
#' }
#' The two are not combined in one panel: the 990PF financial statements have
#' a different structure from the 990 parts. The form family sets the URL
#' prefix (`efile_` or `efilepf_`), the default `aliases`, the
#' [table_catalog()], and the cache subdirectory used by [download_tables()].
#' [panelize_pf()] builds a panel from the 990PF release.
#'
#' @section Source format:
#' A release publishes each table-year under one stem in two formats, so
#' `format` is an extension swap on an otherwise identical URL. Parquet is the
#' default: it is an eighth of the bytes to transfer, and it pays off most for
#' *selective* reads, because the files are sorted by `EIN2`
#' with non-overlapping row-group statistics, so an entity restriction prunes
#' row groups and a column projection reads only the chunks it needs. Reading a
#' whole table is no faster than reading the CSV. The gain is largest without a
#' local cache (`panelize(cache = "none")`), where pruning turns a whole-file
#' transfer into a few range requests.
#'
#' Parquet stores every efile column as a string. The read paths therefore cast
#' numeric fields using the types declared in [field_concordance], rather than
#' inferring them the way `fread()` and `read_csv_auto()` do. Declared types are
#' the more reliable of the two, but they are not identical to the inferred
#' ones: a parquet read returns `ORG_EIN` and the other EIN, phone, and code
#' fields as text (preserving leading zeros), and leaves dates, timestamps, and
#' checkboxes as source strings.
#'
#' Reading parquet needs the suggested package `duckdb` or `arrow`. When
#' neither is installed the default falls back to `"csv"` with a message; an
#' explicit `format = "parquet"` is kept and fails at read time instead.
#'
#' @param root Base URL or local directory containing table-year files. `NULL`
#'   (default) builds the URL for `version`.
#' @param version Published release, such as `"v2_3"` (the current default) or
#'   `"v2_2"`. Ignored when `root` is supplied.
#' @param format Source file format: `"parquet"` (the default, when a parquet
#'   reader is installed) or `"csv"`. See the Source format section.
#' @param aliases Named character vector mapping short aliases to table names.
#'   `NULL` (default) uses the form family's aliases: `P00`, `P01`, `P08`-`P12`
#'   and `A01` for `"990"`; `P00` and `PF00`-`PF03` for `"990PF"`.
#' @param form Form family: `"990"` (default, Form 990 and 990EZ filers) or
#'   `"990PF"` (private foundations). See the Form family section.
#' @return An `data_source` object carrying `root`, `version`, `format`,
#'   `aliases`, and `form`.
#' @examples
#' data_source()                          # current release, parquet
#' data_source(version = "v2_2")          # pin the previous release
#' data_source(format = "csv")            # same release, CSV files
#' data_source(form = "990PF")            # the 990PF release
#' @export
data_source <- function(root = NULL, version = .EFILE_VERSION,
                        format = .efile_default_format(),
                        aliases = NULL, form = "990") {
  form <- .efile_form(form)
  if (is.null(aliases)) aliases <- .efile_aliases_for(form)
  if (is.null(root)) {
    if (!is.character(version) || length(version) != 1L || is.na(version) ||
        !nzchar(version))
      stop("`version` must be one non-empty string such as \"v2_3\".")
    version <- sub("^efile(pf)?_", "", tolower(trimws(version)))
    if (!grepl("^v[0-9]+_[0-9]+$", version))
      stop("`version` must look like \"v2_3\"; received \"", version, "\".")
    root <- .efile_version_root(version, form)
  } else {
    if (!is.character(root) || length(root) != 1L || is.na(root) || !nzchar(root))
      stop("`root` must be one non-empty URL or directory path.")
    version <- NA_character_
  }
  if (!is.character(aliases) || is.null(names(aliases)) || any(!nzchar(names(aliases))))
    stop("`aliases` must be a named character vector.")
  structure(list(root = root, version = version,
                 format = .efile_format(format), aliases = aliases, form = form),
            class = "data_source")
}

# Form family of a source. Sources built before the form field existed (for
# example, a saved panel) carry no `form` and are 990 sources.
.efile_source_form <- function(source) {
  form <- source$form
  if (is.null(form)) "990" else form
}

#' Current default efile release
#'
#' @return The version string used by [data_source()] when none is supplied.
#' @export
efile_version <- function() .EFILE_VERSION

.efile_table_cardinality <- function(table) {
  match_text <- regmatches(table, regexpr("-T[0-9]{2}(-|$)", table))
  if (!length(match_text) || !nzchar(match_text)) return("unknown")
  number <- as.integer(sub("-T([0-9]{2})(-|$)", "\\1", match_text))
  if (number == 0L) "1x1" else if (number == 99L) "supplemental" else "1xm"
}

#' Resolve aliases and literal efile table names
#'
#' Any non-empty literal table name is accepted, allowing newly published and
#' user-specified tables without a package update -- except that a table from
#' the other form family is an error: `PF-*` tables exist only in the 990PF
#' release, and the 990PF release holds only `PF-*` tables plus its copies of
#' the shared header, signature, and Schedule B tables.
#'
#' @param tables Character vector of aliases or canonical table names.
#' @param source An [data_source()] configuration.
#' @return A data frame containing request, table, alias status, cardinality, and
#'   whether the resolved name is in the canonical [table_catalog()].
#' @export
resolve_tables <- function(tables, source = data_source()) {
  if (!inherits(source, "data_source")) stop("`source` must be an data_source.")
  if (!is.character(tables) || !length(tables) || anyNA(tables) ||
      any(!nzchar(trimws(tables))))
    stop("`tables` must contain non-empty aliases or table names.")
  form <- .efile_source_form(source)
  catalog <- .efile_tables_for(form)
  request <- trimws(tables)
  upper <- toupper(request)
  alias <- upper %in% toupper(names(source$aliases))
  lookup <- stats::setNames(source$aliases, toupper(names(source$aliases)))
  resolved <- upper
  resolved[alias] <- unname(lookup[upper[alias]])

  # A 990PF alias such as "PF01" asked of a 990 source would otherwise pass
  # through as a literal table name and fail only at download time.
  pf_alias <- !alias & upper %in% names(.EFILE_ALIASES_PF)
  is_pf <- startsWith(resolved, "PF-") | pf_alias
  wrong <- if (form == "990PF") !is_pf & !resolved %in% catalog else is_pf
  if (any(wrong)) {
    shown <- paste(unique(request[wrong]), collapse = ", ")
    if (form == "990PF")
      stop("Not published in the 990PF release: ", shown, ". A 990PF source ",
           "reads PF-* tables and the shared header, signature, and Schedule B ",
           "tables; see table_catalog(form = \"990PF\").", call. = FALSE)
    stop("990PF tables requested from a 990 source: ", shown, ". Use ",
         "panelize_pf() or data_source(form = \"990PF\").", call. = FALSE)
  }

  data.frame(
    request = request,
    table = resolved,
    is_alias = alias,
    cardinality = vapply(resolved, .efile_table_cardinality, character(1L)),
    known = resolved %in% catalog,
    stringsAsFactors = FALSE
  )
}

#' Catalog of canonical efile tables
#'
#' Returns the full reference set of NCCS efile tables in one form family's
#' release, each with its join cardinality and short alias where one is
#' defined: Form 990/990EZ core and Schedules A-R for `"990"`, or the 990PF
#' parts and supporting statements (plus the shared header, signature, and
#' Schedule B tables) for `"990PF"`. Cardinality is derived from the table's
#' T-number: `1x1` (one row per filing, T00), `1xm` (repeating rows, T01-T98),
#' or `supplemental` (free-text, T99). In the 990PF release the `PF-P99-Txx`
#' supporting-statement tables are numbered by statement, so `T00` is `1x1` and
#' the rest are `1xm`.
#'
#' @param cardinality Filter to `"all"` (default), `"1x1"`, `"1xm"`, or
#'   `"supplemental"`.
#' @param form Form family: `"990"` (default) or `"990PF"`.
#' @return A data frame with columns `table`, `alias` (NA when none), and
#'   `cardinality`, one row per canonical table.
#' @examples
#' table_catalog("1x1")
#' table_catalog(form = "990PF")
#' @export
table_catalog <- function(cardinality = c("all", "1x1", "1xm", "supplemental"),
                          form = "990") {
  cardinality <- match.arg(cardinality)
  form <- .efile_form(form)
  aliases <- .efile_aliases_for(form)
  tables <- .efile_tables_for(form)
  alias_of <- stats::setNames(names(aliases), unname(aliases))
  out <- data.frame(
    table = tables,
    alias = unname(alias_of[tables]),
    cardinality = vapply(tables, .efile_table_cardinality, character(1L)),
    stringsAsFactors = FALSE, row.names = NULL
  )
  if (cardinality != "all") out <- out[out$cardinality == cardinality, , drop = FALSE]
  rownames(out) <- NULL
  out
}
