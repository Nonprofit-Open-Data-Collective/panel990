test_that("table resolution supports aliases and arbitrary literal names", {
  out <- resolve_tables(c("P00", "SD-P05-T00-ENDOWMENT",
                                "CUSTOM-P01-T03-ROWS"))
  expect_equal(out$table[1], "F9-P00-T00-HEADER")
  expect_equal(out$cardinality, c("1x1", "1x1", "1xm"))
  expect_equal(out$is_alias, c(TRUE, FALSE, FALSE))
  # The literal SD table is in the canonical catalog; the CUSTOM one is not.
  expect_equal(out$known, c(TRUE, TRUE, FALSE))
})

test_that("table_catalog lists the canonical set and filters by cardinality", {
  full <- table_catalog()
  expect_true(nrow(full) > 100L)
  expect_true(all(c("table", "alias", "cardinality") %in% names(full)))
  expect_true("F9-P08-T00-REVENUE" %in% full$table)
  # Aliases are attached where defined and NA otherwise.
  expect_equal(full$alias[full$table == "F9-P08-T00-REVENUE"], "P08")
  expect_true(is.na(full$alias[full$table == "F9-P02-T00-SIGNATURE"]))
  # Every canonical table resolves to a real alias or literal.
  expect_true(all(table_catalog("supplemental")$cardinality == "supplemental"))
  expect_true(all(table_catalog("1x1")$cardinality == "1x1"))
  expect_equal(
    nrow(table_catalog("1x1")) + nrow(table_catalog("1xm")) +
      nrow(table_catalog("supplemental")),
    nrow(full)
  )
})

make_download_source <- function() {
  root <- tempfile("efile-source-")
  dir.create(root)
  file <- file.path(root, "F9-P00-T00-HEADER-2022.CSV")
  utils::write.csv(data.frame(EIN2 = "EIN-12-3456789", value = 1),
                   file, row.names = FALSE)
  root
}

test_that("local acquisition records downloads, reuse, and unavailable files", {
  source_root <- make_download_source()
  cache <- tempfile("efile-cache-")
  on.exit(unlink(c(source_root, cache), recursive = TRUE), add = TRUE)
  source <- data_source(source_root)

  first <- download_tables(2022, c("P00", "P01"), source = source,
                          path = cache, retry_max = 1, verbose = FALSE)
  second <- download_tables(2022, "P00", source = source,
                           path = cache, verbose = FALSE)

  expect_equal(first$manifest$status, c("downloaded", "failed"))
  expect_equal(second$manifest$status, "reused")
  expect_equal(length(first$files), 1L)
  expect_true(file.exists(first$log_file))
  expect_match(first$manifest$error[2], "Source file not found")
})

test_that("overwrite replaces an existing cached resource", {
  source_root <- make_download_source()
  cache <- tempfile("efile-cache-")
  on.exit(unlink(c(source_root, cache), recursive = TRUE), add = TRUE)
  source <- data_source(source_root)
  download_tables(2022, "P00", source = source, path = cache, verbose = FALSE)
  out <- download_tables(2022, "P00", source = source, path = cache,
                        overwrite = TRUE, verbose = FALSE)
  expect_equal(out$manifest$status, "downloaded")
})

test_that("temporary cache returns readable paths", {
  source_root <- make_download_source()
  on.exit(unlink(source_root, recursive = TRUE), add = TRUE)
  out <- download_tables(2022, "P00", source = data_source(source_root),
                        cache = "temporary", verbose = FALSE)
  expect_true(file.exists(out$files))
  expect_true(file.exists(out$log_file))
})

test_that("each run writes its own log and appends to the run index", {
  source_root <- make_download_source()
  cache <- tempfile("efile-cache-")
  on.exit(unlink(c(source_root, cache), recursive = TRUE), add = TRUE)
  source <- data_source(source_root)

  first <- download_tables(2022, "P00", source = source, path = cache,
                           verbose = FALSE)
  second <- download_tables(2022, "P00", source = source, path = cache,
                            verbose = FALSE)

  # Distinct run ids, distinct files: a later run cannot clobber an earlier one.
  expect_false(identical(first$run_id, second$run_id))
  expect_false(identical(first$log_file, second$log_file))
  expect_true(file.exists(first$log_file))
  expect_true(file.exists(second$log_file))

  index <- retrieval_log(cache)
  expect_equal(nrow(index), 2L)
  expect_setequal(index$run_id, c(first$run_id, second$run_id))
  expect_equal(index$kind, rep("download", 2L))
  expect_equal(index$downloaded, c(1L, 0L))
  expect_equal(index$reused, c(0L, 1L))
})

test_that("retrieval_log reports an empty cache without erroring", {
  expect_message(out <- retrieval_log(tempfile("no-such-cache-")),
                 "No retrieval runs recorded")
  expect_null(out)
})

test_that("a failing fetch retries up to retry_max and records the attempts", {
  source_root <- make_download_source()
  cache <- tempfile("efile-cache-")
  on.exit(unlink(c(source_root, cache), recursive = TRUE), add = TRUE)

  out <- download_tables(2022, "P01", source = data_source(source_root),
                         path = cache, retry_max = 3L, verbose = FALSE)

  expect_equal(out$manifest$status, "failed")
  expect_equal(out$manifest$attempts, 3L)
  expect_match(out$manifest$error, "Source file not found")
  expect_length(out$files, 0L)
})

test_that("data_source resolves a release version or an explicit root", {
  expect_equal(data_source()$version, efile_version())
  expect_match(data_source()$root, "efile_v2_2/$")
  expect_match(data_source(version = "v2_1")$root, "efile_v2_1/$")
  # An explicit root wins and carries no version.
  local <- data_source(tempdir())
  expect_true(is.na(local$version))
  expect_equal(local$root, tempdir())
  expect_error(data_source(version = "2.2"), "must look like")
})
