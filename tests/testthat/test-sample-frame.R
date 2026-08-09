make_sfw_df <- function() data.frame(
  EIN2 = c("A", "A", "A", "B", "B", "C"),
  TAX_YEAR = c(2019, 2020, 2021, 2020, 2021, 2020),
  RETURN_TYPE = c("990", "990", "990EZ", "990", "990", "990EZ"),
  geo_state_abbr = c("GA", "GA", "GA", "FL", "FL", "GA"),
  F9_01_REV_TOT_CY = c(10, 20, 30, 40, 50, 60),
  my_custom = 1:6,
  stringsAsFactors = FALSE
)

test_that("create_sfw registers default keys and add_key adds a record key", {
  expect_error(create_sfw(), "name")
  sfw <- create_sfw("test")
  expect_s3_class(sfw, "sfw")
  keys <- get_keys(sfw)
  expect_setequal(keys$type, c("entity", "time"))
  sfw <- add_key(sfw, "object id", "unique_record", "OBJECTID")
  expect_true("unique_record" %in% get_keys(sfw)$type)
})

test_that("sugar and structured filters both add filter rules", {
  sfw <- create_sfw("t", state = "GA", years = 2020:2021)
  sfw <- add_rule(sfw, "form", "filter", column = "RETURN_TYPE", values = "990")
  r <- get_rules(sfw)
  expect_true(all(c("filter", "filter", "filter") == r$type[r$type == "filter"]))
  expect_equal(sum(r$type == "filter"), 3L)
})

test_that("add_rule upserts by name; update_rule edits and drops", {
  sfw <- create_sfw("t")
  sfw <- add_rule(sfw, "st", "filter", column = "geo_state_abbr", values = "GA")
  sfw <- add_rule(sfw, "st", "filter", column = "geo_state_abbr", values = "FL")
  expect_equal(nrow(get_rules(sfw)), 1L)            # upsert by name
  sfw <- update_rule(sfw, "st", values = c("GA", "FL"))
  expect_match(get_rules(sfw)$detail, "GA,FL")
  sfw <- update_rule(sfw, "st", drop = TRUE)
  expect_equal(nrow(get_rules(sfw)), 0L)
})

test_that("apply_sfw runs subset then filter, origin never required", {
  df <- make_sfw_df()
  sfw <- create_sfw("t", state = "GA")
  sfw <- add_rule(sfw, "study", "subset", subset = c("A", "C"))
  out <- apply_sfw(df, sfw, verbose = FALSE)
  expect_setequal(unique(out$EIN2), c("A", "C"))
  expect_true(!is.null(attr(out, "sfw_steps")))
})

test_that("between and expr filter rules work", {
  df <- make_sfw_df()
  sfw <- add_rule(create_sfw("t"), "yr", "filter", column = "TAX_YEAR",
                  op = "between", values = c(2020, 2021))
  expect_setequal(unique(apply_sfw(df, sfw, verbose = FALSE)$TAX_YEAR), c(2020, 2021))

  sfw2 <- add_rule(create_sfw("t"), "rev", "filter",
                   expr = "F9_01_REV_TOT_CY > 25")
  expect_equal(nrow(apply_sfw(df, sfw2, verbose = FALSE)), 4L)
})

test_that("missing filter columns are skipped, not errors", {
  sfw <- add_rule(create_sfw("t"), "x", "filter", column = "NOPE", values = "z")
  expect_silent(out <- apply_sfw(make_sfw_df(), sfw, verbose = FALSE))
  expect_equal(nrow(out), 6L)
})

test_that("label rules from a source are filterable", {
  df <- make_sfw_df()
  lut <- data.frame(EIN2 = c("A", "B", "C"),
                    cohort = c("treat", "ctrl", "treat"), stringsAsFactors = FALSE)
  sfw <- add_rule(create_sfw("t"), "cohorts", "label",
                  from = lut, keys = "EIN2", label = "cohort")
  out <- apply_sfw(df, sfw, cohort = "treat", verbose = FALSE)
  expect_setequal(unique(out$EIN2), c("A", "C"))
})

test_that("classify_panel adds panel labels filterable by apply_sfw", {
  df <- make_sfw_df()
  sfw <- classify_panel(create_sfw("t"), df)
  expect_true(all(c("panel_type", "panel_spell") %in% get_rules(sfw)$name))
  persistent <- apply_sfw(df, sfw, panel_type = "persistent", verbose = FALSE)
  expect_setequal(unique(persistent$EIN2), "A")     # A spans 2019-2021
})

