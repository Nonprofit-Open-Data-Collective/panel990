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
  reads <- read_tables(downloads, filters = list(EIN2 = "EIN-12-3456789"))
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
  ))
  merged <- merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"))
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
  ))
  safe <- merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"))
  expanded <- merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"),
                          include_many = TRUE)
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
  ))
  expect_error(merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR")),
               "collision")
  prefixed <- merge_tables(reads, keys = c("EIN2", "OBJECTID", "TAX_YEAR"),
                          collision = "prefix")
  expect_true(any(grepl("__ORG_NAME_L1$", names(prefixed$years[["2021"]]))))
})
