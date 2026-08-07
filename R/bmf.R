.EFILE_BMF_URL <- paste0(
  "https://nccsdata.s3.us-east-1.amazonaws.com/",
  "geocoding/bmf-master/merged/bmf_master_geocoded.csv"
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

#' Return the current NCCS geocoded BMF master URL
#' @return A length-one character vector.
#' @export
bmf_url <- function() .EFILE_BMF_URL

#' Return the default native BMF fields
#' @return A character vector of native snake_case BMF fields.
#' @export
bmf_vars <- function() .EFILE_BMF_VARS

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

#' Retrieve and prepare the NCCS BMF master
#'
#' @param source URL, local CSV path, or in-memory data frame.
#' @param vars Native BMF fields to retain.
#' @param eins Optional `EIN2` values used to filter before preparation.
#' @param strict Error when requested fields are unavailable.
#' @param verbose Print retrieval and preparation messages.
#' @return A prepared BMF data frame.
#' @export
bmf_retrieve <- function(
    source = .EFILE_BMF_URL,
    vars = .EFILE_BMF_VARS,
    eins = NULL,
    strict = FALSE,
    verbose = TRUE
) {
  if (is.data.frame(source)) {
    bmf <- source
    source_type <- "memory"
  } else {
    if (!is.character(source) || length(source) != 1L || is.na(source) ||
        !nzchar(source))
      stop("`source` must be a data frame, URL, or local CSV path.")
    is_url <- grepl("^https?://", source, ignore.case = TRUE)
    if (!is_url && !file.exists(source)) stop("BMF file not found: ", source)
    source_type <- if (is_url) "url" else "local_file"
    if (verbose) message("Reading BMF from ", source_type, ": ", source)
    bmf <- tryCatch(
      data.table::fread(source, showProgress = FALSE, data.table = FALSE),
      error = function(e) stop("Failed to read BMF source: ", conditionMessage(e),
                               call. = FALSE)
    )
  }

  if (!is.null(eins)) {
    if (!"EIN2" %in% names(bmf)) stop("BMF source does not contain `EIN2`.")
    target <- toupper(trimws(as.character(eins)))
    bmf <- bmf[toupper(trimws(as.character(bmf$EIN2))) %in% target, , drop = FALSE]
  }
  out <- bmf_prepare(bmf, vars = vars, strict = strict, verbose = verbose)
  diagnostics <- attr(out, "bmf_diagnostics")
  diagnostics$source_type <- source_type
  attr(out, "bmf_diagnostics") <- diagnostics
  out
}

#' Merge native BMF fields onto efile data
#'
#' @param data Efile data containing `EIN2`.
#' @param source URL, local CSV path, or BMF data frame.
#' @param vars Native BMF fields to retain.
#' @param strict Error when requested fields are unavailable.
#' @param verbose Print retrieval and join messages.
#' @return The input rows with native BMF fields appended and a
#'   `bmf_diagnostics` attribute.
#' @export
bmf_merge <- function(
    data,
    source = .EFILE_BMF_URL,
    vars = .EFILE_BMF_VARS,
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
    source, vars = vars, eins = panel_eins, strict = strict, verbose = verbose
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
