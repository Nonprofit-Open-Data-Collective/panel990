make_balance_fixture <- function() data.frame(
  EIN2 = c(rep("A", 4), rep("B", 4), rep("C", 3), rep("D", 2)),
  TAX_YEAR = c(2019:2022, 2019:2022, 2019:2021, c(2019, 2020)),
  v = seq_len(13),
  stringsAsFactors = FALSE
)

test_that("panel_balance trims to the full-range rectangle by default", {
  out <- panel_balance(make_balance_fixture(), id = "EIN2", time = "TAX_YEAR")
  expect_setequal(unique(out$EIN2), c("A", "B"))       # only orgs in all 4 years
  expect_setequal(unique(out$TAX_YEAR), 2019:2022)
  expect_equal(nrow(out), 8L)
  expect_equal(attr(out, "balance")$orgs_dropped, 2L)  # C, D dropped
})

test_that("an explicit year window keeps orgs complete over just that window", {
  out <- panel_balance(make_balance_fixture(), years = 2019:2021,
                       id = "EIN2", time = "TAX_YEAR")
  expect_setequal(unique(out$EIN2), c("A", "B", "C"))  # D lacks 2021
  expect_setequal(unique(out$TAX_YEAR), 2019:2021)
  expect_equal(attr(out, "balance")$n_years, 3L)
})

test_that("max_rectangle picks the largest balanced block (orgs x years)", {
  # windows: 2019-22 -> 2x4=8; 2019-21 -> 3x3=9; 2019-20 -> 4x2=8. Best = 2019-21.
  out <- panel_balance(make_balance_fixture(), strategy = "max_rectangle",
                       id = "EIN2", time = "TAX_YEAR")
  expect_setequal(unique(out$EIN2), c("A", "B", "C"))
  expect_setequal(unique(out$TAX_YEAR), 2019:2021)
})

test_that("panel_balance can end up empty when nobody spans the window", {
  df <- data.frame(EIN2 = c("A", "B"), TAX_YEAR = c(2019, 2020),
                   stringsAsFactors = FALSE)
  out <- panel_balance(df, id = "EIN2", time = "TAX_YEAR")
  expect_equal(nrow(out), 0L)
  expect_equal(attr(out, "balance")$orgs_kept, 0L)
})
