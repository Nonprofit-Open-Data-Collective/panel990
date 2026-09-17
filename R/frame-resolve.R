# =============================================================================
#  frame-resolve.R
#  Execution of `require` rules: cross-year conditions on the SOURCE.
#
#  Every other row rule is a predicate on rows already in hand, so apply_sfw()
#  can evaluate it against a data frame. A `require` rule is not: "filed in all
#  three years" is a fact about the source, and the rows that would answer it
#  are exactly the rows you are trying to avoid reading.
#
#  resolve_frame() therefore runs the condition against the source first,
#  reading only the entity key, the time key, and any column the predicate
#  names, then lowers the resulting id set into an ordinary `subset` rule. Two
#  properties follow:
#
#    * the frame stays declarative and source-agnostic -- apply_sfw() still
#      works on any data frame, because it only ever sees a `subset`;
#    * the resolved sample is reproducible and audited -- the id set is
#      captured by value and the resolution is logged as a receipt.
#
#  Resolution is cheap because it is narrow, not because it is approximate: on
#  a parquet release it reads two columns of the header table. Three years of
#  header is 1.4 MB of EIN2 + TAX_YEAR against 273 MB of CSV.
# =============================================================================

# Rule -> the SQL aggregate that expresses its presence requirement.
.frame_present_sql <- function(present_in, n_years, time_id) {
  if (identical(present_in, "any")) return(NULL)
  needed <- if (identical(present_in, "all")) n_years else
    min(as.integer(present_in), n_years)
  paste0("count(DISTINCT ", time_id, ") >= ", needed)
}

# Rule -> the SQL aggregate that expresses its per-filing predicate, folded
# over the years. `every` is bool_and, `any` is bool_or.
.frame_predicate_sql <- function(con, rule, available) {
  if (is.na(rule$column)) return(NULL)
  if (!rule$column %in% available)
    stop("`require` rule column not found in ", rule$table, ": ", rule$column)
  identifier <- as.character(DBI::dbQuoteIdentifier(con, rule$column))
  test <- switch(rule$op,
    "in"     = paste0(identifier, " IN (", .efile_sql_in(con, rule$values), ")"),
    "not_in" = paste0(identifier, " NOT IN (", .efile_sql_in(con, rule$values), ")"),
    "is_true"  = paste0("upper(trim(CAST(", identifier, " AS VARCHAR))) IN ",
                        "('X','TRUE','T','1','Y','YES')"),
    "is_false" = paste0("upper(trim(CAST(", identifier, " AS VARCHAR))) NOT IN ",
                        "('X','TRUE','T','1','Y','YES')"),
    "between" = paste0(identifier, " BETWEEN ",
                       DBI::dbQuoteString(con, as.character(rule$values[[1L]])),
                       " AND ",
                       DBI::dbQuoteString(con, as.character(rule$values[[2L]]))),
    paste0(identifier, " ", rule$op, " ",
           DBI::dbQuoteString(con, as.character(rule$values)))
  )
  paste0(if (identical(rule$holds, "every")) "bool_and(" else "bool_or(",
         test, ")")
}

# Entity ids satisfying one `require` rule.
.frame_resolve_one <- function(con, rule, years, source, entity, time) {
  resolved <- resolve_tables(rule$table, source)$table[[1L]]
  paths <- vapply(years, function(year)
    .efile_resource(source$root, .efile_filename(resolved, year, source$format)),
    character(1L))
  # A year the release does not carry is skipped rather than fatal: the
  # presence count is then taken over the years that exist.
  if (!any(grepl("^https?://", paths, ignore.case = TRUE)))
    paths <- paths[file.exists(paths)]
  if (!length(paths))
    stop("No ", resolved, " file available for ", paste(range(years), collapse = "-"),
         " under ", source$root, ".")

  list_sql <- paste0("[", paste(vapply(paths, function(p)
    as.character(DBI::dbQuoteString(con, p)), character(1L)), collapse = ", "), "]")
  reader <- if (identical(source$format, "parquet")) "read_parquet" else "read_csv_auto"
  # union_by_name tolerates the schema drift between release years.
  scan <- paste0(reader, "(", list_sql, ", union_by_name = true)")
  available <- names(DBI::dbGetQuery(con, paste0("SELECT * FROM ", scan, " LIMIT 0")))
  for (key in c(entity, time))
    if (!key %in% available)
      stop("`require` rule needs the ", key, " column in ", resolved, ".")

  entity_id <- as.character(DBI::dbQuoteIdentifier(con, entity))
  time_id <- as.character(DBI::dbQuoteIdentifier(con, time))
  having <- c(.frame_present_sql(rule$present_in, length(paths), time_id),
              .frame_predicate_sql(con, rule, available))
  sql <- paste0("SELECT ", entity_id, " FROM ", scan, " GROUP BY 1",
                if (length(having))
                  paste0(" HAVING ", paste(having, collapse = " AND ")) else "")
  list(ids = as.character(DBI::dbGetQuery(con, sql)[[1L]]),
       table = resolved, years = length(paths))
}

