#' Read acquired efile CSV tables
#'
#' @param downloads Result from [download_tables()].
#' @param columns Optional fields to retain; join keys should be included.
#' @param filters Named list of accepted values, such as `list(EIN2 = eins)`.
#' @param unique_rows Remove exact duplicate rows.
#' @return An `read_result` with named tables and an augmented manifest.
#' @export
read_tables <- function(
    downloads,
    columns = NULL,
    filters = NULL,
    unique_rows = TRUE
) {
  if (!inherits(downloads, "download_result"))
    stop("`downloads` must be returned by download_tables().")
  if (!is.null(columns) && !is.character(columns))
    stop("`columns` must be NULL or a character vector.")
  if (!is.null(filters) && (!is.list(filters) || is.null(names(filters))))
    stop("`filters` must be a named list.")
  manifest <- downloads$manifest
  manifest$rows_source <- NA_integer_
  manifest$cols_source <- NA_integer_
  manifest$rows_selected <- NA_integer_
  manifest$cols_selected <- NA_integer_
  manifest$exact_duplicates_removed <- NA_integer_
  tables <- list()
  success_rows <- which(manifest$status %in% c("downloaded", "reused"))
  for (i in success_rows) {
    path <- manifest$path[[i]]
    table <- data.table::fread(path, showProgress = FALSE, data.table = FALSE)
    source_n <- nrow(table)
    source_p <- ncol(table)
    removed <- 0L
    if (unique_rows) {
      duplicate <- duplicated(table)
      removed <- sum(duplicate)
      table <- table[!duplicate, , drop = FALSE]
    }
    if (!is.null(filters)) for (field in names(filters)) {
      if (!field %in% names(table))
        stop("Filter field not found in ", manifest$table[[i]], ": ", field)
      table <- table[table[[field]] %in% filters[[field]], , drop = FALSE]
    }
    if (!is.null(columns)) {
      keep <- intersect(columns, names(table))
      table <- table[, keep, drop = FALSE]
    }
    if (!"TAX_YEAR" %in% names(table)) table$TAX_YEAR <- manifest$year[[i]]
    name <- paste(manifest$table[[i]], manifest$year[[i]], sep = "::")
    tables[[name]] <- table
    manifest$rows_source[[i]] <- source_n
    manifest$cols_source[[i]] <- source_p
    manifest$rows_selected[[i]] <- nrow(table)
    manifest$cols_selected[[i]] <- ncol(table)
    manifest$exact_duplicates_removed[[i]] <- removed
  }
  structure(list(tables = tables, manifest = manifest,
                 download = downloads), class = "read_result")
}
