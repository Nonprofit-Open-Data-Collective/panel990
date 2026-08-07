make_panel_fixture <- function() {
  data.frame(
    ORG = c(rep("A", 5), rep("B", 3), rep("C", 3), rep("D", 2)),
    YEAR = c(2019:2023, 2021:2023, 2019:2021, c(2019, 2023)),
    value = seq_len(13),
    stringsAsFactors = FALSE
  )
}

test_that("panel classification separates boundary and spell dimensions", {
  out <- panel_describe(
    make_panel_fixture(), time = "YEAR", id = "ORG", print_table = FALSE
  )
  cls <- attr(out, "classification")

  expect_equal(cls$panel_type[cls$ORG == "A"], "full")
  expect_equal(cls$panel_type[cls$ORG == "B"], "entry")
  expect_equal(cls$panel_type[cls$ORG == "C"], "exit")
  expect_equal(cls$panel_type[cls$ORG == "D"], "full")
  expect_equal(cls$panel_spell_balance[cls$ORG == "D"], "fragmented")
  expect_equal(cls$panel_gap_count[cls$ORG == "D"], 1L)
  expect_equal(cls$panel_gap_size_max[cls$ORG == "D"], 3L)
})

test_that("panel classification appends without changing row order", {
  data <- make_panel_fixture()
  out <- panel_describe(
    data, time = "YEAR", id = "ORG", append_classification = TRUE,
    print_table = FALSE
  )

  expect_equal(nrow(out), nrow(data))
  expect_equal(out$value, data$value)
  expect_true(all(c("panel_type", "panel_spell_balance") %in% names(out)))
})

test_that("panel filtering combines type and spell filters", {
  data <- make_panel_fixture()
  summary <- panel_describe(
    data, time = "YEAR", id = "ORG", print_table = FALSE
  )

  fragmented <- panel_filter(
    data, summary, spell_balance = "fragmented", id = "ORG"
  )
  entry_exit <- panel_filter(
    data, summary, keep = c("entry", "exit"), id = "ORG"
  )

  expect_setequal(unique(fragmented$ORG), "D")
  expect_setequal(unique(entry_exit$ORG), c("B", "C"))
})
