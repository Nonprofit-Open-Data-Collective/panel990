test_that("cache none is restricted to DuckDB", {
  expect_error(
    panelize(2022, "P00", cache = "none", backend = "memory"),
    "requires"
  )
})

make_duckdb_source <- function() {
  root <- tempfile("duckdb-source-")
  dir.create(root)
  for (year in 2021:2022) {
    header <- data.frame(EIN2 = "EIN-12-3456789", OBJECTID = paste0("O", year))
    summary <- data.frame(EIN2 = header$EIN2, OBJECTID = header$OBJECTID,
                          revenue = year)
    utils::write.csv(header, file.path(root, paste0("F9-P00-T00-HEADER-", year, ".CSV")),
                     row.names = FALSE)
    utils::write.csv(summary, file.path(root, paste0("F9-P01-T00-SUMMARY-", year, ".CSV")),
                     row.names = FALSE)
  }
  root
}

test_that("DuckDB and memory backends agree on local fixtures", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_duckdb_source()
  memory_cache <- tempfile("memory-cache-")
  duck_cache <- tempfile("duck-cache-")
  on.exit(unlink(c(root, memory_cache, duck_cache), recursive = TRUE), add = TRUE)
  args <- list(
    years = 2021:2022, tables = c("P00", "P01"), source = data_source(root),
    keys = c("EIN2", "OBJECTID", "TAX_YEAR"), verbose = FALSE
  )
  memory <- do.call(panelize, c(args, list(path = memory_cache, backend = "memory")))
  duck <- do.call(panelize, c(args, list(path = duck_cache, backend = "duckdb")))
  expect_equal(duck$data, memory$data)
  expect_equal(duck$table_manifest$rows_selected,
               memory$table_manifest$rows_selected)
  expect_equal(duck$join_manifest$rows_after, memory$join_manifest$rows_after)
})

test_that("DuckDB dependency error is actionable", {
  if (requireNamespace("duckdb", quietly = TRUE)) skip("duckdb is installed")
  root <- make_duckdb_source()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  expect_error(
    panelize(2021, "P00", source = data_source(root),
                backend = "duckdb", cache = "none", verbose = FALSE),
    "requires.*DBI.*duckdb"
  )
})
