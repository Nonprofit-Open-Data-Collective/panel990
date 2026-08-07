test_that("field_concordance dataset is well-formed", {
  data("field_concordance", package = "panel990")
  req <- c("variable_name", "variable_scope", "data_type_simple", "money_field",
           "blank_meaning", "forms", "rdb_table", "rdb_relationship")
  expect_true(all(req %in% names(field_concordance)))
  expect_equal(anyDuplicated(field_concordance$variable_name), 0L)
  expect_true(all(field_concordance$blank_meaning %in%
                    c("implicit_zero", "implicit_false", "literal_missing")))
})

test_that("built-in concordance() returns the bundled 990 rules", {
  cc <- concordance()
  expect_s3_class(cc, "concordance")
  expect_true(is.list(cc$forms))
  expect_true("F9_01_REV_TOT_CY" %in% cc$field)
  expect_equal(cc$blank_meaning[cc$field == "F9_01_REV_TOT_CY"], "implicit_zero")
  expect_equal(cc$blank_meaning[cc$field == "F9_00_ORG_EIN"], "literal_missing")
})

test_that("concordance() still builds custom rules", {
  cc <- concordance("x", "implicit_zero", forms = "990")
  expect_s3_class(cc, "concordance")
  expect_equal(cc$field, "x")
  expect_identical(cc$forms[[1]], "990")
  expect_error(concordance("x", "bogus"), "blank_meaning")
})

test_that("fields_in_scope selects by form presence", {
  both <- fields_in_scope("both")
  full <- fields_in_scope("990")
  ez   <- fields_in_scope("990EZ")

  expect_true(length(both) < length(full))
  expect_true(all(both %in% full))   # both-forms fields are on the full 990
  expect_true(all(both %in% ez))     # ... and on the 990EZ

  data("field_concordance", package = "panel990")
  pc_only <- field_concordance$variable_name[
    field_concordance$variable_scope == "PC"][1]
  expect_true(pc_only %in% full)
  expect_false(pc_only %in% both)
  expect_false(pc_only %in% ez)
})

test_that("built-in concordance normalizes only within form scope", {
  data("field_concordance", package = "panel990")
  f <- field_concordance$variable_name[
    field_concordance$variable_scope == "PC" &
      field_concordance$blank_meaning == "implicit_zero"][1]

  df <- data.frame(RETURN_TYPE = c("990", "990EZ"), stringsAsFactors = FALSE)
  df[[f]] <- c(NA_real_, NA_real_)

  out <- normalize(df, concordance())
  expect_equal(out[[f]][1], 0)        # in scope on the full 990 -> 0
  expect_true(is.na(out[[f]][2]))     # out of scope on the 990EZ -> unchanged
})
