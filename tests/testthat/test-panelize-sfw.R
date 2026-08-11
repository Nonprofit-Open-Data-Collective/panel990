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

test_that("panelize returns a panel, pushes down the entity, and applies rules", {
  root <- make_sfw_panel_source(); cache <- tempfile("sfw-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)

  sfw <- create_sfw("study", eins = "EIN-12-3456789")
  sfw <- add_rule(sfw, "recent", "filter", column = "revenue", op = ">=",
                  values = 2121)

  res <- panelize(sfw, tables = c("P00", "P01"), years = 2020:2021,
                  source = data_source(root), path = cache, verbose = FALSE)

  expect_s3_class(res, "panel")
  keep <- res$table_manifest$status %in% c("downloaded", "reused")
  expect_true(all(res$table_manifest$rows_selected[keep] == 1L))  # entity pushdown
  expect_equal(nrow(as.data.frame(res)), 1L)                      # revenue filter
  expect_equal(res$data$EIN2, "EIN-12-3456789")
  expect_equal(res$data$TAX_YEAR, 2021)
  expect_s3_class(sample_frame(res), "sfw")
  expect_true(nrow(manifest(res)) > 0)                            # provenance logged
})

test_that("panelize applies a BMF trait filter after a BMF merge", {
  root <- make_sfw_panel_source(); cache <- tempfile("sfw-cache2-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)

  bmf <- data.frame(EIN2 = c("EIN-12-3456789", "EIN-98-7654321"),
                    geo_state_abbr = c("GA", "FL"), stringsAsFactors = FALSE)
  sfw <- create_sfw("ga study", state = "GA")

  res <- suppressWarnings(panelize(
    sfw, tables = c("P00", "P01"), years = 2020:2021,
    source = data_source(root), bmf = bmf, path = cache, verbose = FALSE))

  expect_setequal(unique(res$data$EIN2), "EIN-12-3456789")
  expect_true("geo_state_abbr" %in% names(res$data))
  expect_false(is.null(res$bmf_diagnostics))
})

test_that("panelize works without a sample frame (auto keys/frame)", {
  root <- make_sfw_panel_source(); cache <- tempfile("sfw-cache3-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  res <- panelize(tables = c("P00", "P01"), years = 2020:2021,
                  source = data_source(root), path = cache, verbose = FALSE)
  expect_s3_class(res, "panel")
  expect_equal(nrow(res$data), 4L)
  expect_s3_class(sample_frame(res), "sfw")          # a default frame is created
})
