test_that("financial_fields: core is a subset of all and hits the core tables", {
  core <- financial_fields("core")
  all  <- financial_fields("all")
  expect_true(length(core) > 0L)
  expect_true(all(core %in% all))
  expect_true(length(all) > length(core))
  expect_true("F9_01_REV_TOT_CY" %in% core)          # P01 summary
  expect_true("F9_08_REV_TOT_TOT" %in% core)         # P08 revenue
})

test_that("panel_normalize zeros in scope, masks EZ, and guards non-filers", {
  df <- data.frame(
    EIN2 = c("A", "B", "C"), TAX_YEAR = 2020,
    RETURN_TYPE = c("990", "990EZ", "990"),
    F9_01_REV_TOT_CY  = c(100, 50, NA),   # PZ (both forms)
    F9_08_REV_TOT_TOT = c(NA,  NA, NA),   # PC (full 990 only)
    stringsAsFactors = FALSE
  )
  out <- panel_normalize(df, verbose = FALSE)

  expect_equal(out$F9_08_REV_TOT_TOT[1], 0)          # A: 990, in scope -> 0
  expect_true(is.na(out$F9_08_REV_TOT_TOT[2]))       # B: 990EZ, out of scope -> NA
  expect_true(is.na(out$F9_08_REV_TOT_TOT[3]))       # C: no financial data -> untouched
  expect_true(is.na(out$F9_01_REV_TOT_CY[3]))        # C guarded on PZ field too
  expect_equal(out$F9_01_REV_TOT_CY[1:2], c(100, 50))# present values unchanged

  aud <- attr(out, "normalize_audit")
  expect_equal(aud$all_missing_rows, 1L)
  expect_equal(aud$ez_rows, 1L)
})

test_that("panel_normalize runs on a panel and logs a receipt", {
  df <- data.frame(EIN2 = "A", TAX_YEAR = 2020, RETURN_TYPE = "990",
                   F9_01_REV_TOT_CY = 100, F9_08_REV_TOT_TOT = NA,
                   stringsAsFactors = FALSE)
  p <- as_panel(df) |> panel_describe(print = FALSE) |> panel_normalize(verbose = FALSE)
  expect_true(is_panel(p))
  expect_equal(as.data.frame(p)$F9_08_REV_TOT_TOT, 0)
  expect_true("panel_normalize" %in% manifest(p)$step)
  expect_true(p$fresh)                               # normalization did not stale labels
})
