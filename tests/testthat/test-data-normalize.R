test_that("financial blanks normalize only within form scope", {
  data <- data.frame(
    RETURN_TYPE = c("990", "990EZ", "990", "990EZ"),
    full_expense = c(NA, NA, 10, NA),
    shared_revenue = c(NA, NA, 20, 30),
    stringsAsFactors = FALSE
  )
  rules <- concordance(
    field = c("full_expense", "shared_revenue"),
    blank_meaning = "implicit_zero",
    forms = list("990", c("990", "990EZ"))
  )

  out <- normalize(data, rules)

  expect_equal(out$full_expense[c(1, 3)], c(0, 10))
  expect_true(is.na(out$full_expense[2]))
  expect_true(is.na(out$full_expense[4]))
  expect_equal(out$shared_revenue, c(0, 0, 20, 30))
})

test_that("checkbox blanks normalize to false only within scope", {
  data <- data.frame(
    RETURN_TYPE = c("990", "990", "990EZ"),
    checkbox = c("", "X", ""),
    stringsAsFactors = FALSE
  )
  rules <- concordance(
    "checkbox", "implicit_false", forms = "990"
  )

  out <- normalize(data, rules)

  expect_identical(out$checkbox, c(FALSE, TRUE, NA))
})

test_that("literal missing rules do not alter source values", {
  data <- data.frame(
    RETURN_TYPE = c("990", "990EZ"),
    narrative = c("", NA_character_),
    stringsAsFactors = FALSE
  )
  rules <- concordance("narrative", "literal_missing", forms = "*")

  out <- normalize(data, rules)

  expect_identical(out$narrative, data$narrative)
})

test_that("normalization audit distinguishes scope and changes", {
  data <- data.frame(
    RETURN_TYPE = c("990", "990EZ"),
    amount = c(NA_real_, NA_real_)
  )
  rules <- concordance("amount", "implicit_zero", forms = "990")

  out <- normalize(data, rules)
  audit <- attr(out, "normalization_audit")

  expect_equal(audit$applicable_rows, 1L)
  expect_equal(audit$applicable_blanks, 1L)
  expect_equal(audit$values_normalized, 1L)
  expect_equal(audit$out_of_scope_blanks, 1L)
})

test_that("missing concordance fields are audited or rejected", {
  data <- data.frame(RETURN_TYPE = "990")
  rules <- concordance("missing_field", "implicit_zero", forms = "990")

  out <- normalize(data, rules)
  expect_false(attr(out, "normalization_audit")$field_present)
  expect_error(
    normalize(data, rules, strict = TRUE),
    regexp = "missing_field"
  )
})
