.BMF_BUCKET <- "https://nccsdata.s3.us-east-1.amazonaws.com"
.BMF_LATEST <- paste0(.BMF_BUCKET, "/geocoding/unified-bmf/latest")

# The unified BMF is published as one parquet file (~640 MB) and one CSV
# (~3.6 GB) holding identical rows, plus per-state marts in both formats.
# Parquet is the default because it transfers a fifth of the bytes and permits
# column projection.
#
# The state marts are a SEPARATE, LAGGING build, not a partition of the
# unified file: as of the 2026_08 release they stack to 3,687,435 rows against
# the unified 3,698,124 (0.29% fewer) and their bmf_vintage_ym tops out one
# month earlier. They remain the fallback where no parquet reader exists and
# the right choice for single-state work, but callers are warned about the
# discrepancy rather than being told the two paths are equivalent.
.BMF_STATE_MART_ROWS <- 3687435L
.BMF_UNIFIED_ROWS <- 3698124L
.EFILE_BMF_URL <- paste0(.BMF_LATEST, "/bmf_unified_geocoded.parquet")
.EFILE_BMF_CSV_URL <- paste0(.BMF_LATEST, "/bmf_unified_geocoded.csv")
.EFILE_BMF_MANIFEST_URL <- paste0(.BMF_LATEST, "/_manifest.json")

.BMF_STATE_CSV <- paste0(.BMF_BUCKET,
                         "/unified/bmf/state_marts/csv/bmf_master_%s.csv")
.BMF_STATE_PARQUET <- paste0(.BMF_BUCKET,
                             "/unified/bmf/state_marts/parquet/state%%3D%s/part-0.parquet")

# All 63 published state marts: the 50 states, DC, territories, military and
# freely associated postal codes, and ZZ for unresolved addresses.
.BMF_STATES <- c(
  "AA", "AE", "AK", "AL", "AP", "AR", "AS", "AZ", "CA", "CO", "CT", "DC",
  "DE", "FL", "FM", "GA", "GU", "HI", "IA", "ID", "IL", "IN", "KS", "KY",
  "LA", "MA", "MD", "ME", "MH", "MI", "MN", "MO", "MP", "MS", "MT", "NC",
  "ND", "NE", "NH", "NJ", "NM", "NV", "NY", "OH", "OK", "OR", "PA", "PR",
  "PW", "RI", "SC", "SD", "TN", "TX", "UT", "VA", "VI", "VT", "WA", "WI",
  "WV", "WY", "ZZ"
)

.EFILE_BMF_VARS <- c(
  "EIN2", "org_name_display",
  "ntee_code_clean", "ntee_code_major_group",
  "nteev2", "nteev2_subsector", "nteev2_org_type",
  "subsection_code", "foundation_code", "foundation_code_definition",
  "ruling_date", "ruling_date_is_missing", "ruling_year",
  "filing_requirement_code", "filing_requirement_code_definition",
  "asset_amount", "income_amount", "revenue_amount",
  "org_addr_state", "org_addr_zip5",
  "geo_is_geocoded", "geo_lat", "geo_lon",
  "geo_state_abbr", "geo_county", "geo_metro_area",
  "geo_score", "geo_status", "bmf_source", "bmf_vintage_ym"
)

# bmf_prepare() needs these to resolve duplicates and derive ruling_year, so
# they are read even when `vars` omits them and dropped again at selection.
.BMF_PREPARE_HELPERS <- c(
  "EIN2", "bmf_source", "bmf_vintage_ym", "ruling_date",
  "ruling_date_is_missing"
)

#' Return the current NCCS unified BMF URL
#'
#' @param format `"parquet"` (default), `"csv"`, or `"manifest"`.
#' @return A length-one character vector.
#' @export
bmf_url <- function(format = c("parquet", "csv", "manifest")) {
  switch(match.arg(format),
         parquet = .EFILE_BMF_URL,
         csv = .EFILE_BMF_CSV_URL,
         manifest = .EFILE_BMF_MANIFEST_URL)
}

#' Return the default native BMF fields
#' @return A character vector of native snake_case BMF fields.
#' @export
bmf_vars <- function() .EFILE_BMF_VARS

