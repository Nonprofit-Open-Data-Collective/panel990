test_that("data_source carries and validates a source format", {
  expect_equal(data_source()$format, .EFILE_FORMAT)
  expect_equal(data_source(format = "parquet")$format, "parquet")
  # Case and whitespace are normalized; "pq" is accepted sugar.
  expect_equal(data_source(format = " PARQUET ")$format, "parquet")
  expect_equal(data_source(format = "pq")$format, "parquet")
  expect_error(data_source(format = "orc"), "must be one of")
  expect_error(data_source(format = NA_character_), "must be one of")
})

test_that("filenames and format detection follow the extension", {
  expect_equal(.efile_filename("F9-P00-T00-HEADER", 2011, "csv"),
               "F9-P00-T00-HEADER-2011.CSV")
  expect_equal(.efile_filename("F9-P00-T00-HEADER", 2011, "parquet"),
               "F9-P00-T00-HEADER-2011.parquet")
  expect_equal(.efile_format_of("a/b/F9-P00-T00-HEADER-2011.parquet"), "parquet")
  expect_equal(.efile_format_of("a/b/F9-P00-T00-HEADER-2011.CSV"), "csv")
  # A published URL is detected the same way as a local path.
  expect_equal(.efile_format_of("https://x/y/T-2011.PARQUET"), "parquet")
})

test_that("declared efile types cover structural keys and form variables", {
  types <- .p990_efile_types()
  # Structural filing columns are build artifacts and absent from the
  # concordance, so they are declared explicitly.
  expect_equal(unname(types["TAX_YEAR"]), "integer")
  expect_equal(unname(types["EIN2"]), "text")
  # ORG_EIN must stay text: fread() infers integer and drops leading zeros.
  expect_equal(unname(types["ORG_EIN"]), "text")
  # Form variables come from field_concordance$data_type_simple.
  expect_equal(unname(types["F9_01_REV_TOT_CY"]), "numeric")
  expect_true(all(c("numeric", "checkbox", "text", "date") %in% types))
  # Restricting to requested fields drops unknown names rather than erroring.
  expect_equal(names(.p990_efile_types(c("EIN2", "NOT_A_FIELD"))), "EIN2")
})

test_that("coercion casts declared numerics and leaves everything else alone", {
  df <- data.frame(
    EIN2 = "EIN-01-0078060", ORG_EIN = "010078060", TAX_YEAR = "2011",
    RETURN_TYPE = "990EZ", F9_01_REV_TOT_CY = "1234",
    TAX_PERIOD_END_DATE = "2011-12-31", USER_COLUMN = "7",
    stringsAsFactors = FALSE
  )
  out <- .p990_coerce(df)
  expect_type(out$TAX_YEAR, "integer")
  expect_type(out$F9_01_REV_TOT_CY, "double")
  expect_equal(out$F9_01_REV_TOT_CY, 1234)
  # Text, dates, and checkboxes stay as source strings; normalize() reads them.
  expect_type(out$EIN2, "character")
  expect_equal(out$ORG_EIN, "010078060")
  expect_type(out$TAX_PERIOD_END_DATE, "character")
  # A column with no declared type is never touched.
  expect_equal(out$USER_COLUMN, "7")
})

test_that("a blank numeric is NA but an unparseable one warns", {
  blank <- data.frame(F9_01_REV_TOT_CY = c("", "  ", "5"),
                      stringsAsFactors = FALSE)
  # A blank is a legitimate absent value; normalize() decides if it means zero.
  expect_silent(out <- .p990_coerce(blank))
  expect_equal(out$F9_01_REV_TOT_CY, c(NA, NA, 5))

  bad <- data.frame(F9_01_REV_TOT_CY = c("1", "not-a-number"),
                    stringsAsFactors = FALSE)
  expect_warning(out <- .p990_coerce(bad, label = "T 2011"),
                 "not-a-number")
  expect_equal(out$F9_01_REV_TOT_CY, c(1, NA))
})

# A parquet fixture written the way the efile build writes one: every column a
# string, sorted by EIN2.
make_parquet_source <- function() {
  root <- tempfile("parquet-source-")
  dir.create(root)
  for (year in 2021:2022) {
    eins <- sprintf("EIN-12-345678%d", 1:4)
    header <- data.frame(
      EIN2 = eins, OBJECTID = paste0("O", year, 1:4),
      ORG_EIN = c("012345681", "012345682", "012345683", "012345684"),
      TAX_YEAR = as.character(year),
      RETURN_TYPE = c("990", "990EZ", "990", "990EZ"),
      stringsAsFactors = FALSE
    )
    summary <- data.frame(
      EIN2 = eins, OBJECTID = header$OBJECTID,
      TAX_YEAR = as.character(year),
      F9_01_REV_TOT_CY = as.character(seq(1000, 4000, by = 1000) + year),
      stringsAsFactors = FALSE
    )
    arrow::write_parquet(header,
      file.path(root, paste0("F9-P00-T00-HEADER-", year, ".parquet")))
    arrow::write_parquet(summary,
      file.path(root, paste0("F9-P01-T00-SUMMARY-", year, ".parquet")))
  }
  root
}

