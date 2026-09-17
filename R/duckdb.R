.efile_virtual_download <- function(years, tables, source) {
  resolved <- resolve_tables(tables, source)
  manifest <- do.call(rbind, lapply(sort(unique(as.integer(years))), function(year) {
    do.call(rbind, lapply(seq_len(nrow(resolved)), function(i) {
      filename <- .efile_filename(resolved$table[[i]], year, source$format)
      resource <- .efile_resource(source$root, filename)
      data.frame(
        year = year, request = resolved$request[[i]], table = resolved$table[[i]],
        cardinality = resolved$cardinality[[i]], source = resource, path = resource,
        status = "virtual", attempts = 0L, bytes = NA_real_, elapsed_seconds = 0,
        error = NA_character_, stringsAsFactors = FALSE
      )
    }))
  }))
  structure(list(files = manifest$path, manifest = manifest, cache_path = NA_character_,
                 log_file = NA_character_), class = "download_result")
}

# Apply one DuckDB setting, ignoring builds that do not recognize it.
.efile_duckdb_set <- function(con, name, value) {
  tryCatch(
    DBI::dbExecute(con, paste0("SET ", name, " = ",
                               format(value, scientific = FALSE))),
    error = function(e) 0L
  )
  invisible(NULL)
}

.efile_sql_in <- function(con, values) {
  paste(vapply(as.character(values), function(x)
    as.character(DBI::dbQuoteString(con, x)), character(1L)), collapse = ", ")
}

# Value filters as SQL predicates, validated against the columns the scan
# actually exposes.
.efile_sql_where <- function(con, filters, available) {
  where <- character()
  for (field in names(filters)) {
    if (!field %in% available) stop("Filter field not found: ", field)
    where <- c(where, paste0(as.character(DBI::dbQuoteIdentifier(con, field)),
                             " IN (", .efile_sql_in(con, filters[[field]]), ")"))
  }
  where
}

# The scan expression for one table-year file. Parquet carries its own schema,
# so no type inference is configured here; read_csv_auto() guesses, which is
# why the two formats return different column types. See .p990_efile_types().
.efile_duckdb_scan <- function(con, path) {
  quoted <- as.character(DBI::dbQuoteString(con, path))
  if (identical(.efile_format_of(path), "parquet"))
    paste0("read_parquet(", quoted, ")")
  else paste0("read_csv_auto(", quoted, ", header = true)")
}

#' Read efile tables through DuckDB
#'
#' Internal backend used by [panelize()]. Filters and projection are pushed
#' into DuckDB before results are collected into R. The scan expression follows
#' the file extension, so a CSV and a parquet cache read through the same code
#' path; see `.efile_duckdb_scan()`.
#'
#' Under `cache = "none"` the scan reads straight from S3 through the httpfs
#' extension, which has its own HTTP settings and never sees R's `timeout`
#' option. `timeout` and `retry_max` are forwarded to httpfs so the virtual
#' scan honours the same limits as a cached download. This is where parquet
#' earns its keep: projection and an `EIN2` restriction become column-chunk and
#' row-group range requests instead of a whole-file transfer.
#'
#' @section Deduplication and projection:
#' `unique_rows = TRUE` compiles to `SELECT DISTINCT *`, which needs every
#' column and therefore prevents the projection from being pushed into the
#' scan. On a parquet source that is the difference between reading the columns
#' you asked for and reading all of them. The efile build emits no exact
#' duplicate rows, so `unique_rows = FALSE` is the faster and equivalent
#' choice on a current release.
#'
#' @param downloads A `download_result`.
#' @param columns Optional fields to retain.
#' @param filters Named list of accepted values.
#' @param unique_rows Remove exact duplicate rows.
#' @param timeout HTTP timeout in seconds applied to remote scans.
#' @param retry_max HTTP retries applied to remote scans.
#' @keywords internal
read_tables_duckdb <- function(downloads, columns = NULL, filters = NULL,
                               unique_rows = TRUE, timeout = 1800,
                               retry_max = 3L) {
  if (!requireNamespace("DBI", quietly = TRUE) ||
      !requireNamespace("duckdb", quietly = TRUE))
    stop("The DuckDB backend requires the suggested packages `DBI` and `duckdb`.")
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
  if (any(grepl("^https?://", downloads$manifest$path, ignore.case = TRUE))) {
    DBI::dbExecute(con, "INSTALL httpfs")
    DBI::dbExecute(con, "LOAD httpfs")
    # httpfs defaults to a 30 second timeout, which no multi-hundred-MB scan
    # survives. The settings are named differently across DuckDB versions, so
    # a build that rejects one is left on its own default.
    .efile_duckdb_set(con, "http_timeout", .p990_timeout(timeout))
    .efile_duckdb_set(con, "http_retries", max(0L, as.integer(retry_max) - 1L))
  }
  manifest <- downloads$manifest
  for (field in c("rows_source", "cols_source", "rows_selected", "cols_selected",
                  "exact_duplicates_removed")) manifest[[field]] <- NA_integer_
  tables <- list()
  success <- which(manifest$status %in% .EFILE_READABLE)
  for (i in success) {
    scan <- .efile_duckdb_scan(con, manifest$path[[i]])
    metadata <- DBI::dbGetQuery(con, paste0("SELECT * FROM ", scan, " LIMIT 0"))
    source_cols <- names(metadata)
    source_rows <- DBI::dbGetQuery(con, paste0("SELECT count(*) AS n FROM ", scan))$n[[1]]
    from <- if (unique_rows) paste0("(SELECT DISTINCT * FROM ", scan, ") AS src") else
      paste0(scan, " AS src")
    selected <- if (is.null(columns)) source_cols else intersect(columns, source_cols)
    select_sql <- if (length(selected)) paste(vapply(selected, function(x)
      as.character(DBI::dbQuoteIdentifier(con, x)), character(1L)), collapse = ", ") else "*"
    where <- .efile_sql_where(con, filters, source_cols)
    sql <- paste0("SELECT ", select_sql, " FROM ", from,
                  if (length(where)) paste0(" WHERE ", paste(where, collapse = " AND ")) else "")
    table <- DBI::dbGetQuery(con, sql)
    # Parquet holds every efile column as a string; CSV arrives already typed
    # by read_csv_auto()'s inference.
    if (identical(.efile_format_of(manifest$path[[i]]), "parquet"))
      table <- .p990_coerce(table, label = paste0(manifest$table[[i]], " ",
                                                  manifest$year[[i]]))
    if (!"TAX_YEAR" %in% names(table)) table$TAX_YEAR <- manifest$year[[i]]
    name <- paste(manifest$table[[i]], manifest$year[[i]], sep = "::")
    tables[[name]] <- table
    manifest$rows_source[[i]] <- source_rows
    manifest$cols_source[[i]] <- length(source_cols)
    manifest$rows_selected[[i]] <- nrow(table)
    manifest$cols_selected[[i]] <- ncol(table)
    manifest$exact_duplicates_removed[[i]] <- if (unique_rows)
      source_rows - DBI::dbGetQuery(con, paste0("SELECT count(*) AS n FROM ", from))$n[[1]] else 0L
  }
  structure(list(tables = tables, manifest = manifest, download = downloads),
            class = "read_result")
}
