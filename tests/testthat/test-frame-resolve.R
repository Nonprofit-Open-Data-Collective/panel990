# A source whose header table states, per year, who filed and on which form.
#   EIN-...01  files 990EZ in all three years
#   EIN-...02  files 990   in all three years
#   EIN-...03  files 990EZ in 2021-2022, 990 in 2023 (mixed form)
#   EIN-...04  files only in 2021
make_require_source <- function(format = "csv") {
  root <- tempfile("require-source-")
  dir.create(root)
  filings <- list(
    "2021" = data.frame(n = 1:4, type = c("990EZ", "990", "990EZ", "990EZ")),
    "2022" = data.frame(n = 1:3, type = c("990EZ", "990", "990EZ")),
    "2023" = data.frame(n = 1:3, type = c("990EZ", "990", "990"))
  )
  for (year in names(filings)) {
    spec <- filings[[year]]
    header <- data.frame(
      EIN2 = sprintf("EIN-12-345678%02d", spec$n),
      OBJECTID = sprintf("O%s%02d", year, spec$n),
      TAX_YEAR = as.character(year),
      RETURN_TYPE = spec$type,
      stringsAsFactors = FALSE
    )
    summary <- data.frame(
      EIN2 = header$EIN2, OBJECTID = header$OBJECTID,
      TAX_YEAR = header$TAX_YEAR,
      F9_01_REV_TOT_CY = as.character(spec$n * 1000L),
      stringsAsFactors = FALSE
    )
    for (item in list(list("F9-P00-T00-HEADER", header),
                      list("F9-P01-T00-SUMMARY", summary))) {
      file <- file.path(root, .efile_filename(item[[1L]], year, format))
      if (format == "parquet") arrow::write_parquet(item[[2L]], file)
      else utils::write.csv(item[[2L]], file, row.names = FALSE)
    }
  }
  root
}

test_that("a require rule is declarative and validates its payload", {
  frame <- create_sfw("balanced")
  frame <- add_rule(frame, "balanced", type = "require", present_in = "all")
  rules <- get_rules(frame)
  expect_equal(rules$type, "require")
  expect_true(rules$active)
  expect_match(rules$detail, "present in all")
  # The default table is the header, where presence is recorded.
  expect_equal(Filter(function(r) r$type == "require", frame$rules)[[1L]]$table,
               "P00")

  # An expr string cannot be pushed to the source, so it is refused up front
  # rather than silently ignored at resolve time.
  expect_error(add_rule(frame, type = "require", expr = "TAX_YEAR > 2020"),
               "cannot be pushed to the source")
  expect_error(add_rule(frame, type = "require", present_in = "most"),
               "must be \"all\", \"any\", or a minimum year count")
  expect_error(add_rule(frame, type = "require", present_in = 0),
               "must be \"all\", \"any\", or a minimum year count")
  expect_error(add_rule(frame, type = "require", column = "RETURN_TYPE",
                        op = "in", values = "990", holds = "sometimes"),
               "must be \"every\"")
})

test_that("present_in resolves balanced, minimum-count, and any frames", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_require_source()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  source <- data_source(root, format = "csv")
  ids_of <- function(frame) {
    subset <- Filter(function(r) identical(r$type, "subset"), frame$rules)
    sort(subset[[1L]]$ids)
  }
  resolve <- function(present_in) {
    frame <- add_rule(create_sfw("f"), type = "require",
                      present_in = present_in)
    ids_of(resolve_frame(frame, 2021:2023, source, verbose = FALSE))
  }

  # Only 01-03 appear in all three years; 04 files once.
  expect_equal(resolve("all"),
               sprintf("EIN-12-345678%02d", 1:3))
  expect_equal(resolve(2L), sprintf("EIN-12-345678%02d", 1:3))
  expect_equal(resolve("any"), sprintf("EIN-12-345678%02d", 1:4))
  expect_equal(resolve(1L), sprintf("EIN-12-345678%02d", 1:4))
})

test_that("holds distinguishes 'every year' from 'any year'", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_require_source()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  source <- data_source(root, format = "csv")
  ids_of <- function(frame) {
    subset <- Filter(function(r) identical(r$type, "subset"), frame$rules)
    sort(subset[[1L]]$ids)
  }
  ez <- function(holds, present_in = "any") {
    frame <- add_rule(create_sfw("f"), type = "require",
                      present_in = present_in, column = "RETURN_TYPE",
                      op = "in", values = "990EZ", holds = holds)
    ids_of(resolve_frame(frame, 2021:2023, source, verbose = FALSE))
  }

  # 01 is 990EZ throughout; 03 switches to 990 in 2023; 04 files 990EZ once.
  expect_equal(ez("every"), c("EIN-12-34567801", "EIN-12-34567804"))
  expect_equal(ez("any"),
               c("EIN-12-34567801", "EIN-12-34567803", "EIN-12-34567804"))
  # Combining with a balanced requirement drops the single-year filer.
  expect_equal(ez("every", present_in = "all"), "EIN-12-34567801")
})

