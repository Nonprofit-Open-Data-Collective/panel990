# Source format plumbing shared by the download, memory, and DuckDB read paths.
#
# The published efile release carries each table-year as both a CSV and a
# parquet file under the same stem, so the format is an extension swap on an
# otherwise identical URL. Parquet is worth the switch only for selective
# reads: the files are sorted by EIN2 with non-overlapping row-group
# statistics, so an entity restriction prunes row groups instead of scanning,
# and a column projection reads only the chunks it needs. Reading a whole
# table is no faster than fread().
#
# Parquet stores every efile column as a string, so the read paths must supply
# the types that CSV type inference would otherwise guess at. See
# .p990_efile_types() for the type authority and .p990_coerce() for the cast.

.EFILE_FORMATS <- c("csv", "parquet")

# Every table-year in the release is published as parquet as well as CSV, and
# parquet is an eighth of the bytes, so it is the default. Every caller that
# does not name a format follows.
.EFILE_FORMAT <- "parquet"

#' Default source format for this session
#'
#' `.EFILE_FORMAT`, unless it is parquet and no parquet reader is installed:
#' `duckdb` and `arrow` are only suggested, and a parquet default that fails at
#' read time would break every call that did not ask for a format. That case
#' falls back to CSV and says so once per session.
#'
#' @return `"csv"` or `"parquet"`.
#' @keywords internal
.efile_default_format <- function() {
  if (.EFILE_FORMAT != "parquet" || !is.na(.p990_parquet_engine()))
    return(.EFILE_FORMAT)
  if (!isTRUE(getOption("panel990.format_fallback_said"))) {
    options(panel990.format_fallback_said = TRUE)
    .p990_say("No parquet reader found (install `duckdb` or `arrow`); ",
              "reading the CSV release instead.")
  }
  "csv"
}

.efile_extension <- function(format) {
  switch(format, parquet = ".parquet", csv = ".CSV",
         stop("Unsupported format: ", format))
}

#' Normalize a source-format string
#'
#' @param format User-supplied format.
#' @return `"csv"` or `"parquet"`.
#' @keywords internal
.efile_format <- function(format) {
  if (!is.character(format) || length(format) != 1L || is.na(format) ||
      !nzchar(format))
    stop("`format` must be one of: ", paste(.EFILE_FORMATS, collapse = ", "))
  format <- tolower(trimws(format))
  if (format == "pq") format <- "parquet"
  if (!format %in% .EFILE_FORMATS)
    stop("`format` must be one of: ", paste(.EFILE_FORMATS, collapse = ", "),
         "; received \"", format, "\".")
  format
}

.efile_filename <- function(table, year, format = .EFILE_FORMAT) {
  paste0(table, "-", year, .efile_extension(format))
}

# Format of a file already on disk or in a manifest. Detected from the path
# rather than carried alongside it, so a cache holding both formats, or a
# hand-assembled manifest, still reads correctly.
.efile_format_of <- function(path) {
  if (grepl("\\.parquet$", path, ignore.case = TRUE)) "parquet" else "csv"
}

# ---- type authority ---------------------------------------------------------

# Structural filing columns are build artifacts rather than form variables, so
# none of them appear in field_concordance. Their types are fixed here.
#
# ORG_EIN is deliberately text: fread() infers integer and silently drops the
# leading zero from EINs such as 010078060.
.EFILE_KEY_TYPES <- c(
  EIN2                  = "text",
  OBJECTID              = "text",
  ORG_EIN               = "text",
  ORG_NAME_L1           = "text",
  ORG_NAME_L2           = "text",
  RETURN_AMENDED_X      = "checkbox",
  RETURN_GROUP_X        = "checkbox",
  RETURN_PARTIAL_X      = "checkbox",
  RETURN_TAXPER_DAYS    = "integer",
  RETURN_TIME_STAMP     = "text",
  RETURN_TYPE           = "text",
  TAX_PERIOD_BEGIN_DATE = "date",
  TAX_PERIOD_END_DATE   = "date",
  TAX_YEAR              = "integer",
  URL                   = "text",
  VERSION               = "text"
)