test_that("a parquet source builds a panel with declared types", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_parquet_source()
  cache <- tempfile("parquet-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)

  panel <- panelize(tables = c("P00", "P01"), years = 2021:2022,
                    source = data_source(root, format = "parquet"),
                    path = cache, bmf = FALSE, verbose = FALSE)
  data <- panel_data(panel)
  expect_equal(nrow(data), 8L)
  # Parquet holds strings; the read casts using the declared types.
  expect_type(data$TAX_YEAR, "integer")
  expect_type(data$F9_01_REV_TOT_CY, "double")
  expect_setequal(data$F9_01_REV_TOT_CY,
                  c(seq(1000, 4000, 1000) + 2021, seq(1000, 4000, 1000) + 2022))
  # Leading zeros survive, which they would not under fread()'s inference.
  expect_equal(sort(unique(data$ORG_EIN))[1], "012345681")
})

test_that("both backends agree on a parquet source", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_parquet_source()
  memory_cache <- tempfile("pq-memory-")
  duck_cache <- tempfile("pq-duck-")
  on.exit(unlink(c(root, memory_cache, duck_cache), recursive = TRUE),
          add = TRUE)
  args <- list(tables = c("P00", "P01"), years = 2021:2022,
               source = data_source(root, format = "parquet"),
               bmf = FALSE, verbose = FALSE)

  # Neither backend promises a row order -- DuckDB's DISTINCT and
  # merge(sort = FALSE) are both free to permute -- so compare on the keys.
  canonical <- function(panel) {
    data <- panel_data(panel)
    data <- data[order(data$OBJECTID), sort(names(data)), drop = FALSE]
    rownames(data) <- NULL
    data
  }

  memory <- do.call(panelize, c(args, list(path = memory_cache,
                                           backend = "memory")))
  duck <- do.call(panelize, c(args, list(path = duck_cache,
                                         backend = "duckdb")))
  expect_equal(canonical(duck), canonical(memory))

  # ... and with deduplication off, which is what lets the projection be
  # pushed into the scan.
  memory2 <- do.call(panelize, c(args, list(path = memory_cache,
    backend = "memory", unique_rows = FALSE)))
  duck2 <- do.call(panelize, c(args, list(path = duck_cache,
    backend = "duckdb", unique_rows = FALSE)))
  expect_equal(canonical(duck2), canonical(memory2))
  # Turning deduplication off changes nothing: the build has no exact dupes.
  expect_equal(canonical(memory2), canonical(memory))
})

test_that("a pushed-down projection still reports true source dimensions", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_parquet_source()
  cache <- tempfile("pq-dims-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)

  downloads <- download_tables(2021, "P00",
                               source = data_source(root, format = "parquet"),
                               path = cache, verbose = FALSE)
  reads <- read_tables(downloads, columns = c("EIN2", "TAX_YEAR"),
                       unique_rows = FALSE, verbose = FALSE)
  # cols_source describes the file, not the projection: the row and column
  # counts come from the parquet footer rather than the loaded frame.
  expect_equal(reads$manifest$cols_source, 5L)
  expect_equal(reads$manifest$rows_source, 4L)
  expect_equal(reads$manifest$cols_selected, 2L)
  expect_equal(reads$manifest$rows_selected, 4L)
})

test_that("filters and projections push into a parquet read", {
  skip_if_not_installed("arrow")
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_parquet_source()
  cache <- tempfile("pq-filter-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  downloads <- download_tables(2021, "P00",
                               source = data_source(root, format = "parquet"),
                               path = cache, verbose = FALSE)

  for (unique_rows in c(TRUE, FALSE)) {
    reads <- read_tables(downloads, columns = c("EIN2", "RETURN_TYPE"),
                         filters = list(RETURN_TYPE = "990EZ"),
                         unique_rows = unique_rows, verbose = FALSE)
    table <- reads$tables[[1L]]
    expect_equal(nrow(table), 2L)
    expect_true(all(table$RETURN_TYPE == "990EZ"))
  }
  # An unknown filter field is an error on either path.
  expect_error(read_tables(downloads, filters = list(NOPE = 1),
                           unique_rows = FALSE, verbose = FALSE),
               "Filter field not found")
  expect_error(read_tables(downloads, filters = list(NOPE = 1),
                           unique_rows = TRUE, verbose = FALSE),
               "Filter field not found")
})

test_that("cache = 'none' reaches a merged panel", {
  # merge_tables() recognized only the cached statuses, so a virtual scan
  # produced reads that were then silently dropped at the merge step.
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- tempfile("virtual-source-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  for (year in 2021:2022) {
    header <- data.frame(EIN2 = "EIN-12-3456789", OBJECTID = paste0("O", year))
    utils::write.csv(header,
      file.path(root, paste0("F9-P00-T00-HEADER-", year, ".CSV")),
      row.names = FALSE)
    utils::write.csv(cbind(header, revenue = year),
      file.path(root, paste0("F9-P01-T00-SUMMARY-", year, ".CSV")),
      row.names = FALSE)
  }

  panel <- panelize(tables = c("P00", "P01"), years = 2021:2022,
                    source = data_source(root), backend = "duckdb",
                    cache = "none", bmf = FALSE, verbose = FALSE)
  expect_equal(nrow(panel_data(panel)), 2L)
  expect_true(all(panel$download_manifest$status == "virtual"))
  expect_setequal(panel_data(panel)$revenue, 2021:2022)
})