test_that("select rule keeps header/custom, drops out-of-scope dict vars", {
  data("field_concordance", package = "panel990")
  pc_var <- field_concordance$variable_name[field_concordance$variable_scope == "PC"][1]
  df <- make_sfw_df(); df[[pc_var]] <- 1:6

  sfw <- add_rule(create_sfw("t"), "cols", "select", scope = "both")
  out <- apply_sfw(df, sfw, verbose = FALSE)
  expect_false(pc_var %in% names(out))
  expect_true("F9_01_REV_TOT_CY" %in% names(out))
  expect_true(all(c("EIN2", "TAX_YEAR", "my_custom") %in% names(out)))
})

test_that("check rules report without filtering; conform verifies", {
  df <- make_sfw_df()
  sfw <- add_rule(create_sfw("t", state = "GA"), "ga_only", "check",
                  column = "geo_state_abbr", values = "GA")
  out <- apply_sfw(df, sfw, verbose = FALSE)
  chk <- attr(out, "sfw_checks")
  # apply_sfw filtered to GA (the filter), so the check passes on the result
  expect_true(chk$ok[chk$check == "ga_only"])

  res <- conform(df, sfw, verbose = FALSE)   # raw df has FL rows -> nonconforming
  expect_false(res$conformant)
  expect_equal(res$rows_violating, 2L)
})

test_that("refresh droplevels prunes factor levels after row filters", {
  df <- data.frame(EIN2 = c("A", "B", "C"), TAX_YEAR = 2020,
                   grp = factor(c("x", "y", "z")), stringsAsFactors = FALSE)
  sfw <- add_rule(create_sfw("t"), "keep", "subset", subset = c("A", "B"))
  sfw <- add_refresh(sfw, "relevel", action = "droplevels")
  out <- apply_sfw(df, sfw, verbose = FALSE)
  expect_equal(nrow(out), 2L)
  expect_setequal(levels(out$grp), c("x", "y"))     # z dropped
})

test_that("refresh group_stat recomputes on the surviving rows", {
  df <- data.frame(EIN2 = c("A", "A", "B"), TAX_YEAR = c(2020, 2021, 2020),
                   rev = c(10, 30, 50), keep = c(TRUE, TRUE, FALSE))
  sfw <- add_rule(create_sfw("t"), "pos", "filter", column = "keep", op = "is_true")
  sfw <- add_refresh(sfw, "avg", action = "group_stat", by = "EIN2",
                     value = "rev", fun = "mean", into = "rev_mean")
  out <- apply_sfw(df, sfw, verbose = FALSE)
  expect_equal(nrow(out), 2L)                        # B dropped
  expect_equal(unique(out$rev_mean), 20)             # mean of A's 10, 30
})

test_that("views compute crosstabs and tapply summaries", {
  df <- data.frame(EIN2 = c("A", "B", "C", "D"), TAX_YEAR = 2020,
                   state = c("GA", "GA", "FL", "FL"), rev = c(1, 2, 3, 4),
                   stringsAsFactors = FALSE)
  sfw <- add_view(create_sfw("t"), "by_state", rows = "state")
  sfw <- add_view(sfw, "rev_by_state", rows = "state", value = "rev", fun = "sum")

  vs <- views(df, sfw, verbose = FALSE)
  expect_equal(as.integer(vs$by_state[c("GA", "FL")]), c(2L, 2L))
  expect_equal(as.numeric(vs$rev_by_state[c("GA", "FL")]), c(3, 7))

  out <- apply_sfw(df, sfw, verbose = FALSE)          # also attached by apply_sfw
  expect_false(is.null(attr(out, "sfw_views")$by_state))
})

test_that("dedup rule collapses to one row per entity-year", {
  df <- data.frame(
    EIN2 = c("A", "A", "B"), TAX_YEAR = c(2020, 2020, 2020),
    RETURN_TIME_STAMP = c("2021-01-01", "2021-06-01", "2021-01-01"),
    v = 1:3, stringsAsFactors = FALSE)
  sfw <- add_rule(create_sfw("t"), "dd", "dedup")
  out <- apply_sfw(df, sfw, verbose = FALSE)
  expect_equal(nrow(out), 2L)                       # A collapsed to latest
})
