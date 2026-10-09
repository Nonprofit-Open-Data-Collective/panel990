# A local mirror of the 990PF release: the shared header plus Parts I and II,
# carrying the same table names the 990 release uses for its header.
make_pf_source <- function() {
  root <- tempfile("pf-source-")
  dir.create(root)
  for (year in 2021:2022) {
    header <- data.frame(
      EIN2 = c("EIN-11-1111111", "EIN-22-2222222"),
      OBJECTID = paste0("PF", year, c("A", "B")),
      RETURN_TYPE = "990PF", ORG_NAME_L1 = c("Gamma Fdn", "Delta Fdn"),
      stringsAsFactors = FALSE
    )
    part1 <- data.frame(
      EIN2 = header$EIN2, OBJECTID = header$OBJECTID, RETURN_TYPE = "990PF",
      PF_01_REV_CONTR_REC_BOOKS = c(100, NA),
      PF_01_REV_TOT_BOOKS = c(100, 50) + year,
      stringsAsFactors = FALSE
    )
    utils::write.csv(header, file.path(root, paste0("F9-P00-T00-HEADER-", year, ".CSV")),
                     row.names = FALSE)
    utils::write.csv(part1, file.path(root, paste0("PF-P01-T00-REVENUE-EXPENSE-", year, ".CSV")),
                     row.names = FALSE)
  }
  root
}

test_that("data_source() selects the 990PF release by form", {
  pf <- data_source(form = "990PF")
  expect_identical(pf$form, "990PF")
  expect_match(pf$root, "/efilepf_v3_1/$")
  expect_identical(unname(pf$aliases[["PF01"]]), "PF-P01-T00-REVENUE-EXPENSE")
  expect_identical(unname(pf$aliases[["P00"]]), "F9-P00-T00-HEADER")

  f9 <- data_source()
  expect_identical(f9$form, "990")
  expect_match(f9$root, "/efile_v3_1/$")
  expect_false("PF01" %in% names(f9$aliases))

  expect_identical(data_source(form = "pf")$form, "990PF")
  expect_identical(data_source(form = "990-PF")$form, "990PF")
  expect_match(data_source(version = "efilepf_v2_2", form = "990PF")$root,
               "/efilepf_v2_2/$")
  expect_error(data_source(form = "990EZ"), "published with full 990 filers")
  expect_error(data_source(form = "1040"), "must be one of")
})

test_that("table_catalog() lists each release's tables", {
  pf <- table_catalog(form = "990PF")
  expect_equal(nrow(pf), 84L)
  expect_true(all(startsWith(pf$table, "PF-") |
                    pf$table %in% c("F9-P00-T00-HEADER", "F9-P02-T00-SIGNATURE") |
                    startsWith(pf$table, "SB-")))
  expect_identical(pf$alias[pf$table == "PF-P02-T00-BALANCE-SHEET"], "PF02")
  expect_identical(pf$cardinality[pf$table == "PF-P99-T00-AUXILLIARY"], "1x1")
  expect_identical(pf$cardinality[pf$table == "PF-P99-T01-ACC-FEES"], "1xm")
  expect_false(any(startsWith(table_catalog()$table, "PF-")))
})

test_that("resolve_tables() rejects tables from the other release", {
  expect_error(resolve_tables("PF01", data_source()), "panelize_pf")
  expect_error(resolve_tables("PF-P01-T00-REVENUE-EXPENSE", data_source()),
               "990PF tables requested")
  expect_error(resolve_tables("P08", data_source(form = "990PF")),
               "Not published in the 990PF release")
  ok <- resolve_tables(c("P00", "PF01", "PF-P99-T60-FUTURE"),
                       data_source(form = "990PF"))
  expect_identical(ok$table, c("F9-P00-T00-HEADER", "PF-P01-T00-REVENUE-EXPENSE",
                               "PF-P99-T60-FUTURE"))
  expect_identical(ok$known, c(TRUE, TRUE, FALSE))
})

