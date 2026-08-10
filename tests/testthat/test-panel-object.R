make_panel_obj_fixture <- function() data.frame(
  EIN2 = c(rep("A", 5), rep("B", 3), rep("C", 3), rep("D", 2)),
  TAX_YEAR = c(2019:2023, 2021:2023, 2019:2021, c(2019, 2023)),
  v = seq_len(13), stringsAsFactors = FALSE
)

test_that("as_panel bundles data + sfw and accessors extract them", {
  p <- as_panel(make_panel_obj_fixture())
  expect_true(is_panel(p))
  expect_s3_class(sample_frame(p), "sfw")
  expect_s3_class(as.data.frame(p), "data.frame")
  expect_equal(nrow(as.data.frame(p)), 13L)
  expect_true(is_panel(as_panel(p)))                 # idempotent
})

test_that("panel_describe(panel) stores labels, marks fresh, and logs", {
  p <- panel_describe(as_panel(make_panel_obj_fixture()), print = FALSE)
  expect_true(is_panel(p))
  expect_true(p$fresh)
  expect_true(all(c("panel_type", "panel_spell") %in%
                    get_rules(sample_frame(p))$name))
  m <- manifest(p)
  expect_equal(nrow(m), 1L)
  expect_equal(m$step, "panel_describe")
})

test_that("panel_filter(panel) auto-refreshes, records a rule, logs, filters", {
  # not described yet -> labels stale -> panel_filter refreshes them first
  p <- panel_filter(as_panel(make_panel_obj_fixture()), panel_type = "persistent")
  expect_true(is_panel(p))
  expect_setequal(unique(as.data.frame(p)$EIN2), c("A", "D"))  # both span the window

  m <- manifest(p)
  expect_true(all(c("panel_describe", "panel_filter") %in% m$step))
  expect_true("filter:panel_type" %in% get_rules(sample_frame(p))$name)
  fr <- m[m$step == "panel_filter", ]
  expect_true(fr$rows_after < fr$rows_before)         # rows were dropped
  expect_equal(fr$rows_dropped, fr$rows_before - fr$rows_after)
})

test_that("assume_fresh skips the refresh", {
  p <- panel_describe(as_panel(make_panel_obj_fixture()), print = FALSE)
  n0 <- nrow(manifest(p))
  p <- panel_filter(p, panel_type = "persistent", assume_fresh = TRUE)
  # only the filter step is added (no extra describe)
  expect_equal(sum(manifest(p)$step == "panel_describe"), 1L)
})

test_that("mechanical verbs pipe through a panel, log, and stale labels", {
  df <- data.frame(EIN2 = c("A", "A", "F", "F", "F"),
                   TAX_YEAR = c(2020, 2022, 2020, 2021, 2022),
                   rev = c(0, 30, 1, 1, 1), stringsAsFactors = FALSE)
  p <- panel_describe(as_panel(df), print = FALSE)
  expect_true(p$fresh)

  p2 <- panel_impute(p, vars = "rev")            # inserts A/2021
  expect_true(is_panel(p2))
  expect_false(p2$fresh)                          # imputation staled the labels
  expect_true("panel_impute" %in% manifest(p2)$step)
  expect_equal(nrow(as.data.frame(p2)), nrow(df) + 1L)

  p3 <- panel_update(p2)                          # refresh labels
  expect_true(p3$fresh)
  expect_true("panel_update" %in% manifest(p3)$step)
})

test_that("panel_deduplicate works on a panel and via the deduplicate alias", {
  df <- data.frame(EIN2 = c("A", "A", "B"), TAX_YEAR = 2020,
                   RETURN_TIME_STAMP = c("2021-01-01", "2021-06-01", "2021-01-01"),
                   v = 1:3, stringsAsFactors = FALSE)
  p <- panel_deduplicate(as_panel(df), verbose = FALSE)
  expect_equal(nrow(as.data.frame(p)), 2L)
  expect_true("panel_deduplicate" %in% manifest(p)$step)
  expect_false(p$fresh)                           # dedup staled labels
  expect_equal(nrow(deduplicate(df, verbose = FALSE)), 2L)   # alias, data frame
})

test_that("the data-frame API is unchanged (backward compatible)", {
  df <- make_panel_obj_fixture()
  s <- panel_describe(df, time = "TAX_YEAR", id = "EIN2", print = FALSE)
  expect_s3_class(s, "panel_summary")
  out <- panel_filter(df, panel_type = "persistent")
  expect_s3_class(out, "data.frame")
  expect_setequal(unique(out$EIN2), c("A", "D"))
})
