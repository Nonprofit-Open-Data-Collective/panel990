.EFILE_FILING_KEYS <- c(
  "EIN2", "OBJECTID", "ORG_EIN", "ORG_NAME_L1", "ORG_NAME_L2",
  "RETURN_AMENDED_X", "RETURN_GROUP_X", "RETURN_PARTIAL_X",
  "RETURN_TAXPER_DAYS", "RETURN_TIME_STAMP", "RETURN_TYPE",
  "TAX_PERIOD_BEGIN_DATE", "TAX_PERIOD_END_DATE", "TAX_YEAR", "URL", "VERSION"
)

#' Merge efile tables using explicit filing keys
#'
#' @param reads Result from [read_tables()].
#' @param keys Candidate join keys. Every merge uses the shared subset and
#'   requires at least one key.
#' @param include_many Join `1xm` and supplemental tables. Default `FALSE`.
#' @param collision `"error"` or `"prefix"` for shared non-key field names.
#' @param verbose Print per-join progress messages.
#' @return An `merge_result` containing one merged data frame per year,
#'   a table manifest, and a join manifest.
#' @export
merge_tables <- function(
    reads,
    keys = .EFILE_FILING_KEYS,
    include_many = FALSE,
    collision = c("error", "prefix"),
    verbose = TRUE
) {
  collision <- match.arg(collision)
  if (!inherits(reads, "read_result"))
    stop("`reads` must be returned by read_tables().")
  manifest <- reads$manifest
  years <- sort(unique(manifest$year[manifest$status %in% c("downloaded", "reused")]))
  panels <- list()
  joins <- list()
  j <- 0L
  for (year in years) {
    rows <- which(manifest$year == year &
                    manifest$status %in% c("downloaded", "reused"))
    if (!length(rows)) next
    selected <- rows[include_many |
      manifest$cardinality[rows] == "1x1"]
    skipped <- setdiff(rows, selected)
    if (length(skipped)) manifest$status[skipped] <- "read_not_joined_many"
    if (!length(selected)) next
    left <- NULL
    left_name <- NA_character_
    for (i in selected) {
      name <- paste(manifest$table[[i]], year, sep = "::")
      right <- reads$tables[[name]]
      key <- intersect(keys, names(right))
      # duplicated() via data.table: the base data.frame method pastes rows
      # into strings and is orders of magnitude slower on efile-sized tables.
      duplicate_keys <- if (length(key))
        sum(duplicated(data.table::as.data.table(right[, key, drop = FALSE])))
        else NA_integer_
      if (manifest$cardinality[[i]] == "1x1" && !is.na(duplicate_keys) && duplicate_keys > 0L)
        stop("Unexpected duplicate keys in 1x1 table ", manifest$table[[i]], ".")
      if (is.null(left)) {
        left <- right
        left_name <- manifest$table[[i]]
        next
      }
      by <- intersect(keys, intersect(names(left), names(right)))
      if (!length(by)) stop("No shared explicit join keys for ", manifest$table[[i]], ".")
      collisions <- setdiff(intersect(names(left), names(right)), by)
      if (length(collisions)) {
        if (collision == "error")
          stop("Non-key field collision in ", manifest$table[[i]], ": ",
               paste(collisions, collapse = ", "))
        names(right)[match(collisions, names(right))] <- paste0(manifest$table[[i]], "__", collisions)
      }
      before <- nrow(left)
      right_rows <- nrow(right)
      started <- Sys.time()
      if (isTRUE(verbose))
        .p990_say("-> MERGE    ", year, ": ", left_name, " + ",
                  manifest$table[[i]], " on ", paste(by, collapse = ", "))
      left <- merge(left, right, by = by, all = TRUE, sort = FALSE)
      if (isTRUE(verbose))
        .p990_say("<- MERGE OK ", year, " ", format(nrow(left), big.mark = ","),
                  " x ", ncol(left), " in ",
                  round(as.numeric(difftime(Sys.time(), started,
                                            units = "secs")), 1L), "s")
      j <- j + 1L
      joins[[j]] <- data.frame(
        year = year, left = left_name, right = manifest$table[[i]],
        keys = paste(by, collapse = ";"), expected_cardinality = manifest$cardinality[[i]],
        right_duplicate_keys = duplicate_keys, rows_left_before = before,
        rows_right = right_rows, rows_after = nrow(left),
        collisions = paste(collisions, collapse = ";"), stringsAsFactors = FALSE
      )
      left_name <- paste(left_name, manifest$table[[i]], sep = "+")
    }
    panels[[as.character(year)]] <- left
  }
  join_manifest <- if (length(joins)) do.call(rbind, joins) else data.frame(
    year = integer(), left = character(), right = character(), keys = character(),
    expected_cardinality = character(), right_duplicate_keys = integer(),
    rows_left_before = integer(), rows_right = integer(), rows_after = integer(),
    collisions = character(), stringsAsFactors = FALSE
  )
  structure(list(years = panels, table_manifest = manifest,
                 join_manifest = join_manifest, read = reads),
            class = "merge_result")
}
