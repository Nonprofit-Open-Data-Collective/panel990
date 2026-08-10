make_revenue_row <- function() data.frame(
  EIN2 = "A", TAX_YEAR = 2020,
  # contributions (line 1): components sum to CONTR_TOT = 500
  F9_08_REV_CONTR_FED_CAMP = 100, F9_08_REV_CONTR_MEMBSHIP_DUE = 50,
  F9_08_REV_CONTR_FUNDR_EVNT = 30, F9_08_REV_CONTR_RLTD_ORG = 20,
  F9_08_REV_CONTR_GOVT_GRANT = 200, F9_08_REV_CONTR_OTH = 100,
  F9_08_REV_CONTR_TOT = 500,
  # investment income columns: 10 + 5 + 35 = 50
  F9_08_REV_OTH_INVEST_INCOME_RLTD = 10, F9_08_REV_OTH_INVEST_INCOME_UBIZ = 5,
  F9_08_REV_OTH_INVEST_INCOME_EXCL = 35, F9_08_REV_OTH_INVEST_INCOME_TOT = 50,
  # gaming net: 25 - 10 = 15
  F9_08_REV_OTH_GAMING = 25, F9_08_REV_OTH_GAMING_DIRECT_EXP = 10,
  F9_08_REV_OTH_GAMING_NET_TOT = 15,
  stringsAsFactors = FALSE
)

test_that("the identity registry is well-formed and validated", {
  data("accounting_identities", package = "panel990")
  data("field_concordance", package = "panel990")
  expect_true(all(c("identity", "variable", "coefficient", "type") %in%
                    names(accounting_identities)))
  expect_true(all(accounting_identities$variable %in%
                    field_concordance$variable_name))
  expect_gte(length(unique(accounting_identities$identity)), 20L)
})

test_that("accounting_check flags exactly the broken identities", {
  row <- make_revenue_row()
  expect_equal(nrow(accounting_check(row)), 0L)         # consistent -> no violations

  bad <- row
  bad$F9_08_REV_CONTR_GOVT_GRANT <- 180                 # contributions off by 30
  bad$F9_08_REV_CONTR_OTH <- 90
  bad$F9_08_REV_OTH_INVEST_INCOME_EXCL <- 30            # investment off by 5
  v <- accounting_check(bad)
  expect_setequal(v$identity, c("rev_contributions_subtotal", "rev_invest_columns"))
  expect_equal(v$residual[v$identity == "rev_contributions_subtotal"], 30)
  expect_equal(v$residual[v$identity == "rev_invest_columns"], 5)
})

test_that("reconcile restores identities with minimal change, holding fixed", {
  bad <- make_revenue_row()
  bad$F9_08_REV_CONTR_GOVT_GRANT <- 180
  bad$F9_08_REV_CONTR_OTH <- 90
  bad$F9_08_REV_OTH_INVEST_INCOME_EXCL <- 30

  imputed <- c("F9_08_REV_CONTR_GOVT_GRANT", "F9_08_REV_CONTR_OTH",
               "F9_08_REV_OTH_INVEST_INCOME_EXCL")
  fixed <- setdiff(names(bad), c(imputed, "EIN2", "TAX_YEAR"))

  rec <- reconcile(bad, fixed = fixed)
  # 30 gap splits evenly over the two free contribution components; the single
  # free investment component absorbs its 5.
  expect_equal(rec$F9_08_REV_CONTR_GOVT_GRANT, 195)
  expect_equal(rec$F9_08_REV_CONTR_OTH, 105)
  expect_equal(rec$F9_08_REV_OTH_INVEST_INCOME_EXCL, 35)
  # identities now hold, and fixed columns are untouched
  expect_equal(nrow(accounting_check(rec)), 0L)
  expect_equal(rec$F9_08_REV_CONTR_FED_CAMP, bad$F9_08_REV_CONTR_FED_CAMP)
  expect_equal(attr(rec, "reconciled")$rows_adjusted, 1L)
})

test_that("expense column identities are checked and reconciled", {
  row <- data.frame(
    EIN2 = "A", TAX_YEAR = 2020,
    F9_09_EXP_OCCUPANCY_PROG = 60, F9_09_EXP_OCCUPANCY_MGMT = 25,
    F9_09_EXP_OCCUPANCY_FUNDR = 15, F9_09_EXP_OCCUPANCY_TOT = 100,
    stringsAsFactors = FALSE)
  expect_equal(nrow(accounting_check(row, section = "expenses")), 0L)

  row$F9_09_EXP_OCCUPANCY_TOT <- 110                 # total overstated by 10
  v <- accounting_check(row, section = "expenses")
  expect_equal(v$identity, "exp_occupancy_columns")
  expect_equal(v$residual, 10)

  rec <- reconcile(row, section = "expenses",
                   fixed = c("F9_09_EXP_OCCUPANCY_PROG", "F9_09_EXP_OCCUPANCY_MGMT",
                             "F9_09_EXP_OCCUPANCY_FUNDR"))
  expect_equal(rec$F9_09_EXP_OCCUPANCY_TOT, 100)     # only free var absorbs the gap
})

test_that("balance-sheet equation is checked (assets = liabilities + net assets)", {
  row <- data.frame(
    EIN2 = "A", TAX_YEAR = 2020,
    F9_10_ASSET_TOT_EOY = 1000, F9_10_LIAB_TOT_EOY = 400,
    F9_10_NAFB_TOT_EOY = 600, stringsAsFactors = FALSE)
  expect_equal(nrow(accounting_check(row, section = "balance_sheet")), 0L)

  row$F9_10_NAFB_TOT_EOY <- 550                      # doesn't balance
  v <- accounting_check(row, section = "balance_sheet")
  expect_equal(v$identity, "bs_balance_eoy")
  expect_equal(v$residual, 50)
})

test_that("accounting_check evaluates only complete identities across a panel", {
  panel <- rbind(make_revenue_row(), transform(make_revenue_row(),
                 EIN2 = "B", F9_08_REV_OTH_GAMING_NET_TOT = 99))  # B breaks gaming
  v <- accounting_check(panel)
  expect_setequal(v$EIN2, "B")
  expect_equal(v$identity, "rev_gaming_net")
})
