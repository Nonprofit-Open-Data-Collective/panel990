.EFILE_ROOT <- "https://nccs-efile.s3.us-east-1.amazonaws.com/public/efile_v2_1/"

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

#' Create an efile source configuration
#'
#' @param root Base URL or local directory containing table-year CSV files.
#' @param aliases Named character vector mapping short aliases to table names.
#' @return An `data_source` object.
#' @export
data_source <- function(root = .EFILE_ROOT, aliases = .EFILE_ALIASES) {
  if (!is.character(root) || length(root) != 1L || is.na(root) || !nzchar(root))
    stop("`root` must be one non-empty URL or directory path.")
  if (!is.character(aliases) || is.null(names(aliases)) || any(!nzchar(names(aliases))))
    stop("`aliases` must be a named character vector.")
  structure(list(root = root, aliases = aliases), class = "data_source")
}

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
#' @return A data frame containing request, table, alias status, and cardinality.
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
    stringsAsFactors = FALSE
  )
}

#' Return the built-in efile table aliases
#' @return A data frame with alias, canonical table, and cardinality.
#' @export
table_catalog <- function() {
  data.frame(
    alias = names(.EFILE_ALIASES),
    table = unname(.EFILE_ALIASES),
    cardinality = vapply(unname(.EFILE_ALIASES), .efile_table_cardinality,
                         character(1L)),
    stringsAsFactors = FALSE
  )
}
