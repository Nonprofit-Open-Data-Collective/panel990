#' Read acquired efile CSV tables
#'
#' Deduplication runs on a `data.table`. Base `duplicated()` on a wide
#' `data.frame` pastes every row into a string and dominates the cost of this
#' step -- on a 555k x 80 header table it takes roughly 47 seconds against
#' under a second here, for identical results.
#'
#' @param downloads Result from [download_tables()].
#' @param columns Optional fields to retain; join keys should be included.
#' @param filters Named list of accepted values, such as `list(EIN2 = eins)`.
#' @param unique_rows Remove exact duplicate rows.
#' @param verbose Print per-table progress messages.
#' @return An `read_result` with named tables and an augmented manifest.
#' @export
read_tables <- function(
    downloads,
    columns = NULL,
    filters = NULL,
    unique_rows = TRUE,
    verbose = TRUE
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
  total <- length(success_rows)
  step <- 0L
  for (i in success_rows) {
    path <- manifest$path[[i]]
    step <- step + 1L
    label <- paste0("[", step, "/", total, "] ", manifest$table[[i]], " ",
                    manifest$year[[i]])
    started <- Sys.time()
    if (isTRUE(verbose))
      .p990_say("-> READ     ", label, " (",
                .p990_bytes(manifest$bytes[[i]]), ")")

    # Read as a data.table purely so duplicated() dispatches to the fast
    # method, then convert before subsetting: this package does not declare
    # itself data.table-aware, so `[` on a data.table would fall back to
    # data.frame semantics and treat a row filter as a column selection.
    dt <- data.table::fread(path, showProgress = FALSE, data.table = TRUE)
    source_n <- nrow(dt)
    source_p <- ncol(dt)
    removed <- 0L
    duplicate <- if (unique_rows) duplicated(dt) else NULL
    # setDF() converts in place; as.data.frame() would copy the whole table.
    table <- data.table::setDF(dt)
    if (!is.null(duplicate)) {
      removed <- sum(duplicate)
      if (removed > 0L) table <- table[!duplicate, , drop = FALSE]
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
    if (isTRUE(verbose))
      .p990_say("<- READ OK  ", label, " ",
                format(nrow(table), big.mark = ","), " x ", ncol(table),
                " in ", round(as.numeric(difftime(Sys.time(), started,
                                                  units = "secs")), 1L), "s",
                if (removed > 0L)
                  paste0(" (", format(removed, big.mark = ","),
                         " duplicate row(s) removed)") else "")
  }
  structure(list(tables = tables, manifest = manifest,
                 download = downloads), class = "read_result")
}