#' Resolve a sample frame's cross-year requirements against the source
#'
#' @description
#' Executes every active `require` rule on the frame and replaces them with a
#' single captured `subset` rule, so the resulting frame specifies one concrete
#' set of entity ids that [panelize()] can push down to read-time and
#' [apply_sfw()] can execute against any data frame.
#'
#' A `require` rule is the one rule type that cannot be evaluated against a
#' data frame, because it asserts something across table-years -- "filed in all
#' three years", "was a 990EZ filer every year". See [add_rule()] for the
#' payload.
#'
#' Resolution reads only the entity key, the time key, and any column a
#' predicate names, so it is far cheaper than building the panel and filtering
#' it: the condition is answered before the financial columns are ever touched.
#' On a `data_source(format = "parquet")` release this is two columns of one
#' table.
#'
#' @details
#' Multiple `require` rules intersect: an entity must satisfy all of them. The
#' rules themselves are deactivated rather than dropped, so the frame still
#' records the condition that produced the sample; `get_rules()` shows both the
#' original requirement and the resolved subset, and [manifest()] logs the
#' resolution with the id count.
#'
#' @param sfw A sample frame carrying at least one `require` rule.
#' @param years Tax years the requirement is evaluated over. Years the release
#'   does not carry are skipped, and `present_in = "all"` then means all of the
#'   years that exist.
#' @param source An [data_source()] configuration.
#' @param name Name for the `subset` rule that receives the resolved ids.
#' @param verbose Print a line per resolved rule.
#' @return The updated sample frame: `require` rules deactivated, one `subset`
#'   rule added, and a receipt appended to the provenance log.
#' @seealso [add_rule()], [panelize()], [manifest()]
#' @examples
#' frame <- create_sfw("balanced 990EZ filers")
#' frame <- add_rule(frame, type = "require", table = "P00",
#'                   present_in = "all", column = "RETURN_TYPE",
#'                   op = "in", values = "990EZ", holds = "every")
#' get_rules(frame)
#' \dontrun{
#' # Reads EIN2, TAX_YEAR, and RETURN_TYPE only.
#' frame <- resolve_frame(frame, years = 2019:2021,
#'                        source = data_source(format = "parquet"))
#' get_rules(frame)
#' }
#' @export
resolve_frame <- function(sfw, years, source = data_source(),
                          name = "resolved", verbose = TRUE) {
  .sfw_check(sfw)
  if (!inherits(source, "data_source")) stop("`source` must be an data_source.")
  if (!is.numeric(years) || !length(years) || anyNA(years))
    stop("`years` must be a non-empty numeric vector.")
  years <- sort(unique(as.integer(years)))
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("duckdb", quietly = TRUE))
    stop("Resolving a `require` rule needs the suggested packages `DBI` and ",
         "`duckdb`.")

  rules <- Filter(function(r) identical(r$type, "require") && isTRUE(r$active),
                  sfw$rules)
  if (!length(rules)) {
    if (isTRUE(verbose))
      .p990_say("resolve_frame: no active `require` rules; frame unchanged.")
    return(sfw)
  }
  entity <- .sfw_key(sfw, "entity")
  time <- .sfw_key(sfw, "time")
  if (is.na(entity) || is.na(time))
    stop("A `require` rule needs both an entity and a time key; see add_key().")

  con <- .p990_parquet_con()
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  if (grepl("^https?://", source$root, ignore.case = TRUE)) {
    DBI::dbExecute(con, "INSTALL httpfs")
    DBI::dbExecute(con, "LOAD httpfs")
  }

  ids <- NULL
  for (rule in rules) {
    started <- Sys.time()
    out <- .frame_resolve_one(con, rule, years, source, entity, time)
    if (isTRUE(verbose))
      .p990_say("<- REQUIRE  ", rule$name, " [", out$table, " x ", out$years,
                " year(s)]: ", format(length(out$ids), big.mark = ","),
                " ", entity, " in ",
                round(as.numeric(difftime(Sys.time(), started, units = "secs")), 2L),
                "s")
    # Several requirements intersect: an entity must satisfy all of them.
    ids <- if (is.null(ids)) out$ids else intersect(ids, out$ids)
    sfw <- .panel_receipt(sfw, paste0("require: ", rule$name),
                          .sfw_rule_detail(rule), c(NA, NA),
                          c(length(out$ids), NA))
  }

  # Deactivate rather than drop, so the frame still records what was asked for
  # alongside the ids that answered it.
  for (i in seq_along(sfw$rules))
    if (identical(sfw$rules[[i]]$type, "require"))
      sfw$rules[[i]]$active <- FALSE
  sfw <- add_rule(sfw, name = name, type = "subset", ids = ids)
  if (length(rules) > 1L)
    sfw <- .panel_receipt(sfw, "resolve_frame",
                          paste0(length(rules), " requirement(s) intersected"),
                          c(NA, NA), c(length(ids), NA))
  if (isTRUE(verbose))
    .p990_say("resolve_frame: ", format(length(ids), big.mark = ","), " ",
              entity, " satisfy ", length(rules), " requirement(s).")
  sfw
}

# Does the frame carry an unresolved requirement? Drives panelize()'s automatic
# resolution.
.sfw_has_require <- function(sfw)
  any(vapply(sfw$rules, function(r)
    identical(r$type, "require") && isTRUE(r$active), logical(1L)))
