make_bmf_fixture <- function() {
  data.frame(
    EIN2 = c("EIN-12-3456789", "EIN-12-3456789", "EIN-98-7654321"),
    org_name_display = c("Old Name", "Current Name", "Second Org"),
    ruling_date = c("1990-01-01", "1900-01-01", "2005-06-01"),
    ruling_date_is_missing = c(FALSE, TRUE, FALSE),
    revenue_amount = c(10, 20, 30),
    geo_state_abbr = c("AZ", "AZ", "NM"),
    bmf_source = c("legacy", "current", "current"),
    bmf_vintage_ym = c("2025-01", "2026-06", "2026-06"),
    stringsAsFactors = FALSE
  )
}

test_that("BMF API exposes native defaults", {
  expect_match(bmf_url(), "bmf_master_geocoded\\.csv$")
  expect_true(all(c("EIN2", "nteev2", "revenue_amount", "bmf_vintage_ym") %in%
                    bmf_vars()))
  expect_false(any(grepl("^(CENSUS_|F990_|NTEE_|BMF_|ORG_)", bmf_vars())))
})

test_that("BMF preparation resolves vintage and ruling sentinel", {
  out <- bmf_prepare(
    make_bmf_fixture(),
    vars = c("org_name_display", "ruling_date", "ruling_year",
             "bmf_source", "bmf_vintage_ym"),
    verbose = FALSE
  )
  diagnostics <- attr(out, "bmf_diagnostics")

  expect_equal(nrow(out), 2L)
  expect_equal(out$org_name_display[out$EIN2 == "EIN-12-3456789"],
               "Current Name")
  expect_true(is.na(out$ruling_year[out$EIN2 == "EIN-12-3456789"]))
  expect_equal(out$ruling_year[out$EIN2 == "EIN-98-7654321"], 2005L)
  expect_equal(diagnostics$duplicate_rows_resolved, 1L)
})

test_that("BMF unavailable fields are reported or rejected", {
  expect_warning(
    out <- bmf_prepare(
      make_bmf_fixture(), vars = c("org_name_display", "absent"),
      verbose = FALSE
    ),
    "absent"
  )
  expect_equal(attr(out, "bmf_diagnostics")$missing_requested_fields, "absent")
  expect_error(
    bmf_prepare(make_bmf_fixture(), vars = "absent", strict = TRUE,
                      verbose = FALSE),
    "absent"
  )
})

test_that("BMF merge preserves rows and input order", {
  data <- data.frame(
    EIN2 = c("EIN-98-7654321", "EIN-00-0000001", "EIN-12-3456789",
             "EIN-12-3456789"),
    marker = 1:4,
    stringsAsFactors = FALSE
  )
  out <- bmf_merge(
    data, make_bmf_fixture(),
    vars = c("org_name_display", "revenue_amount", "bmf_vintage_ym"),
    verbose = FALSE
  )
  diagnostics <- attr(out, "bmf_diagnostics")

  expect_equal(nrow(out), 4L)
  expect_equal(out$marker, 1:4)
  expect_equal(out$org_name_display[3:4], rep("Current Name", 2L))
  expect_true(is.na(out$org_name_display[2]))
  expect_equal(diagnostics$matched_rows, 3L)
  expect_equal(diagnostics$unmatched_distinct_eins, 1L)
})

test_that("BMF retrieval accepts local CSV files", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path), add = TRUE)
  utils::write.csv(make_bmf_fixture(), path, row.names = FALSE, na = "")

  out <- bmf_retrieve(
    path, vars = c("org_name_display", "bmf_vintage_ym"), verbose = FALSE
  )

  expect_equal(nrow(out), 2L)
  expect_equal(attr(out, "bmf_diagnostics")$source_type, "local_file")
})
