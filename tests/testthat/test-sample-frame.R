make_sfw_df <- function() data.frame(
  EIN2 = c("A", "A", "A", "B", "B", "C"),
  TAX_YEAR = c(2019, 2020, 2021, 2020, 2021, 2020),
  RETURN_TYPE = c("990", "990", "990EZ", "990", "990", "990EZ"),
  geo_state_abbr = c("GA", "GA", "GA", "FL", "FL", "GA"),
  F9_01_REV_TOT_CY = c(10, 20, 30, 40, 50, 60),
  my_custom = 1:6,
  stringsAsFactors = FALSE
)

test_that("constructor validates and stores keys/metadata", {
  expect_error(create_sample_frame(), "name")
  sfw <- create_sample_frame("test", id_col = "ORG", time_col = "YR")
  expect_s3_class(sfw, "sample_frame")
  expect_equal(sfw$meta$id_col, "ORG")
  expect_equal(length(sfw$filters), 0L)
})

test_that("sugar args lower into filters on the right columns", {
  sfw <- create_sample_frame("t", state = "GA", years = 2020:2021,
                             formtype = "990")
  f <- get_filters(sfw)
  expect_true("geo_state_abbr" %in% f$column)
  expect_true("TAX_YEAR" %in% f$column)
  expect_true("RETURN_TYPE" %in% f$column)
})

test_that("add_filter accumulates, set_filter replaces by column", {
  sfw <- create_sample_frame("t")
  sfw <- add_filter(sfw, "geo_state_abbr", "in", "GA")
  sfw <- add_filter(sfw, "geo_state_abbr", "in", "FL")
  expect_equal(nrow(get_filters(sfw)), 2L)
  sfw <- set_filter(sfw, "geo_state_abbr", "in", c("GA", "FL"))
  expect_equal(sum(get_filters(sfw)$column == "geo_state_abbr"), 1L)
})

test_that("apply_sfw filters rows and leaves origin optional", {
  df <- make_sfw_df()
  sfw <- create_sample_frame("t", state = "GA")          # no origin set
  out <- apply_sfw(df, sfw, verbose = FALSE)
  expect_setequal(unique(out$EIN2), c("A", "C"))
  expect_equal(nrow(out), 4L)
  expect_true(!is.null(attr(out, "sfw_steps")))
})

test_that("between, comparison, and expr filters work", {
  df <- make_sfw_df()
  sfw <- add_filter(create_sample_frame("t"), "TAX_YEAR", "between", c(2020, 2021))
  expect_setequal(unique(apply_sfw(df, sfw, verbose = FALSE)$TAX_YEAR), c(2020, 2021))

  sfw2 <- add_filter(create_sample_frame("t"), op = "expr",
                     values = "F9_01_REV_TOT_CY > 25")
  expect_equal(nrow(apply_sfw(df, sfw2, verbose = FALSE)), 4L)
})

test_that("missing filter columns are skipped, not errors", {
  df <- make_sfw_df()
  sfw <- add_filter(create_sample_frame("t"), "NOT_A_COLUMN", "in", "x")
  expect_silent(out <- apply_sfw(df, sfw, verbose = FALSE))
  expect_equal(nrow(out), nrow(df))
})

test_that("classify_panel stores derived labels filterable by apply_sfw", {
  df <- make_sfw_df()
  sfw <- classify_panel(create_sample_frame("t"), df)
  expect_true(all(c("panel_type", "panel_spell") %in% names(sfw$attributes)))
  # A spans 2019-2021 contiguous -> balanced
  balanced <- apply_sfw(df, sfw, panel_type = "balanced", verbose = FALSE)
  expect_setequal(unique(balanced$EIN2), "A")
})

test_that("column selection keeps header/custom, drops out-of-scope dict vars", {
  data("field_concordance", package = "panel990")
  pc_var <- field_concordance$variable_name[field_concordance$variable_scope == "PC"][1]
  df <- make_sfw_df()
  df[[pc_var]] <- 1:6

  sfw <- keep_cols(create_sample_frame("t"), scope = "both")
  out <- apply_sfw(df, sfw, verbose = FALSE)
  expect_false(pc_var %in% names(out))                 # PC-only dropped from "both"
  expect_true("F9_01_REV_TOT_CY" %in% names(out))      # PZ kept
  expect_true(all(c("EIN2", "TAX_YEAR", "my_custom") %in% names(out)))  # keys/custom kept
})

test_that("conform detects violations and missing keys", {
  df <- make_sfw_df()
  sfw <- create_sample_frame("t", state = "GA")
  res <- conform(df, sfw, verbose = FALSE)
  expect_false(res$conformant)
  expect_equal(res$rows_violating, 2L)               # the two FL rows

  ga_only <- apply_sfw(df, sfw, verbose = FALSE)
  expect_true(conform(ga_only, sfw, verbose = FALSE)$conformant)
})

test_that("update_sample_frame replaces filters by column", {
  sfw <- create_sample_frame("t", years = 2019:2021)
  sfw <- update_sample_frame(sfw, years = 2020:2021)
  yr <- get_filters(sfw)
  expect_equal(sum(yr$column == "TAX_YEAR"), 1L)
  expect_equal(nrow(apply_sfw(make_sfw_df(), sfw, verbose = FALSE)), 5L)
})
