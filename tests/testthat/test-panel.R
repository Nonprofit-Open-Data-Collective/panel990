make_panel_fixture <- function() {
  data.frame(
    ORG = c(rep("A", 5), rep("B", 3), rep("C", 3), rep("D", 2)),
    YEAR = c(2019:2023, 2021:2023, 2019:2021, c(2019, 2023)),
    value = seq_len(13),
    stringsAsFactors = FALSE
  )
}

test_that("panel_describe classifies on two axes", {
  out <- panel_describe(make_panel_fixture(), time = "YEAR", id = "ORG",
                        print = FALSE)
  expect_s3_class(out, "panel_summary")
  cls <- attr(out, "classification")

  # boundary axis
  expect_equal(cls$panel_type[cls$ORG == "A"], "persistent")  # 2019-2023
  expect_equal(cls$panel_type[cls$ORG == "B"], "entrant")     # 2021-2023
  expect_equal(cls$panel_type[cls$ORG == "C"], "exit")        # 2019-2021
  expect_equal(cls$panel_type[cls$ORG == "D"], "persistent")  # 2019 & 2023
  # spell axis
  expect_equal(cls$panel_spell[cls$ORG == "A"], "seamless")
  expect_equal(cls$panel_spell[cls$ORG == "D"], "segmented")
  expect_equal(cls$panel_gap_count[cls$ORG == "D"], 1L)
  expect_equal(cls$panel_gap_size_max[cls$ORG == "D"], 3L)
})

test_that("panel_label appends both axes without changing row order", {
  data <- make_panel_fixture()
  out <- panel_label(data, time = "YEAR", id = "ORG")

  expect_equal(nrow(out), nrow(data))
  expect_equal(out$value, data$value)
  expect_true(all(c("panel_type", "panel_spell") %in% names(out)))
  expect_equal(out$panel_type[out$ORG == "A"][1], "persistent")
})

test_that("panel_filter selects by type and spell, auto-classifying", {
  data <- make_panel_fixture()

  segmented <- panel_filter(data, spell = "segmented", time = "YEAR", id = "ORG")
  entry_exit <- panel_filter(data, panel_type = c("entrant", "exit"),
                             time = "YEAR", id = "ORG")
  # "balanced" set = persistent + seamless
  balanced <- panel_filter(data, panel_type = "persistent", spell = "seamless",
                           time = "YEAR", id = "ORG")

  expect_setequal(unique(segmented$ORG), "D")
  expect_setequal(unique(entry_exit$ORG), c("B", "C"))
  expect_setequal(unique(balanced$ORG), "A")            # D is persistent but segmented
})

test_that("panel_filter accepts a precomputed classification and min_obs", {
  data <- make_panel_fixture()
  summary <- panel_describe(data, time = "YEAR", id = "ORG", print = FALSE)

  persistent <- panel_filter(data, panel_type = "persistent",
                             classification = summary, time = "YEAR", id = "ORG")
  expect_setequal(unique(persistent$ORG), c("A", "D"))  # both touch first & last

  big <- panel_filter(data, min_obs = 3, time = "YEAR", id = "ORG")
  expect_setequal(unique(big$ORG), c("A", "B", "C"))    # D has only 2 obs
})
