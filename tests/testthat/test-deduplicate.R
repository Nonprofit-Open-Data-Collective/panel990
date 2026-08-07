make_duplicate_filings <- function() data.frame(
  EIN2 = c("A", "A", "A", "B", "B"),
  TAX_YEAR = 2021,
  RETURN_GROUP_X = c("", "", "", "X", "X"),
  RETURN_PARTIAL_X = c("X", "", "", "", ""),
  RETURN_AMENDED_X = c("", "", "X", "", ""),
  RETURN_TIME_STAMP = c("2022-01-01", "2022-06-01", "2022-09-01",
                        "2022-03-01", "2022-04-01"),
  value = 1:5,
  stringsAsFactors = FALSE
)

test_that("deduplication applies filing preferences in order", {
  out <- deduplicate(make_duplicate_filings(), verbose = FALSE)
  expect_equal(nrow(out), 2L)
  expect_equal(out$value[out$EIN2 == "A"], 3L)
  expect_equal(out$value[out$EIN2 == "B"], 5L)
})

test_that("deduplication accepts date and datetime timestamps", {
  data <- data.frame(
    ORG = c("A", "A", "B", "B"), YEAR = 2021,
    STAMP = c("2022-01-01", "2022-12-31", "2022-01-01 08:00:00",
              "2022-01-01T09:00:00"), value = 1:4
  )
  out <- deduplicate(
    data, id = "ORG", year = "YEAR", group = "NONE", partial = "NONE",
    amended = NULL, timestamp = "STAMP", verbose = FALSE
  )
  expect_equal(out$value, c(2L, 4L))
})

test_that("deduplication validates key fields", {
  expect_error(deduplicate(data.frame(x = 1)), "ID column")
  expect_error(deduplicate(data.frame(EIN2 = "A")), "Year column")
})
