test_that("panel_complete interpolates across multi-year gaps", {
  # F keeps 2021/2022 in the panel window; A spans it with a two-year gap.
  df <- data.frame(
    EIN2 = c("A", "A", "F", "F", "F", "F"),
    TAX_YEAR = c(2020, 2023, 2020, 2021, 2022, 2023),
    amount = c(0, 30, 1, 1, 1, 1)
  )
  out <- panel_complete(df, vars = "amount")          # method = "interpolate"
  a <- out[out$EIN2 == "A", ]
  expect_equal(a$amount[a$TAX_YEAR == 2021], 10)      # linear 0 -> 30 over 2020-2023
  expect_equal(a$amount[a$TAX_YEAR == 2022], 20)
  expect_true(all(a$imputed_row[a$TAX_YEAR %in% c(2021, 2022)]))
})

test_that("fill methods differ (mean vs interpolate vs locf vs nocb)", {
  df <- data.frame(
    EIN2 = c("A", "A", "F", "F", "F", "F"),
    TAX_YEAR = c(2020, 2023, 2020, 2021, 2022, 2023),
    amount = c(0, 30, 1, 1, 1, 1)
  )
  pick <- function(m) {
    o <- panel_complete(df, method = m, vars = "amount")
    o$amount[o$EIN2 == "A" & o$TAX_YEAR %in% c(2021, 2022)]
  }
  expect_equal(pick("mean"), c(15, 15))
  expect_equal(pick("interpolate"), c(10, 20))
  expect_equal(pick("locf"), c(0, 0))
  expect_equal(pick("nocb"), c(30, 30))
})

test_that("panel_complete fills non-persistent segmented spans; panel_impute does not", {
  df <- data.frame(
    EIN2 = c("A", "A", "C", "C", "F", "F", "F", "F"),
    TAX_YEAR = c(2020, 2023, 2021, 2023, 2020, 2021, 2022, 2023),
    amount = c(0, 30, 100, 200, 1, 1, 1, 1)   # C = entrant (enters 2021), gap 2022
  )
  base <- panel_impute(df, vars = "amount")           # default types = "persistent"
  expect_false(any(base$EIN2 == "C" & base$imputed_row))

  comp <- panel_complete(df, vars = "amount")         # all types
  filled <- comp[comp$EIN2 == "C" & comp$TAX_YEAR == 2022, ]
  expect_equal(nrow(filled), 1L)
  expect_true(filled$imputed_row)
  expect_equal(filled$amount, 150)                    # interpolate 100 -> 200
})