#' Return the published BMF state mart codes
#'
#' @param format `"csv"` (default) or `"parquet"`.
#' @return A named character vector of state mart URLs, named by postal code.
#' @export
bmf_states <- function(format = c("csv", "parquet")) {
  template <- switch(match.arg(format),
                     csv = .BMF_STATE_CSV, parquet = .BMF_STATE_PARQUET)
  stats::setNames(sprintf(template, .BMF_STATES), .BMF_STATES)
}

#' Read the published BMF build manifest
#'
#' The NCCS build publishes `_manifest.json` beside the data with the vintage,
#' build time, and the byte count, row count, and SHA-256 of each file. The
#' byte counts are used to verify completed downloads.
#'
#' @param url Manifest URL.
#' @param timeout Download timeout in seconds.
#' @param retry_max Maximum attempts.
#' @param verbose Print progress messages.
#' @return A list parsed from the manifest, or `NULL` when it cannot be read
#'   (including when the suggested package `jsonlite` is absent).
#' @export
bmf_manifest <- function(url = .EFILE_BMF_MANIFEST_URL, timeout = 120,
                         retry_max = 2L, verbose = TRUE) {
  if (!requireNamespace("jsonlite", quietly = TRUE)) {
    if (verbose)
      message("Install the suggested package `jsonlite` to read the BMF ",
              "manifest; continuing without size verification.")
    return(NULL)
  }
  destination <- tempfile("bmf-manifest-", fileext = ".json")
  on.exit(unlink(destination), add = TRUE)
  outcome <- .p990_fetch(url, destination, timeout = timeout,
                         retry_max = retry_max, label = "BMF manifest",
                         verbose = verbose)
  if (!outcome$status %in% c("downloaded", "reused")) {
    if (verbose)
      message("Could not read the BMF manifest: ", outcome$error)
    return(NULL)
  }
  tryCatch(jsonlite::fromJSON(destination, simplifyVector = FALSE),
           error = function(e) {
             if (verbose) message("Could not parse the BMF manifest: ",
                                  conditionMessage(e))
             NULL
           })
}

.bmf_manifest_bytes <- function(manifest, file) {
  if (is.null(manifest) || is.null(manifest$files)) return(NA_real_)
  entry <- manifest$files[[file]]
  if (is.null(entry) || is.null(entry$bytes)) return(NA_real_)
  as.numeric(entry$bytes)
}

# Prefer DuckDB (already a Suggests dependency and able to project columns
# during the scan); fall back to arrow; NA when neither is installed.
.bmf_parquet_engine <- function() {
  if (requireNamespace("DBI", quietly = TRUE) &&
      requireNamespace("duckdb", quietly = TRUE)) return("duckdb")
  if (requireNamespace("arrow", quietly = TRUE)) return("arrow")
  NA_character_
}

.bmf_read_parquet <- function(path, columns = NULL, engine = .bmf_parquet_engine()) {
  if (is.na(engine))
    stop("Reading parquet requires the suggested package `duckdb` or `arrow`.")
  if (engine == "duckdb") {
    con <- DBI::dbConnect(duckdb::duckdb())
    on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)
    quoted <- as.character(DBI::dbQuoteString(con, path))
    scan <- paste0("read_parquet(", quoted, ")")
    available <- names(DBI::dbGetQuery(con, paste0("SELECT * FROM ", scan,
                                                   " LIMIT 0")))
    keep <- if (is.null(columns)) available else intersect(columns, available)
    select_sql <- if (length(keep))
      paste(vapply(keep, function(x)
        as.character(DBI::dbQuoteIdentifier(con, x)), character(1L)),
        collapse = ", ") else "*"
    return(DBI::dbGetQuery(con, paste0("SELECT ", select_sql, " FROM ", scan)))
  }
  # Read as an Arrow table and subset by name: `col_select` would pull in
  # tidyselect, which is not a dependency here.
  table <- arrow::read_parquet(path, as_data_frame = FALSE)
  keep <- if (is.null(columns)) names(table) else intersect(columns, names(table))
  if (length(keep)) table <- table[, keep]
  as.data.frame(table, stringsAsFactors = FALSE)
}

# Read only the requested columns from a BMF CSV (the unified file or a state
# mart). fread() errors on unknown `select` names, so inspect the header first.
.bmf_read_csv <- function(path, columns = NULL) {
  if (is.null(columns))
    return(data.table::fread(path, showProgress = FALSE, data.table = FALSE))
  header <- names(data.table::fread(path, nrows = 0L, showProgress = FALSE,
                                    data.table = FALSE))
  keep <- intersect(columns, header)
  if (!length(keep))
    stop("No requested BMF field is present in ", basename(path), ".")
  data.table::fread(path, select = keep, showProgress = FALSE,
                    data.table = FALSE)
}

