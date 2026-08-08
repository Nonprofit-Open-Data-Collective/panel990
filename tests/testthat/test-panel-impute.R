test_that("panel imputation inserts and averages an internal year", {
  data <- data.frame(
    EIN2 = c("A", "A", "B", "B", "B"),
    TAX_YEAR = c(2020, 2022, 2020:2022),
    amount = c(10, 30, 1, 2, 3)
  )
  out <- panel_impute(data, vars = "amount")
  added <- out[out$EIN2 == "A" & out$TAX_YEAR == 2021, ]
  expect_equal(nrow(added), 1L)
  expect_equal(added$amount, 20)
  expect_true(added$imputed_row)
})

test_that("gap guards prevent imputation", {
  data <- data.frame(
    EIN2 = c(rep("A", 2), rep("B", 4)),
    TAX_YEAR = c(2020, 2023, 2020:2023),
    amount = c(10, 40, 1:4)
  )
  out <- panel_impute(data, vars = "amount", max_gap_size = 1)
  expect_equal(nrow(out), nrow(data))
})

test_that("out-of-scope tails are not inserted", {
  data <- data.frame(
    EIN2 = c(rep("A", 2), rep("B", 4)),
    TAX_YEAR = c(2022:2023, 2020:2023),
    amount = 1:6
  )
  out <- panel_impute(data, types = "entrant", vars = "amount")
  expect_equal(nrow(out[out$EIN2 == "A", ]), 2L)
})