test_that("several require rules intersect and are recorded, not discarded", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_require_source()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  frame <- create_sfw("balanced 990EZ")
  frame <- add_rule(frame, "balanced", type = "require", present_in = "all")
  frame <- add_rule(frame, "always_ez", type = "require", present_in = "any",
                    column = "RETURN_TYPE", op = "in", values = "990EZ")
  resolved <- resolve_frame(frame, 2021:2023, data_source(root, format = "csv"),
                            verbose = FALSE)

  rules <- get_rules(resolved)
  # The requirements survive as an inactive record of what produced the sample.
  expect_equal(rules$type, c("require", "require", "subset"))
  expect_equal(rules$active, c(FALSE, FALSE, TRUE))
  expect_equal(rules$detail[[3L]], "1 ids")

  # Every requirement leaves a receipt, plus one for the intersection.
  log <- manifest(resolved)
  expect_true(all(c("require: balanced", "require: always_ez",
                    "resolve_frame") %in% log$step))
  expect_equal(log$rows_after[log$step == "require: balanced"], 3)
  expect_equal(log$rows_after[log$step == "resolve_frame"], 1)
})

test_that("resolution is a no-op without an active require rule", {
  frame <- create_sfw("plain")
  expect_message(out <- resolve_frame(frame, 2021:2023), "no active")
  expect_equal(get_rules(out), get_rules(frame))
})

test_that("resolution needs entity and time keys and a real column", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_require_source()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  keyless <- add_rule(create_sfw("f", time = NULL), type = "require")
  expect_error(resolve_frame(keyless, 2021:2023, data_source(root, format = "csv"),
                             verbose = FALSE),
               "needs both an entity and a time key")

  absent <- add_rule(create_sfw("f"), type = "require", column = "NOPE",
                     op = "in", values = "1")
  expect_error(resolve_frame(absent, 2021:2023, data_source(root, format = "csv"),
                             verbose = FALSE),
               "column not found")

  expect_error(resolve_frame(add_rule(create_sfw("f"), type = "require"),
                             years = character(), data_source(root, format = "csv")),
               "must be a non-empty numeric vector")
})

test_that("panelize resolves a require rule and pushes the result down", {
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- make_require_source()
  on.exit(unlink(root, recursive = TRUE), add = TRUE)

  frame <- create_sfw("balanced 990EZ", record = "OBJECTID")
  frame <- add_rule(frame, "balanced", type = "require", present_in = "all",
                    column = "RETURN_TYPE", op = "in", values = "990EZ")
  panel <- panelize(frame, tables = c("P00", "P01"), years = 2021:2023,
                    source = data_source(root, format = "csv"), backend = "duckdb",
                    cache = "none", bmf = FALSE, verbose = FALSE)

  data <- panel_data(panel)
  # Only 01 is a 990EZ filer in all three years.
  expect_equal(unique(data$EIN2), "EIN-12-34567801")
  expect_equal(nrow(data), 3L)
  # The read was narrowed rather than the panel filtered afterwards: the
  # restriction reached the scan, so no other entity was ever materialized.
  expect_true(all(panel$table_manifest$rows_selected == 1L))
  expect_true("require: balanced" %in% manifest(panel)$step)
})

test_that("a require rule guarantees year coverage, not one row per year", {
  # An amended return is a second filing for the same tax year, so presence in
  # every year does not imply one row per year; that is what a dedup rule is
  # for. Regression guard on the division of labour between the two.
  skip_if_not_installed("DBI")
  skip_if_not_installed("duckdb")
  root <- tempfile("amended-source-")
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  for (year in 2021:2023) {
    amended <- year == 2022
    header <- data.frame(
      EIN2 = "EIN-12-34567801",
      OBJECTID = paste0("O", year, if (amended) 1:2 else 1),
      TAX_YEAR = year,
      RETURN_TYPE = "990EZ",
      RETURN_AMENDED_X = if (amended) c("", "X") else "",
      RETURN_TIME_STAMP = paste0(year, "-05-0", if (amended) 1:2 else 1),
      stringsAsFactors = FALSE
    )
    utils::write.csv(header,
      file.path(root, paste0("F9-P00-T00-HEADER-", year, ".CSV")),
      row.names = FALSE)
  }
  frame <- create_sfw("balanced", record = "OBJECTID")
  frame <- add_rule(frame, type = "require", present_in = "all")
  args <- list(tables = "P00", years = 2021:2023, source = data_source(root, format = "csv"),
               backend = "duckdb", cache = "none", bmf = FALSE, verbose = FALSE)

  expect_equal(nrow(panel_data(do.call(panelize,
    c(list(frame), args)))), 4L)
  expect_equal(nrow(panel_data(do.call(panelize,
    c(list(add_rule(frame, type = "dedup")), args)))), 3L)
})