test_that("990PF downloads are cached apart from the 990 release", {
  root <- make_pf_source()
  cache <- tempfile("pf-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  pf <- download_tables(2021, c("P00", "PF01"),
                        data_source(root, format = "csv", form = "990PF"),
                        path = cache, verbose = FALSE)
  expect_true(all(file.exists(file.path(cache, "990PF", "2021",
    c("F9-P00-T00-HEADER-2021.CSV", "PF-P01-T00-REVENUE-EXPENSE-2021.CSV")))))
  expect_false(file.exists(file.path(cache, "2021", "F9-P00-T00-HEADER-2021.CSV")))

  # The 990 layout is unchanged, so the same header name lands elsewhere.
  f9 <- download_tables(2021, "P00", data_source(root, format = "csv"),
                        path = cache, verbose = FALSE)
  expect_true(file.exists(file.path(cache, "2021", "F9-P00-T00-HEADER-2021.CSV")))
  expect_identical(f9$manifest$status, "downloaded")
})

test_that("the 990PF concordance is bundled and form-aware", {
  pf <- field_concordance_pf
  expect_true(all(pf$variable_scope %in% c("PF", "HD", "SG")))
  expect_true(all(pf$forms[pf$variable_scope == "PF"] == "990PF"))
  expect_false(anyDuplicated(pf$variable_name) > 0L)
  expect_false(any(startsWith(field_concordance$rdb_table, "PF-")))

  cc <- concordance(form = "990PF")
  expect_s3_class(cc, "concordance")
  expect_true("PF_01_REV_TOT_BOOKS" %in% cc$field)
  expect_false("F9_08_REV_TOT_TOT" %in% cc$field)
  expect_setequal(fields_in_scope("990PF"), pf$variable_name)

  # One type lookup serves both releases.
  types <- panel990:::.p990_efile_types(
    c("PF_01_REV_TOT_BOOKS", "F9_08_REV_TOT_TOT", "PF_02_NAFB_FOLLOW_SFAS117_X"))
  expect_identical(unname(types[c("PF_01_REV_TOT_BOOKS", "F9_08_REV_TOT_TOT")]),
                   c("numeric", "numeric"))
  expect_identical(unname(types[["PF_02_NAFB_FOLLOW_SFAS117_X"]]), "checkbox")
})

test_that("financial_fields() returns the 990PF financial statements", {
  core <- financial_fields(form = "990PF")
  tables <- field_concordance_pf$rdb_table[match(core, field_concordance_pf$variable_name)]
  expect_true(all(grepl("^PF-P0[1-3]-", tables)))
  expect_true(all(c("PF_01_REV_TOT_BOOKS", "PF_02_ASSET_TOT_EOY_FMV",
                    "PF_03_NAFB_TOT_EOY") %in% core))
  expect_gt(length(financial_fields("all", form = "990PF")), length(core))
  expect_false(any(core %in% financial_fields()))
})

test_that("panel_normalize() zeroes 990PF blanks for 990PF filers only", {
  df <- data.frame(
    RETURN_TYPE = c("990PF", "990PF", "990PF"),
    PF_01_REV_TOT_BOOKS = c(10, NA, NA),
    PF_01_REV_CONTR_REC_BOOKS = c(NA, 5, NA),
    stringsAsFactors = FALSE
  )
  out <- panel_normalize(df, verbose = FALSE)
  expect_equal(out$PF_01_REV_TOT_BOOKS, c(10, 0, NA))     # all-missing row kept
  expect_equal(out$PF_01_REV_CONTR_REC_BOOKS, c(0, 5, NA))
  audit <- attr(out, "normalize_audit")
  expect_identical(audit$values_zeroed, 2L)
  expect_identical(audit$pf_rows, 3L)
  expect_identical(audit$all_missing_rows, 1L)

  # A 990 filer never has 990PF fields zeroed, and the reverse.
  mixed <- data.frame(RETURN_TYPE = c("990", "990PF"),
                      F9_08_REV_TOT_TOT = c(NA, NA), F9_01_REV_TOT_CY = c(1, NA),
                      PF_01_REV_TOT_BOOKS = c(NA, 7))
  m <- panel_normalize(mixed, verbose = FALSE)
  expect_equal(m$F9_08_REV_TOT_TOT, c(0, NA))
  expect_equal(m$PF_01_REV_TOT_BOOKS, c(NA, 7))
})

