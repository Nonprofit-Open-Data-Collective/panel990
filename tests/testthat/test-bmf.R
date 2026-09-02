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
  expect_match(bmf_url(), "bmf_unified_geocoded\\.parquet$")
  expect_match(bmf_url("csv"), "bmf_unified_geocoded\\.csv$")
  expect_match(bmf_url("manifest"), "_manifest\\.json$")
  expect_equal(length(bmf_states()), 63L)
  expect_true(all(c("CA", "NY", "DC", "PR", "ZZ") %in% names(bmf_states())))
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

test_that("state marts stack to the unified schema", {
  fixture <- make_bmf_fixture()
  # State marts carry a materialized `state` partition column that the
  # unified file does not; stacking must drop it.
  parts <- list(
    cbind(fixture[1:2, ], state = "AZ", stringsAsFactors = FALSE),
    cbind(fixture[3, , drop = FALSE], state = "NM", stringsAsFactors = FALSE)
  )
  stacked <- panel990:::.bmf_stack(parts)

  expect_equal(nrow(stacked), 3L)
  expect_false("state" %in% names(stacked))
  expect_setequal(names(stacked), names(fixture))
})

test_that("unknown state mart codes are rejected", {
  expect_error(panel990:::.bmf_resolve_states(c("CA", "XX")),
               "Unknown BMF state mart code")
  expect_equal(panel990:::.bmf_resolve_states(c("ca", "ny")), c("CA", "NY"))
  expect_equal(length(panel990:::.bmf_resolve_states(NULL)), 63L)
})

test_that("reading a local BMF file leaves no cache directory behind", {
  path <- tempfile(fileext = ".csv")
  cache <- tempfile("bmf-cache-")
  on.exit(unlink(c(path, cache), recursive = TRUE), add = TRUE)
  utils::write.csv(make_bmf_fixture(), path, row.names = FALSE, na = "")

  out <- bmf_retrieve(path, vars = "org_name_display", path = cache,
                      verbose = FALSE)

  expect_equal(nrow(out), 2L)
  expect_false(dir.exists(cache))
})

test_that("the state mart row-count constants record the observed gap", {
  # The marts are a lagging build; if these ever converge, the warning and the
  # documentation claiming a discrepancy should be revisited.
  expect_lt(panel990:::.BMF_STATE_MART_ROWS, panel990:::.BMF_UNIFIED_ROWS)
  expect_equal(panel990:::.BMF_UNIFIED_ROWS -
                 panel990:::.BMF_STATE_MART_ROWS, 10689L)
})