.bmf_resolve_states <- function(states) {
  if (is.null(states)) return(.BMF_STATES)
  states <- toupper(trimws(as.character(states)))
  unknown <- setdiff(states, .BMF_STATES)
  if (length(unknown))
    stop("Unknown BMF state mart code(s): ", paste(unknown, collapse = ", "),
         ". See bmf_states().")
  unique(states)
}

#' Prepare current-schema BMF data
#'
#' Validates `EIN2`, resolves duplicate records using BMF vintage and source,
#' derives sentinel-aware `ruling_year`, and selects native fields.
#'
#' @param bmf A data frame containing current-schema BMF data.
#' @param vars Fields to retain. Use `NULL` for every available field.
#' @param strict Error when requested fields are unavailable.
#' @param verbose Print preparation messages.
#' @return A data frame with one row per `EIN2` and a `bmf_diagnostics`
#'   attribute.
#' @export
bmf_prepare <- function(
    bmf,
    vars = .EFILE_BMF_VARS,
    strict = FALSE,
    verbose = TRUE
) {
  if (!is.data.frame(bmf)) stop("`bmf` must be a data.frame.")
  if (!is.null(vars) && !is.character(vars))
    stop("`vars` must be NULL or a character vector.")
  if (!is.logical(strict) || length(strict) != 1L || is.na(strict))
    stop("`strict` must be TRUE or FALSE.")

  bmf <- as.data.frame(bmf, stringsAsFactors = FALSE)
  source_rows <- nrow(bmf)
  source_cols <- ncol(bmf)
  if (!"EIN2" %in% names(bmf))
    stop("Current BMF source must contain the `EIN2` merge field.")

  bmf$EIN2 <- toupper(trimws(as.character(bmf$EIN2)))
  blank <- is.na(bmf$EIN2) | !nzchar(bmf$EIN2)
  dropped_blank_keys <- sum(blank)
  bmf <- bmf[!blank, , drop = FALSE]

  invalid_key_count <- sum(
    !grepl("^EIN-[0-9]{2}-[0-9]{7}$", bmf$EIN2), na.rm = TRUE
  )
  if (invalid_key_count > 0L)
    warning(invalid_key_count, " BMF `EIN2` value(s) do not match ",
            "EIN-XX-XXXXXXX.", call. = FALSE)

  row_id <- seq_len(nrow(bmf))
  vintage <- if ("bmf_vintage_ym" %in% names(bmf))
    as.character(bmf$bmf_vintage_ym) else rep(NA_character_, nrow(bmf))
  current <- if ("bmf_source" %in% names(bmf))
    as.integer(tolower(as.character(bmf$bmf_source)) == "current") else
      rep(0L, nrow(bmf))
  duplicate_rows <- sum(duplicated(bmf$EIN2))
  # Use transformed sort keys because older R supports one `decreasing` flag.
  ord <- order(bmf$EIN2, -xtfrm(vintage), -current, row_id, na.last = TRUE)
  bmf <- bmf[ord, , drop = FALSE]
  bmf <- bmf[!duplicated(bmf$EIN2), , drop = FALSE]

  if ("ruling_date" %in% names(bmf)) {
    missing_ruling <- is.na(bmf$ruling_date) |
      as.character(bmf$ruling_date) %in% c("", "1900-01-01")
    if ("ruling_date_is_missing" %in% names(bmf)) {
      flag <- tolower(trimws(as.character(bmf$ruling_date_is_missing)))
      missing_ruling <- missing_ruling |
        flag %in% c("true", "t", "1", "yes")
    }
    bmf$ruling_year <- suppressWarnings(
      as.integer(substr(as.character(bmf$ruling_date), 1L, 4L))
    )
    bmf$ruling_year[missing_ruling] <- NA_integer_
  }

  requested <- if (is.null(vars)) names(bmf) else unique(c("EIN2", vars))
  missing_requested <- setdiff(requested, names(bmf))
  selected <- intersect(requested, names(bmf))
  if (length(missing_requested) > 0L) {
    msg <- paste0("Requested BMF field(s) unavailable: ",
                  paste(missing_requested, collapse = ", "))
    if (strict) stop(msg, call. = FALSE) else warning(msg, call. = FALSE)
  }
  bmf <- bmf[, selected, drop = FALSE]
  rownames(bmf) <- NULL

  diagnostics <- list(
    source_rows = source_rows,
    source_cols = source_cols,
    rows_prepared = nrow(bmf),
    distinct_eins = length(unique(bmf$EIN2)),
    dropped_blank_keys = dropped_blank_keys,
    invalid_key_count = invalid_key_count,
    duplicate_rows_resolved = duplicate_rows,
    requested_fields = requested,
    selected_fields = selected,
    missing_requested_fields = missing_requested
  )
  attr(bmf, "bmf_diagnostics") <- diagnostics

  if (verbose)
    message("BMF prepared: ", format(nrow(bmf), big.mark = ","),
            " unique EIN(s), ", ncol(bmf), " selected column(s).")
  bmf
}

