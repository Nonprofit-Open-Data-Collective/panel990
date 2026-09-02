make_panel_source <- function() {
  root <- tempfile("panel-source-")
  dir.create(root)
  for (year in 2021:2022) {
    header <- data.frame(
      EIN2 = c("EIN-12-3456789", "EIN-98-7654321"),
      OBJECTID = paste0("O", year, c("A", "B")),
      ORG_NAME_L1 = c("Alpha", "Beta"), stringsAsFactors = FALSE
    )
    summary <- data.frame(
      EIN2 = header$EIN2, OBJECTID = header$OBJECTID,
      revenue = c(100, 200) + year, stringsAsFactors = FALSE
    )
    repeated <- data.frame(
      EIN2 = rep(header$EIN2[1], 2), OBJECTID = rep(header$OBJECTID[1], 2),
      item = c("x", "y"), stringsAsFactors = FALSE
    )
    utils::write.csv(header, file.path(root, paste0("F9-P00-T00-HEADER-", year, ".CSV")),
                     row.names = FALSE)
    utils::write.csv(summary, file.path(root, paste0("F9-P01-T00-SUMMARY-", year, ".CSV")),
                     row.names = FALSE)
    utils::write.csv(repeated, file.path(root, paste0("CUSTOM-P01-T01-ROWS-", year, ".CSV")),
                     row.names = FALSE)
  }
  root
}

test_that("read layer records table counts and applies filters", {
  root <- make_panel_source()
  cache <- tempfile("panel-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  downloads <- download_tables(2021, c("P00", "P01"), data_source(root),
                              path = cache, verbose = FALSE)
  reads <- read_tables(downloads, filters = list(EIN2 = "EIN-12-3456789"),
                      verbose = FALSE)
  expect_equal(reads$manifest$rows_source, c(2L, 2L))
  expect_equal(reads$manifest$rows_selected, c(1L, 1L))
  expect_equal(length(reads$tables), 2L)
})

test_that("explicit-key merge produces row diagnostics", {
  root <- make_panel_source()
  cache <- tempfile("panel-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  reads <- read_tables(download_tables(
    2021, c("P00", "P01"), data_source(root), path = cache, verbose = FALSE
  ), verbose = FALSE)
  merged <- merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"),
                         verbose = FALSE)
  expect_equal(nrow(merged$years[["2021"]]), 2L)
  expect_equal(merged$join_manifest$rows_after, 2L)
  expect_match(merged$join_manifest$keys, "OBJECTID")
})

test_that("one-to-many tables are skipped unless explicitly enabled", {
  root <- make_panel_source()
  cache <- tempfile("panel-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  reads <- read_tables(download_tables(
    2021, c("P00", "CUSTOM-P01-T01-ROWS"), data_source(root),
    path = cache, verbose = FALSE
  ), verbose = FALSE)
  safe <- merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"),
                       verbose = FALSE)
  expanded <- merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"),
                          include_many = TRUE, verbose = FALSE)
  expect_equal(nrow(safe$years[["2021"]]), 2L)
  expect_equal(nrow(expanded$years[["2021"]]), 3L)
  expect_true("read_not_joined_many" %in% safe$table_manifest$status)
})

test_that("multi-year panel aligns schemas and exposes manifests", {
  root <- make_panel_source()
  cache <- tempfile("panel-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  result <- panelize(
    tables = c("P00", "P01"), years = 2021:2022, source = data_source(root),
    path = cache, verbose = FALSE
  )
  expect_s3_class(result, "panel")
  expect_equal(nrow(result$data), 4L)
  expect_setequal(unique(result$data$TAX_YEAR), 2021:2022)
  expect_equal(nrow(result$download_manifest), 4L)
  expect_equal(nrow(result$join_manifest), 2L)
  expect_equal(as.data.frame(result), result$data)
})

test_that("non-key collisions are rejected or prefixed", {
  root <- make_panel_source()
  cache <- tempfile("panel-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  # Add a colliding non-key field to summary.
  path <- file.path(root, "F9-P01-T00-SUMMARY-2021.CSV")
  summary <- utils::read.csv(path)
  summary$ORG_NAME_L1 <- c("A2", "B2")
  utils::write.csv(summary, path, row.names = FALSE)
  reads <- read_tables(download_tables(
    2021, c("P00", "P01"), data_source(root), path = cache, verbose = FALSE
  ), verbose = FALSE)
  expect_error(merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"), verbose = FALSE),
               "collision")
  prefixed <- merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"),
                          collision = "prefix", verbose = FALSE)
  expect_true(any(grepl("__ORG_NAME_L1$", names(prefixed$years[["2021"]]))))
})

test_that("dedup filters rows, not columns, when rows exceed columns", {
  # Regression: subsetting a data.table with `[` falls back to data.frame
  # semantics here, where x[i] selects COLUMNS. With a 2-row fixture the
  # recycled logical happened to select every column and hid the bug; it only
  # surfaces once the row count exceeds the column count.
  root <- tempfile("efile-wide-")
  cache <- tempfile("efile-cache-")
  dir.create(root)
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)

  n <- 25L
  wide <- data.frame(
    EIN2 = sprintf("EIN-12-%07d", seq_len(n)),
    OBJECTID = seq_len(n),
    TAX_YEAR = 2021L,
    value = seq_len(n),
    stringsAsFactors = FALSE
  )
  wide <- rbind(wide, wide[1L, ])          # one exact duplicate row
  utils::write.csv(wide, file.path(root, "F9-P00-T00-HEADER-2021.CSV"),
                   row.names = FALSE)

  reads <- read_tables(
    download_tables(2021, "P00", data_source(root), path = cache,
                    verbose = FALSE),
    verbose = FALSE
  )
  out <- reads$tables[["F9-P00-T00-HEADER::2021"]]

  expect_equal(nrow(out), n)                        # duplicate dropped
  expect_equal(ncol(out), 4L)                       # all columns retained
  expect_setequal(names(out), names(wide))
  expect_equal(reads$manifest$exact_duplicates_removed, 1L)
  expect_equal(reads$manifest$rows_source, n + 1L)
})

test_that("the package is data.table aware so fast S3 methods are used", {
  # data.table gates its S3 methods on cedta(). Without this flag
  # duplicated.data.table calls NextMethod() into duplicated.data.frame, which
  # is ~16x slower on efile-sized tables and fails silently.
  expect_true(isTRUE(panel990:::.datatable.aware))

  # Confirm dispatch actually lands on the data.table method from inside the
  # package namespace, rather than falling through to the data.frame one.
  dt <- data.table::data.table(a = c(1, 1, 2), b = c("x", "x", "y"))
  seen <- character()
  trace_target <- function(...) {
    seen <<- c(seen, "data.frame")
    duplicated.data.frame(...)
  }
  local_env <- new.env(parent = asNamespace("panel990"))
  assign("duplicated.data.frame", trace_target, envir = local_env)
  out <- eval(quote(duplicated(dt)), envir = list2env(list(dt = dt), parent = local_env))

  expect_equal(out, c(FALSE, TRUE, FALSE))
  expect_length(seen, 0L)   # the data.frame fallback was never reached
})