#' Declared efile type of each field
#'
#' Parquet stores every efile column as a string, so a read needs an external
#' statement of which fields are numeric. This is that statement: the 16
#' structural filing columns from `.EFILE_KEY_TYPES`, and every form variable
#' from `field_concordance$data_type_simple`.
#'
#' Using the concordance makes the parquet types *declared* rather than
#' inferred, which is the one respect in which the parquet path is better than
#' the CSV path: `read_csv_auto()` and `fread()` guess from the first rows and
#' disagree with each other on real tables.
#'
#' @param fields Optional character vector to restrict the result to.
#' @return A named character vector of `variable_name` -> efile type, one of
#'   `"numeric"`, `"integer"`, `"checkbox"`, `"text"`, or `"date"`.
#' @keywords internal
.p990_efile_types <- function(fields = NULL) {
  fc <- .field_concordance()
  types <- c(.EFILE_KEY_TYPES,
             stats::setNames(fc$data_type_simple, fc$variable_name))
  # Structural keys win: a form variable sharing a key's name would otherwise
  # override the fixed type above.
  types <- types[!duplicated(names(types))]
  if (!is.null(fields)) types <- types[intersect(fields, names(types))]
  types
}

# Only numeric and integer actually convert. Checkboxes stay character so
# normalize()'s form-aware vocabulary handling still sees the raw source value;
# dates and timestamps stay as ISO strings, which is what parquet holds.
.P990_COERCE <- c(numeric = "numeric", integer = "integer")

#' Cast character columns to their declared efile types
#'
#' Applied to parquet reads, where every column arrives as a string. Fields
#' with no declared type -- user-supplied columns, tables newer than the
#' concordance -- are left exactly as read.
#'
#' A value that is neither blank nor parseable is a signal that the upstream
#' build wrote something unexpected into a numeric column, so it warns rather
#' than failing quietly, in the same spirit as [normalize()].
#'
#' @param df A data frame of character columns.
#' @param types Named type vector, defaulting to [.p990_efile_types()].
#' @param label Table name used in warning messages.
#' @return `df` with numeric fields cast.
#' @keywords internal
.p990_coerce <- function(df, types = .p990_efile_types(names(df)),
                         label = NULL) {
  cast <- types[types %in% names(.P990_COERCE)]
  unparseable <- list()
  for (field in intersect(names(cast), names(df))) {
    x <- df[[field]]
    if (!is.character(x)) next
    target <- .P990_COERCE[[cast[[field]]]]
    value <- suppressWarnings(
      if (target == "integer") as.integer(x) else as.numeric(x))
    # A blank is a legitimate absent value; normalize() decides whether it
    # means zero. Anything else that fails to parse is a build problem.
    bad <- is.na(value) & !is.na(x) & nzchar(trimws(x))
    if (any(bad)) unparseable[[field]] <- unique(trimws(x[bad]))
    df[[field]] <- value
  }
  if (length(unparseable)) {
    shown <- vapply(names(unparseable), function(f) {
      v <- unparseable[[f]]
      paste0(f, " (", paste(utils::head(v, 3L), collapse = ", "),
             if (length(v) > 3L) paste0(", +", length(v) - 3L, " more") else "",
             ")")
    }, character(1L))
    warning(sprintf(
      paste0("Non-numeric value(s) in %d declared-numeric field(s)%s; set to ",
             "NA: %s. This may indicate an upstream build problem."),
      length(unparseable),
      if (is.null(label)) "" else paste0(" of ", label),
      paste(utils::head(shown, 5L), collapse = "; ")), call. = FALSE)
  }
  df
}

# ---- parquet reading --------------------------------------------------------

# Prefer DuckDB (already a Suggests dependency and able to project columns and
# push filters into the scan); fall back to arrow; NA when neither is present.
.p990_parquet_engine <- function() {
  if (requireNamespace("DBI", quietly = TRUE) &&
      requireNamespace("duckdb", quietly = TRUE)) return("duckdb")
  if (requireNamespace("arrow", quietly = TRUE)) return("arrow")
  NA_character_
}

#' Open a DuckDB connection without duckdb's startup notice
#'
#' Used by every DuckDB read, parquet or CSV. A read loop should open one connection and pass it down rather than let each
#' file create its own: starting an instance per table-year repeats the setup
#' cost and prints duckdb's extension-directory notice once per file.
#'
#' @return A DBI connection. The caller is responsible for disconnecting.
#' @keywords internal
.p990_parquet_con <- function() {
  suppressMessages(DBI::dbConnect(duckdb::duckdb()))
}

