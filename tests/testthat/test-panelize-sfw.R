make_sfw_panel_source <- function() {
  root <- tempfile("sfw-panel-")
  dir.create(root)
  for (year in 2020:2021) {
    header <- data.frame(
      EIN2 = c("EIN-12-3456789", "EIN-98-7654321"),
      OBJECTID = paste0("O", year, c("A", "B")),
      RETURN_TYPE = c("990", "990EZ"), stringsAsFactors = FALSE)
    summary <- data.frame(
      EIN2 = header$EIN2, OBJECTID = header$OBJECTID,
      revenue = c(100, 200) + year, stringsAsFactors = FALSE)
    utils::write.csv(header, file.path(root, paste0("F9-P00-T00-HEADER-", year, ".CSV")),
                     row.names = FALSE)
    utils::write.csv(summary, file.path(root, paste0("F9-P01-T00-SUMMARY-", year, ".CSV")),
                     row.names = FALSE)
  }
  root
}

test_that("panelize pushes the entity restriction to read-time and applies rules", {
  root <- make_sfw_panel_source(); cache <- tempfile("sfw-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)

  sfw <- create_sfw("study", eins = "EIN-12-3456789")
  sfw <- add_rule(sfw, "recent", "filter", column = "revenue", op = ">=",
                  values = 2121)

  res <- panelize(2020:2021, c("P00", "P01"), source = data_source(root),
                  sfw = sfw, path = cache, verbose = FALSE)

  expect_s3_class(res, "panel990")
  # entity pushdown: only EIN-12 rows were ever read
  keep <- res$table_manifest$status %in% c("downloaded", "reused")
  expect_true(all(res$table_manifest$rows_selected[keep] == 1L))
  # post-assembly filter kept only the 2021 row (revenue 2121)
  expect_equal(nrow(res$data), 1L)
  expect_equal(res$data$EIN2, "EIN-12-3456789")
  expect_equal(res$data$TAX_YEAR, 2021)
  expect_false(is.null(res$sfw))
  expect_false(is.null(res$sfw_steps))
})

test_that("panelize applies a BMF trait filter after a BMF merge", {
  root <- make_sfw_panel_source(); cache <- tempfile("sfw-cache2-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)

  bmf <- data.frame(EIN2 = c("EIN-12-3456789", "EIN-98-7654321"),
                    geo_state_abbr = c("GA", "FL"), stringsAsFactors = FALSE)
  sfw <- create_sfw("ga study", state = "GA")

  res <- suppressWarnings(panelize(
    2020:2021, c("P00", "P01"), source = data_source(root),
    sfw = sfw, bmf = bmf, path = cache, verbose = FALSE))

  expect_setequal(unique(res$data$EIN2), "EIN-12-3456789")   # only the GA org
  expect_true("geo_state_abbr" %in% names(res$data))
  expect_false(is.null(res$bmf_diagnostics))
})

test_that("panelize still works without a sample frame", {
  root <- make_sfw_panel_source(); cache <- tempfile("sfw-cache3-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  res <- panelize(2020:2021, c("P00", "P01"), source = data_source(root),
                  path = cache, keys = c("EIN2", "OBJECTID", "TAX_YEAR"),
                  verbose = FALSE)
  expect_equal(nrow(res$data), 4L)
  expect_null(res$sfw)
})
