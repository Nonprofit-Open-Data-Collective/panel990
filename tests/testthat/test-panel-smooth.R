test_that("panel smoothing preserves shape and fills missing focal values", {
  data <- data.frame(
    EIN2 = rep("A", 5), TAX_YEAR = 2018:2022,
    x = c(100, NaN, 300, 400, 500), y = 1:5
  )
  out <- panel_smooth(data, vars = "x", window = 3, verbose = FALSE)
  expect_equal(dim(out), dim(data))
  expect_equal(out$x[2], 200)
  expect_equal(out$y, data$y)
})

test_that("shifted edge windows and weighting modes are stable", {
  data <- data.frame(EIN2 = rep("A", 4), TAX_YEAR = 2020:2023, x = 1:4)
  equal <- panel_smooth(data, "x", weights = "equal", verbose = FALSE)
  decay <- panel_smooth(data, "x", weights = "decay", verbose = FALSE)
  expect_equal(equal$x, c(2, 2, 3, 3))
  expect_false(identical(equal$x[1], decay$x[1]))
})

test_that("smoothing validates window and fields", {
  data <- data.frame(EIN2 = "A", TAX_YEAR = 2020, x = 1)
  expect_error(panel_smooth(data, "x", window = 2), "odd")
  expect_error(panel_smooth(data, "missing"), "not found")
})