#' Retrieve and prepare the NCCS unified BMF
#'
#' Retrieval strategy is chosen by `format`:
#'
#' * `"parquet"` downloads the single unified parquet file (~640 MB) and reads
#'   it with DuckDB or arrow, projecting only the requested columns.
#' * `"states"` downloads the per-state CSV marts (6-380 MB each) and stacks
#'   them. Stacking is a plain row bind, not a join, so it is cheap; this is
#'   the fallback when no parquet reader is installed, and the way to retrieve
#'   a subset of states. **The state marts are a separate, lagging build**, not
#'   a partition of the unified file: at the 2026_08 release they stack to
#'   3,687,435 rows against the unified 3,698,124, and their `bmf_vintage_ym`
#'   runs about a month behind. Retrieving all states this way emits a warning
#'   to that effect. Prefer parquet when the vintage matters.
#' * `"csv"` downloads the single unified CSV (~3.6 GB). Slowest, and only
#'   worth using when neither of the above is possible.
#' * `"auto"` (default) uses `"parquet"` when DuckDB or arrow is available and
#'   `"states"` otherwise, or whenever `states` is supplied.
#'
#' Every transfer is retried with exponential backoff and verified against the
#' published `_manifest.json` byte count where one exists. Each call writes a
#' per-run log under `<path>/logs`; see [retrieval_log()].
#'
#' @param source Optional override: a URL, local file path, or in-memory data
#'   frame. `NULL` (default) uses the published NCCS release.
#' @param vars Native BMF fields to retain.
#' @param eins Optional `EIN2` values used to filter before preparation.
#' @param states Optional postal codes limiting retrieval to those state marts.
#'   Supplying this implies `format = "states"`. See [bmf_states()].
#' @param format Retrieval strategy; see details.
#' @param cache `"retain"` to keep downloads under `path`, or `"temporary"`
#'   for a session temporary directory.
#' @param path Cache directory used when `cache = "retain"`.
#' @param overwrite Download again even when a cached file exists.
#' @param timeout Download timeout in seconds, per attempt.
#' @param retry_max Maximum attempts per file.
#' @param strict Error when requested fields are unavailable.
#' @param verbose Print retrieval and preparation messages.
#' @return A prepared BMF data frame with a `bmf_diagnostics` attribute.
#' @export
bmf_retrieve <- function(
    source = NULL,
    vars = .EFILE_BMF_VARS,
    eins = NULL,
    states = NULL,
    format = c("auto", "parquet", "states", "csv"),
    cache = c("retain", "temporary"),
    path = "PANEL990",
    overwrite = FALSE,
    timeout = 3600,
    retry_max = 3L,
    strict = FALSE,
    verbose = TRUE
) {
  format <- match.arg(format)
  cache <- match.arg(cache)

  if (is.data.frame(source)) {
    out <- bmf_prepare(.bmf_filter_eins(source, eins), vars = vars,
                       strict = strict, verbose = verbose)
    diagnostics <- attr(out, "bmf_diagnostics")
    diagnostics$source_type <- "memory"
    attr(out, "bmf_diagnostics") <- diagnostics
    return(out)
  }

  # Created lazily by .p990_fetch()/.p990_write_log() so that reading a local
  # file never leaves an empty cache directory behind.
  base_path <- if (cache == "temporary") tempfile("panel990-bmf-") else path
  run_id <- .p990_run_id()
  engine <- .bmf_parquet_engine()

  # Read the helper columns bmf_prepare() needs even when `vars` omits them.
  read_columns <- if (is.null(vars)) NULL else
    unique(c(.BMF_PREPARE_HELPERS, vars))

  # A user-supplied path or URL bypasses strategy selection entirely.
  if (!is.null(source)) {
    if (!is.character(source) || length(source) != 1L || is.na(source) ||
        !nzchar(source))
      stop("`source` must be NULL, a data frame, a URL, or a local file path.")
    return(.bmf_from_source(source, vars, read_columns, eins, engine,
                            base_path, run_id, overwrite, timeout, retry_max,
                            strict, verbose))
  }

  if (format == "auto") {
    if (!is.null(states)) {
      format <- "states"
    } else if (!is.na(engine)) {
      format <- "parquet"
    } else {
      format <- "states"
      if (verbose)
        .p990_say("No parquet reader found (install `duckdb` or `arrow` for ",
                  "the single-file download). Falling back to state CSV marts.")
    }
  }
  if (format == "parquet" && is.na(engine))
    stop("`format = \"parquet\"` requires the suggested package `duckdb` or ",
         "`arrow`. Use `format = \"states\"` instead.")

  manifest_json <- if (format %in% c("parquet", "csv"))
    bmf_manifest(timeout = min(timeout, 300), retry_max = retry_max,
                 verbose = verbose) else NULL
  if (verbose && !is.null(manifest_json$vintage))
    .p990_say("BMF vintage ", manifest_json$vintage, " built ",
              .p990_or(manifest_json$built_at, "unknown"), ".")

  log_rows <- list()
  if (format %in% c("parquet", "csv")) {
    file_name <- basename(if (format == "parquet") .EFILE_BMF_URL else
      .EFILE_BMF_CSV_URL)
    url <- if (format == "parquet") .EFILE_BMF_URL else .EFILE_BMF_CSV_URL
    destination <- file.path(base_path, "bmf", file_name)
    outcome <- .p990_fetch(
      url, destination, timeout = timeout, retry_max = retry_max,
      expected_bytes = .bmf_manifest_bytes(manifest_json, file_name),
      label = paste0("BMF unified ", format), overwrite = overwrite,
      verbose = verbose
    )
    log_rows[[1L]] <- .bmf_log_row(run_id, format, NA_character_, url,
                                   destination, outcome)
    if (!outcome$status %in% c("downloaded", "reused")) {
      .p990_write_log(do.call(rbind, log_rows), base_path, run_id, "bmf")
      stop("Failed to retrieve the unified BMF ", format, ": ", outcome$error,
           call. = FALSE)
    }
    if (verbose) .p990_say("Reading ", file_name, " ...")
    bmf <- if (format == "parquet")
      .bmf_read_parquet(destination, read_columns, engine) else
        .bmf_read_csv(destination, read_columns)
    source_type <- paste0("unified_", format)
    retrieved_states <- NA_character_
  } else {
    wanted <- .bmf_resolve_states(states)
    urls <- bmf_states("csv")[wanted]
    if (verbose)
      .p990_say("Retrieving ", length(wanted), " state CSV mart(s) for ",
                "stacking: ", paste(wanted, collapse = ", "))
    parts <- vector("list", length(wanted))
    failures <- character()
    for (i in seq_along(wanted)) {
      code <- wanted[[i]]
      destination <- file.path(base_path, "bmf", "states",
                               paste0("bmf_master_", code, ".csv"))
      outcome <- .p990_fetch(
        urls[[i]], destination, timeout = timeout, retry_max = retry_max,
        label = paste0("[", i, "/", length(wanted), "] BMF state ", code),
        overwrite = overwrite, verbose = verbose
      )
      log_rows[[i]] <- .bmf_log_row(run_id, "states", code, urls[[i]],
                                    destination, outcome)
      if (!outcome$status %in% c("downloaded", "reused")) {
        failures <- c(failures, code)
        next
      }
      parts[[i]] <- .bmf_read_csv(destination, read_columns)
    }
    parts <- parts[!vapply(parts, is.null, logical(1L))]
    if (!length(parts)) {
      .p990_write_log(do.call(rbind, log_rows), base_path, run_id, "bmf")
      stop("No BMF state mart could be retrieved.", call. = FALSE)
    }
    if (length(failures))
      warning("BMF state mart(s) unavailable and omitted from the stack: ",
              paste(failures, collapse = ", "), call. = FALSE)
    if (verbose) .p990_say("Stacking ", length(parts), " state mart(s) ...")
    bmf <- .bmf_stack(parts)
    source_type <- "state_marts_csv"
    retrieved_states <- paste(setdiff(wanted, failures), collapse = ",")
    # The marts trail the unified build, so a caller who asked for the whole
    # country this way is told what they actually received.
    if (!length(failures) && length(wanted) == length(.BMF_STATES))
      warning("The state marts are a separate, lagging build: they stack to ",
              "roughly ", format(.BMF_STATE_MART_ROWS, big.mark = ","),
              " rows against the unified file's ",
              format(.BMF_UNIFIED_ROWS, big.mark = ","),
              ", with an older bmf_vintage_ym. Use format = \"parquet\" for ",
              "the current build.", call. = FALSE)
  }

  log_file <- .p990_write_log(do.call(rbind, log_rows), base_path, run_id, "bmf")
  if (verbose) .p990_say("BMF retrieval log: ", log_file)

  # The state marts ship no manifest, so record the newest vintage present in
  # the data itself; read it before bmf_prepare() selects the column away.
  observed_vintage <- NA_character_
  if ("bmf_vintage_ym" %in% names(bmf)) {
    seen <- as.character(bmf$bmf_vintage_ym)
    seen <- seen[!is.na(seen) & nzchar(seen)]
    if (length(seen)) observed_vintage <- max(seen)
  }

  # Filtering and preparing several million rows takes a while; say so rather
  # than going quiet after the transfer finishes.
  if (verbose)
    .p990_say("-> PREPARE  ", format(nrow(bmf), big.mark = ","),
              " BMF row(s): resolving duplicates by vintage ...")
  bmf <- .bmf_filter_eins(bmf, eins)
  out <- bmf_prepare(bmf, vars = vars, strict = strict, verbose = verbose)
  diagnostics <- attr(out, "bmf_diagnostics")
  diagnostics$source_type <- source_type
  diagnostics$format <- format
  diagnostics$run_id <- run_id
  diagnostics$log_file <- log_file
  diagnostics$states <- retrieved_states
  diagnostics$bmf_vintage <- .p990_or(manifest_json$vintage, observed_vintage)
  diagnostics$parquet_engine <- engine
  attr(out, "bmf_diagnostics") <- diagnostics
  out
}