test_that("panel_normalize() reports how many values it zeroed", {
  df <- data.frame(RETURN_TYPE = "990", F9_08_REV_TOT_TOT = c(NA, 5),
                   F9_01_REV_TOT_CY = c(1, NA))
  out <- panel_normalize(df, verbose = FALSE)
  expect_identical(attr(out, "normalize_audit")$values_zeroed, 2L)
  expect_message(panel_normalize(df), "zeroed 2 blank")
})

test_that("accounting_check() evaluates 990PF identities on 990PF fields", {
  ids <- accounting_identities[accounting_identities$form_scope == "PF", ]
  expect_equal(length(unique(ids$identity)), 29L)
  expect_true(all(startsWith(ids$identity, "pf_")))

  df <- data.frame(EIN2 = c("A", "B"), TAX_YEAR = 2022L,
                   PF_02_ASSET_TOT_EOY_BV = c(100, 100),
                   PF_02_NAFB_TOT_LIAB_NAFB_EOY_BV = c(100, 90))
  report <- accounting_check(df, violations_only = FALSE)
  expect_identical(unique(report$identity), "pf_bs_balance_eoy")
  expect_identical(report$ok[report$EIN2 == "B"], FALSE)
  expect_equal(abs(report$residual[report$EIN2 == "B"]), 10)
})

test_that("panelize_pf() builds a 990PF panel from a mirror", {
  root <- make_pf_source()
  cache <- tempfile("pf-cache-")
  on.exit(unlink(c(root, cache), recursive = TRUE), add = TRUE)
  p <- panelize_pf(tables = c("P00", "PF01"), years = 2021:2022, root = root,
                   format = "csv", path = cache, bmf = FALSE, verbose = FALSE)
  expect_s3_class(p, "panel")
  expect_identical(p$source$form, "990PF")
  d <- panel_data(p)
  expect_equal(nrow(d), 4L)
  expect_true(all(c("ORG_NAME_L1", "PF_01_REV_TOT_BOOKS") %in% names(d)))
  expect_true(all(file.exists(file.path(cache, "990PF", c("2021", "2022")))))
})

test_that("panelize_pf() and panelize() guard the form family", {
  expect_error(panelize_pf(years = 2022, source = data_source()),
               "builds its own 990PF source")
  expect_error(panelize(tables = "PF01", years = 2022, cache = "temporary",
                        verbose = FALSE),
               "panelize_pf")

  frame <- add_rule(create_sfw("scoped"), type = "select", scope = "both")
  expect_error(panelize(frame, tables = "PF01", years = 2022,
                        source = data_source(form = "990PF"), verbose = FALSE),
               "does not apply to a 990PF panel")
  pf_frame <- add_rule(create_sfw("pf scope"), type = "select", scope = "990PF")
  expect_true(panel990:::.sfw_check_form_scope(pf_frame, "990PF"))
})

test_that("sample-frame selection recognizes 990PF tables and fields", {
  df <- data.frame(EIN2 = "A", TAX_YEAR = 2022L, RETURN_TYPE = "990PF",
                   PF_01_REV_TOT_BOOKS = 1, PF_02_ASSET_TOT_EOY_BV = 2,
                   stringsAsFactors = FALSE)
  frame <- add_rule(create_sfw("pf part I"), type = "select", tables = "PF01")
  out <- apply_sfw(df, frame, verbose = FALSE)
  expect_true("PF_01_REV_TOT_BOOKS" %in% names(out))
  expect_false("PF_02_ASSET_TOT_EOY_BV" %in% names(out))
})