# Run `expr` against `con` when one was supplied, otherwise against a
# connection opened and closed around the call.
.p990_with_con <- function(con, expr) {
  if (!is.null(con)) return(expr(con))
  own <- .p990_parquet_con()
  on.exit(DBI::dbDisconnect(own, shutdown = TRUE), add = TRUE)
  expr(own)
}

#' Source dimensions of a parquet file without reading it
#'
#' Row count and column count come from the file footer and schema, so they are
#' free. This lets a read push its projection into the scan and still report
#' the true source width in the manifest.
#'
#' @param path Local path or URL.
#' @param engine `"duckdb"` or `"arrow"`.
#' @param con Optional open DuckDB connection to reuse.
#' @return A list with `rows` and `cols`.
#' @keywords internal
.p990_parquet_dims <- function(path, engine = .p990_parquet_engine(),
                               con = NULL) {
  if (is.na(engine))
    stop("Reading parquet requires the suggested package `duckdb` or `arrow`.")
  if (engine == "duckdb") {
    return(.p990_with_con(con, function(con) {
      quoted <- as.character(DBI::dbQuoteString(con, path))
      rows <- DBI::dbGetQuery(con, paste0(
        "SELECT num_rows AS n FROM parquet_file_metadata(", quoted, ")"))$n[[1]]
      cols <- DBI::dbGetQuery(con, paste0(
        "SELECT count(*) AS n FROM parquet_schema(", quoted,
        ") WHERE num_children IS NULL OR num_children = 0"))$n[[1]]
      list(rows = as.integer(rows), cols = as.integer(cols))
    }))
  }
  info <- arrow::open_dataset(path, format = "parquet")
  list(rows = as.integer(info$num_rows), cols = length(info$schema$names))
}

#' Read a parquet file, projecting columns and pushing row filters down
#'
#' Column projection and an `IN` filter are applied during the scan, so a
#' selective read touches only the column chunks and row groups it needs. The
#' efile files are sorted by `EIN2`, which is what makes an entity restriction
#' prune row groups rather than scan them.
#'
#' @param path Local path or URL.
#' @param columns Fields to retain; `NULL` reads every column.
#' @param filters Named list of accepted values, such as `list(EIN2 = eins)`.
#' @param engine `"duckdb"` or `"arrow"`.
#' @param con Optional open DuckDB connection to reuse across a read loop.
#' @return A data frame of character columns, uncast. Callers apply
#'   [.p990_coerce()].
#' @keywords internal
.p990_read_parquet <- function(path, columns = NULL, filters = NULL,
                               engine = .p990_parquet_engine(), con = NULL) {
  if (is.na(engine))
    stop("Reading parquet requires the suggested package `duckdb` or `arrow`.")
  if (engine == "duckdb") {
    return(.p990_with_con(con, function(con) {
      if (grepl("^https?://", path, ignore.case = TRUE)) {
        DBI::dbExecute(con, "INSTALL httpfs")
        DBI::dbExecute(con, "LOAD httpfs")
      }
      scan <- .efile_duckdb_scan(con, path)
      available <- names(DBI::dbGetQuery(con,
        paste0("SELECT * FROM ", scan, " LIMIT 0")))
      keep <- if (is.null(columns)) available else intersect(columns, available)
      select_sql <- if (length(keep)) paste(vapply(keep, function(x)
        as.character(DBI::dbQuoteIdentifier(con, x)), character(1L)),
        collapse = ", ") else "*"
      where <- .efile_sql_where(con, filters, available)
      DBI::dbGetQuery(con, paste0("SELECT ", select_sql, " FROM ", scan,
        if (length(where)) paste0(" WHERE ", paste(where, collapse = " AND ")) else ""))
    }))
  }
  # Read as an Arrow table and subset by name: `col_select` would pull in
  # tidyselect, which is not a dependency here.
  table <- arrow::read_parquet(path, as_data_frame = FALSE)
  keep <- if (is.null(columns)) names(table) else intersect(columns, names(table))
  if (length(keep)) table <- table[, keep]
  out <- as.data.frame(table, stringsAsFactors = FALSE)
  for (field in intersect(names(filters), names(out)))
    out <- out[as.character(out[[field]]) %in% as.character(filters[[field]]), ,
               drop = FALSE]
  rownames(out) <- NULL
  out
}