# Row-bind state marts. The marts carry a materialized `state` partition
# column that the unified file does not, so it is dropped to keep the two
# retrieval paths schema-identical; the value survives in geo_state_abbr.
.bmf_stack <- function(parts) {
  out <- data.table::rbindlist(parts, use.names = TRUE, fill = TRUE)
  out <- as.data.frame(out, stringsAsFactors = FALSE)
  out[["state"]] <- NULL
  out
}

.bmf_filter_eins <- function(bmf, eins) {
  if (is.null(eins)) return(bmf)
  if (!"EIN2" %in% names(bmf)) stop("BMF source does not contain `EIN2`.")
  target <- toupper(trimws(as.character(eins)))
  bmf[toupper(trimws(as.character(bmf$EIN2))) %in% target, , drop = FALSE]
}

.bmf_log_row <- function(run_id, format, state, url, destination, outcome) {
  data.frame(
    format = format, state = state, source = url,
    path = normalizePath(destination, winslash = "/", mustWork = FALSE),
    status = outcome$status, attempts = outcome$attempts,
    bytes = outcome$bytes, elapsed_seconds = round(outcome$seconds, 2L),
    error = outcome$error, stringsAsFactors = FALSE
  )
}

.bmf_from_source <- function(source, vars, read_columns, eins, engine,
                             base_path, run_id, overwrite, timeout, retry_max,
                             strict, verbose) {
  is_url <- grepl("^https?://", source, ignore.case = TRUE)
  if (!is_url && !file.exists(source)) stop("BMF file not found: ", source)
  is_parquet <- grepl("\\.parquet$", source, ignore.case = TRUE)
  local_path <- source
  outcome <- NULL
  if (is_url) {
    local_path <- file.path(base_path, "bmf", basename(sub("\\?.*$", "", source)))
    outcome <- .p990_fetch(source, local_path, timeout = timeout,
                           retry_max = retry_max, label = "BMF source",
                           overwrite = overwrite, verbose = verbose)
    if (!outcome$status %in% c("downloaded", "reused"))
      stop("Failed to retrieve the BMF source: ", outcome$error, call. = FALSE)
  }
  if (verbose) .p990_say("Reading BMF from ", basename(local_path), " ...")
  bmf <- if (is_parquet) .bmf_read_parquet(local_path, read_columns, engine) else
    .bmf_read_csv(local_path, read_columns)
  log_file <- NA_character_
  if (!is.null(outcome))
    log_file <- .p990_write_log(
      .bmf_log_row(run_id, if (is_parquet) "parquet" else "csv", NA_character_,
                   source, local_path, outcome),
      base_path, run_id, "bmf")
  bmf <- .bmf_filter_eins(bmf, eins)
  out <- bmf_prepare(bmf, vars = vars, strict = strict, verbose = verbose)
  diagnostics <- attr(out, "bmf_diagnostics")
  diagnostics$source_type <- if (is_url) "url" else "local_file"
  diagnostics$run_id <- run_id
  diagnostics$log_file <- log_file
  attr(out, "bmf_diagnostics") <- diagnostics
  out
}

