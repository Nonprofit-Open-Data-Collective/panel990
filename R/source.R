# The published efile release is versioned in the S3 prefix. Keep the bucket
# and the version separate so callers can move between releases without
# rebuilding the URL by hand; `.EFILE_VERSION` is only the default.
.EFILE_BUCKET <- "https://nccs-efile.s3.us-east-1.amazonaws.com/public/"
.EFILE_VERSION <- "v2_2"

.efile_version_root <- function(version) {
  paste0(.EFILE_BUCKET, "efile_", version, "/")
}

.EFILE_ROOT <- .efile_version_root(.EFILE_VERSION)

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
  "SA-P02-T00-SUPPORT_SCHEDULE_170",
  "SA-P03-T00-SUPPORT_SCHEDULE_509",
  "SA-P04-T00-SUPPORT-ORGS",
  "SA-P05-T00-SUPPORT-ORGS",
  "SA-P06-T99-SUPPLEMENTAL-INFO",
  # Schedule B
  "SB-P01-T01-CONTRIBUTORS",
  # Schedule C
  "SC-P01-T00-LOBBY",
  "SC-P01-T01-POLITICAL-ORGS-INFO",
  "SC-P02-T00-LOBBY",
  "SC-P03-T00-LOBBY",
  "SC-P04-T99-SUPPLEMENTAL-INFO",
  # Schedule D
  "SD-P01-T00-ORGS-DONOR-ADVISED-FUNDS-OTH",
  "SD-P02-T00-CONSERV-EASEMENTS",
  "SD-P03-T00-ORGS-COLLECT-ART-HIST-TREASURE-OTH",
  "SD-P04-T00-ESCROW-CUSTODIAL-ARRANGEMENTS",
  "SD-P05-T00-ENDOWMENT",
  "SD-P06-T00-LAND-BLDG-EQUIP",
  "SD-P07-T00-INVESTMENTS-SECURITIES",
  "SD-P07-T01-INVESTMENTS-OTH-DERIVATIVES",
  "SD-P07-T01-INVESTMENTS-OTH-EQUITY",
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
  "SG-P02-T01-FUNDRAISING-EVENTS",
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
  "SH-P05-T99-SUPPLEMENTAL-INFO",
  "SH-P06-T99-SUPPLEMENTAL-INFO",
  "SH-P99-T00-FAP-COMMUNITY-BENEFIT-POLICY",
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
  "SO-T99-SUPPLEMENTAL-INFO",
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

#' Create an efile source configuration
#'
#' The NCCS efile release is versioned. Leave `root` as `NULL` to point at a
#' published release by `version`, or pass `root` explicitly to read from a
#' local directory or a mirror, in which case `version` is recorded as `NA`.
#'
#' @param root Base URL or local directory containing table-year CSV files.
#'   `NULL` (default) builds the URL for `version`.
#' @param version Published release, such as `"v2_2"` (the current default) or
#'   `"v2_1"`. Ignored when `root` is supplied.
#' @param aliases Named character vector mapping short aliases to table names.
#' @return An `data_source` object carrying `root`, `version`, and `aliases`.
#' @examples
#' data_source()                   # current release
#' data_source(version = "v2_1")   # pin the previous release
#' @export
data_source <- function(root = NULL, version = .EFILE_VERSION,
                        aliases = .EFILE_ALIASES) {
  if (is.null(root)) {
    if (!is.character(version) || length(version) != 1L || is.na(version) ||
        !nzchar(version))
      stop("`version` must be one non-empty string such as \"v2_2\".")
    version <- sub("^efile_", "", tolower(trimws(version)))
    if (!grepl("^v[0-9]+_[0-9]+$", version))
      stop("`version` must look like \"v2_2\"; received \"", version, "\".")
    root <- .efile_version_root(version)
  } else {
    if (!is.character(root) || length(root) != 1L || is.na(root) || !nzchar(root))
      stop("`root` must be one non-empty URL or directory path.")
    version <- NA_character_
  }
  if (!is.character(aliases) || is.null(names(aliases)) || any(!nzchar(names(aliases))))
    stop("`aliases` must be a named character vector.")
  structure(list(root = root, version = version, aliases = aliases),
            class = "data_source")
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
#' user-specified tables without a package update.
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
  request <- trimws(tables)
  upper <- toupper(request)
  alias <- upper %in% toupper(names(source$aliases))
  lookup <- stats::setNames(source$aliases, toupper(names(source$aliases)))
  resolved <- upper
  resolved[alias] <- unname(lookup[upper[alias]])
  data.frame(
    request = request,
    table = resolved,
    is_alias = alias,
    cardinality = vapply(resolved, .efile_table_cardinality, character(1L)),
    known = resolved %in% .EFILE_TABLES,
    stringsAsFactors = FALSE
  )
}

#' Catalog of canonical efile tables
#'
#' Returns the full reference set of NCCS efile tables (Form 990/990EZ core and
#' Schedules A-R), each with its join cardinality and short alias where one is
#' defined. Cardinality is derived from the table's T-number: `1x1` (one row per
#' filing, T00), `1xm` (repeating rows, T01-T98), or `supplemental` (free-text,
#' T99).
#'
#' @param cardinality Filter to `"all"` (default), `"1x1"`, `"1xm"`, or
#'   `"supplemental"`.
#' @return A data frame with columns `table`, `alias` (NA when none), and
#'   `cardinality`, one row per canonical table.
#' @export
table_catalog <- function(cardinality = c("all", "1x1", "1xm", "supplemental")) {
  cardinality <- match.arg(cardinality)
  alias_of <- stats::setNames(names(.EFILE_ALIASES), unname(.EFILE_ALIASES))
  out <- data.frame(
    table = .EFILE_TABLES,
    alias = unname(alias_of[.EFILE_TABLES]),
    cardinality = vapply(.EFILE_TABLES, .efile_table_cardinality, character(1L)),
    stringsAsFactors = FALSE, row.names = NULL
  )
  if (cardinality != "all") out <- out[out$cardinality == cardinality, , drop = FALSE]
  rownames(out) <- NULL
  out
}