#' Merge native BMF fields onto efile data
#'
#' @param data Efile data containing `EIN2`.
#' @param source Optional BMF override: URL, local path, or data frame.
#' @param vars Native BMF fields to retain.
#' @param states Optional state marts to restrict retrieval to.
#' @param format Retrieval strategy; see [bmf_retrieve()].
#' @param cache `"retain"` or `"temporary"`.
#' @param path Cache directory used when `cache = "retain"`.
#' @param overwrite Download again even when a cached file exists.
#' @param timeout Download timeout in seconds, per attempt.
#' @param retry_max Maximum attempts per file.
#' @param strict Error when requested fields are unavailable.
#' @param verbose Print retrieval and join messages.
#' @return The input rows with native BMF fields appended and a
#'   `bmf_diagnostics` attribute.
#' @export
bmf_merge <- function(
    data,
    source = NULL,
    vars = .EFILE_BMF_VARS,
    states = NULL,
    format = c("auto", "parquet", "states", "csv"),
    cache = c("retain", "temporary"),
    path = "PANEL990",
    overwrite = FALSE,
    timeout = 3600,
    retry_max = 3L,
    strict = FALSE,
    verbose = TRUE
) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  if (!"EIN2" %in% names(data)) stop("`data` must contain `EIN2`.")

  left <- data
  left$EIN2 <- toupper(trimws(as.character(left$EIN2)))
  left$.efile_input_order__ <- seq_len(nrow(left))
  panel_eins <- unique(left$EIN2[!is.na(left$EIN2) & nzchar(left$EIN2)])
  bmf <- bmf_retrieve(
    source = source, vars = vars, eins = panel_eins, states = states,
    format = match.arg(format), cache = match.arg(cache), path = path,
    overwrite = overwrite, timeout = timeout, retry_max = retry_max,
    strict = strict, verbose = verbose
  )
  diagnostics <- attr(bmf, "bmf_diagnostics")

  overlap <- setdiff(intersect(names(left), names(bmf)), "EIN2")
  if (length(overlap) > 0L) {
    warning("Replacing existing BMF field(s): ", paste(overlap, collapse = ", "),
            call. = FALSE)
    left[overlap] <- NULL
  }
  bmf$.efile_bmf_match__ <- TRUE
  result <- merge(left, bmf, by = "EIN2", all.x = TRUE, sort = FALSE)
  result <- result[order(result$.efile_input_order__), , drop = FALSE]
  if (nrow(result) != nrow(data))
    stop("BMF join changed row count; expected a many-to-one join.")

  matched_rows <- sum(!is.na(result$.efile_bmf_match__))
  matched_eins <- length(unique(result$EIN2[!is.na(result$.efile_bmf_match__)]))
  result$.efile_input_order__ <- NULL
  result$.efile_bmf_match__ <- NULL
  rownames(result) <- NULL
  diagnostics <- c(diagnostics, list(
    input_rows = nrow(data), output_rows = nrow(result),
    panel_distinct_eins = length(panel_eins), matched_rows = matched_rows,
    matched_distinct_eins = matched_eins,
    unmatched_distinct_eins = length(panel_eins) - matched_eins
  ))
  attr(result, "bmf_diagnostics") <- diagnostics
  if (verbose)
    message("BMF merge complete: ", matched_rows, " of ", nrow(data),
            " row(s) matched.")
  result
}
