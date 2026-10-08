# data-raw/build-accounting-identities.R
# Build the bundled accounting-identity registry for the IRS 990 revenue
# (Part VIII), functional-expenses (Part IX), and balance-sheet (Part X)
# sections, keyed to ef2 variable_names. Each identity is a linear combination
# of fields that must equal zero. Stored long: one row per (identity, variable,
# coefficient).
#
# Only high-confidence identities whose structure is unambiguous from the ef2
# naming are included. Vertical sums are skipped where write-in detail lives in
# 1xm tables (expense line 24) or form-version variants create ambiguity
# (balance-sheet cash lines). Every variable is validated against
# field_concordance, so a bad name fails the build.
#
# Run with:  Rscript data-raw/build-accounting-identities.R

sum_to <- function(total, parts)                # total = sum(parts)
  stats::setNames(c(1, rep(-1, length(parts))), c(total, parts))
net_of <- function(net, gross, cost)            # net = gross - cost
  stats::setNames(c(1, -1, 1), c(net, gross, cost))

expand <- function(defs, section, form_scope = "PC") do.call(rbind, lapply(defs, function(d) {
  coef <- d[[4]]
  data.frame(identity = d[[1]], section = section, form_scope = form_scope,
             type = d[[2]], description = d[[3]],
             variable = names(coef), coefficient = as.numeric(coef),
             stringsAsFactors = FALSE)
}))

# ============================ REVENUE (Part VIII) =============================
R <- "F9_08_REV_"
cols4 <- function(base)                          # base_TOT = _RLTD + _UBIZ + _EXCL
  sum_to(paste0(base, "_TOT"), paste0(base, c("_RLTD", "_UBIZ", "_EXCL")))

rev_defs <- list(
  list("rev_grand_columns",   "column", "Total revenue: col A = related + unrelated + excluded",         cols4(paste0(R, "TOT"))),
  list("rev_prog_columns",    "column", "Program service (other): A = B + C + D",                        cols4(paste0(R, "PROG_OTH"))),
  list("rev_misc_columns",    "column", "Miscellaneous (other): A = B + C + D",                          cols4(paste0(R, "MISC_OTH"))),
  list("rev_invest_columns",  "column", "Investment income: A = B + C + D",                              cols4(paste0(R, "OTH_INVEST_INCOME"))),
  list("rev_bond_columns",    "column", "Tax-exempt bond proceeds: A = B + C + D",                       cols4(paste0(R, "OTH_INVEST_BOND"))),
  list("rev_royalty_columns", "column", "Royalties: A = B + C + D",                                      cols4(paste0(R, "OTH_ROY"))),
  list("rev_rent_columns",    "column", "Net rental income: A = B + C + D",                              cols4(paste0(R, "OTH_RENT_NET"))),
  list("rev_sales_columns",   "column", "Net gain on asset sales: A = B + C + D",                        cols4(paste0(R, "OTH_SALE_GAIN_NET"))),
  list("rev_fundr_columns",   "column", "Net fundraising: A = B + C + D",                                cols4(paste0(R, "OTH_FUNDR_NET"))),
  list("rev_gaming_columns",  "column", "Net gaming: A = B + C + D",                                     cols4(paste0(R, "OTH_GAMING_NET"))),
  list("rev_inventory_columns","column","Net inventory sales: A = B + C + D",                            cols4(paste0(R, "OTH_INV_NET"))),
  list("rev_contributions_subtotal", "subtotal", "Total contributions = federated + dues + events + related orgs + govt + other",
       sum_to(paste0(R, "CONTR_TOT"), paste0(R, c("CONTR_FED_CAMP", "CONTR_MEMBSHIP_DUE", "CONTR_FUNDR_EVNT", "CONTR_RLTD_ORG", "CONTR_GOVT_GRANT", "CONTR_OTH")))),
  list("rev_rent_income_real", "net", "Rental income (real) = gross - expenses",
       net_of(paste0(R, "OTH_RENT_INCOME_REAL"), paste0(R, "OTH_RENT_GRO_REAL"), paste0(R, "OTH_RENT_LESS_EXP_REAL"))),
  list("rev_rent_income_pers", "net", "Rental income (personal) = gross - expenses",
       net_of(paste0(R, "OTH_RENT_INCOME_PERS"), paste0(R, "OTH_RENT_GRO_PERS"), paste0(R, "OTH_RENT_LESS_EXP_PERS"))),
  list("rev_rent_net", "subtotal", "Net rental income = real + personal",
       sum_to(paste0(R, "OTH_RENT_NET_TOT"), paste0(R, c("OTH_RENT_INCOME_REAL", "OTH_RENT_INCOME_PERS")))),
  list("rev_sale_gain_sec", "net", "Gain on securities = gross sales - cost basis",
       net_of(paste0(R, "OTH_SALE_GAIN_SEC"), paste0(R, "OTH_SALE_ASSET_SEC"), paste0(R, "OTH_SALE_LESS_COST_SEC"))),
  list("rev_sale_gain_oth", "net", "Gain on other assets = gross sales - cost basis",
       net_of(paste0(R, "OTH_SALE_GAIN_OTH"), paste0(R, "OTH_SALE_ASSET_OTH"), paste0(R, "OTH_SALE_LESS_COST_OTH"))),
  list("rev_sale_net", "subtotal", "Net gain on sales = securities + other",
       sum_to(paste0(R, "OTH_SALE_GAIN_NET_TOT"), paste0(R, c("OTH_SALE_GAIN_SEC", "OTH_SALE_GAIN_OTH")))),
  list("rev_gaming_net", "net", "Net gaming = gross - direct expenses",
       net_of(paste0(R, "OTH_GAMING_NET_TOT"), paste0(R, "OTH_GAMING"), paste0(R, "OTH_GAMING_DIRECT_EXP"))),
  list("rev_inventory_net", "net", "Net inventory sales = gross - cost of goods",
       net_of(paste0(R, "OTH_INV_NET_TOT"), paste0(R, "OTH_INV_GRO_SALE"), paste0(R, "OTH_INV_COST_GOODS"))),
  list("rev_grand_total", "grand_total", "Total revenue (line 12) = sum of all revenue line totals",
       sum_to(paste0(R, "TOT_TOT"), paste0(R, c("CONTR_TOT", "PROG_TOT_TOT", "OTH_INVEST_INCOME_TOT", "OTH_INVEST_BOND_TOT", "OTH_ROY_TOT", "OTH_RENT_NET_TOT", "OTH_SALE_GAIN_NET_TOT", "OTH_FUNDR_NET_TOT", "OTH_GAMING_NET_TOT", "OTH_INV_NET_TOT", "MISC_TOT_TOT"))))
)

# ====================== FUNCTIONAL EXPENSES (Part IX) ========================
# Column identities only: total = program + management + fundraising per line.
# (Vertical line 25 = sum of lines skipped: line 24 write-ins live in a 1xm table.)
E <- "F9_09_EXP_"
exp4 <- c("AD_PROMO", "COMP_DSQ_PERS", "COMP_DTK", "CONF_MEETING", "DEPREC",
          "FEE_SVC_ACC", "FEE_SVC_INVEST", "FEE_SVC_LEGAL", "FEE_SVC_LOB",
          "FEE_SVC_MGMT", "FEE_SVC_OTH", "INFO_TECH", "INSURANCE", "INT",
          "JOINT_COST", "OCCUPANCY", "OFFICE", "OTH_EMPL_BEN", "OTH_OTH",
          "OTH_SAL_WAGE", "PAY_AFFIL", "PAYROLL_TAX", "PENSION_CONTR", "ROY",
          "TRAVEL", "TRAVEL_ENTMT")
exp_defs <- lapply(exp4, function(b) list(
  paste0("exp_", tolower(b), "_columns"), "column",
  paste0(b, ": total = program + management + fundraising"),
  sum_to(paste0(E, b, "_TOT"), paste0(E, b, c("_PROG", "_MGMT", "_FUNDR")))))
# program-only lines (grants, benefits to members): total = program
exp_defs <- c(exp_defs, lapply(c("BEN_PAID_MEMB", "GRANT_FRGN", "GRANT_US_INDIV", "GRANT_US_ORG"),
  function(b) list(paste0("exp_", tolower(b), "_columns"), "column",
    paste0(b, ": total = program (program-only line)"),
    sum_to(paste0(E, b, "_TOT"), paste0(E, b, "_PROG")))))
# fundraising-only line (professional fundraising fees)
exp_defs <- c(exp_defs, list(list("exp_fee_svc_fundr_columns", "column",
  "Professional fundraising fees: total = fundraising (fundraising-only line)",
  sum_to(paste0(E, "FEE_SVC_FUNDR_TOT"), paste0(E, "FEE_SVC_FUNDR_FUNDR")))))
# grand total (line 25) column split
exp_defs <- c(exp_defs, list(list("exp_grand_columns", "column",
  "Total functional expenses (line 25): col A = program + management + fundraising",
  sum_to(paste0(E, "TOT_TOT"), paste0(E, "TOT", c("_PROG", "_MGMT", "_FUNDR"))))))

# ========================= BALANCE SHEET (Part X) ============================
B <- "F9_10_"
liab_lines <- c("ACC_PAYABLE", "GRANT_PAYABLE", "REV_DEFERRED", "TAX_EXEMPT_BOND",
                "ESCROW_ACC", "LOAN_OFF", "MTG_NOTE", "NOTE_UNSEC", "OTH")
bs_defs <- list()
for (per in c("BOY", "EOY")) {
  bs_defs <- c(bs_defs, list(
    list(paste0("bs_balance_", tolower(per)), "balance",
         paste0("Total assets = total liabilities + total net assets (", per, ")"),
         sum_to(paste0(B, "ASSET_TOT_", per),
                paste0(B, c("LIAB_TOT_", "NAFB_TOT_"), per))),
    list(paste0("bs_liabilities_", tolower(per)), "subtotal",
         paste0("Total liabilities = sum of liability lines (", per, ")"),
         sum_to(paste0(B, "LIAB_TOT_", per),
                paste0(B, "LIAB_", liab_lines, "_", per)))))
}
bs_defs <- c(bs_defs, list(list("bs_land_bldg_net", "net",
  "Land, buildings, and equipment (net) = gross - accumulated depreciation",
  net_of(paste0(B, "ASSET_LAND_BLDG_NET_EOY"), paste0(B, "ASSET_LAND_BLDG"),
         paste0(B, "ASSET_LAND_BLDG_DEPREC")))))

# ===================== 990PF FINANCIAL STATEMENTS (Parts I-III) ===============
# The 990PF reports Part I in up to four columns -- (a) books, (b) net
# investment income, (c) adjusted net income, (d) disbursements -- and Part II
# at beginning- and end-of-year book value plus end-of-year fair market value.
# Every identity below held for at least 98% of 2021-2022 990PF filings after
# panel_normalize(). Two plausible ones are deliberately omitted: net
# investment income and adjusted net income (Part I lines 27b/27c) are floored
# at zero on the form, so they do not equal revenue minus expenses.
P1 <- "PF_01_"; P2 <- "PF_02_"; P3 <- "PF_03_"

pf_rev_defs <- list(
  list("pf_rev_total_books", "subtotal", "Part I total revenue (books) = sum of revenue lines",
       sum_to(paste0(P1, "REV_TOT_BOOKS"), paste0(P1, c("REV_CONTR_REC_BOOKS", "REV_INT_SAVING_BOOKS",
         "REV_DIVIDEND_BOOKS", "REV_RENT_GRO_BOOKS", "REV_SALE_ASSET_NET_BOOKS", "REV_GRO_PROFIT_BOOKS",
         "REV_OTH_INCOME_BOOKS")))),
  list("pf_rev_total_net", "subtotal", "Part I total revenue (net investment income) = sum of revenue lines",
       sum_to(paste0(P1, "REV_TOT_NET"), paste0(P1, c("REV_INT_SAVING_NET", "REV_DIVIDEND_NET",
         "REV_RENT_GRO_NET", "REV_CAP_GAIN_NET", "REV_OTH_INCOME_NET")))),
  list("pf_rev_total_adj_net", "subtotal", "Part I total revenue (adjusted net income) = sum of revenue lines",
       sum_to(paste0(P1, "REV_TOT_ADJ_NET"), paste0(P1, c("REV_INT_SAVING_ADJ_NET", "REV_DIVIDEND_ADJ_NET",
         "REV_RENT_GRO_ADJ_NET", "REV_CAP_GAIN_ADJ_NET", "REV_INCOME_MOD_ADJ_NET", "REV_GRO_PROFIT_ADJ_NET",
         "REV_OTH_INCOME_ADJ_NET")))),
  list("pf_rev_gross_profit", "net", "Gross profit (books) = gross sales less returns - cost of goods sold",
       net_of(paste0(P1, "REV_GRO_PROFIT_BOOKS"), paste0(P1, "REV_GRO_SALE_LESS_RETURN"),
              paste0(P1, "REV_LESS_COST_GOODS_SOLD"))),
  list("pf_excess_rev_over_exp", "net", "Excess of revenue over expenses (books) = total revenue - total expenses",
       net_of(paste0(P1, "EXCESS_REV_OVER_EXP_BOOKS"), paste0(P1, "REV_TOT_BOOKS"),
              paste0(P1, "EXP_TOT_EXP_DISBMT_BOOKS")))
)

pf_exp_lines <- c("COMP_OFF", "OTH_EMPL_SAL", "PENSION_EMPL", "LEGAL_BEN", "ACC_FEE",
                  "OTH_PROF_FEE", "INT", "TAXES", "DEPREC", "OCCUPANCY", "TRAVEL_CONF",
                  "PRINT_PUBLICA", "OTH")
pf_columns <- c(BOOKS = "books", NET = "net investment income",
                ADJ_NET = "adjusted net income", DISBMT = "disbursements")
pf_exp_defs <- lapply(names(pf_columns), function(col) {
  lines <- if (col == "DISBMT") setdiff(pf_exp_lines, "DEPREC") else pf_exp_lines
  list(paste0("pf_exp_operating_", tolower(col)), "subtotal",
       paste0("Part I total operating expenses (", pf_columns[[col]], ") = sum of expense lines"),
       sum_to(paste0(P1, "EXP_TOT_OPERATING_", col), paste0(P1, "EXP_", lines, "_", col)))
})
pf_exp_defs <- c(pf_exp_defs, lapply(names(pf_columns), function(col) {
  parts <- paste0(P1, "EXP_TOT_OPERATING_", col)
  if (col %in% c("BOOKS", "DISBMT")) parts <- c(parts, paste0(P1, "EXP_CONTR_PAID_", col))
  list(paste0("pf_exp_total_", tolower(col)), "grand_total",
       paste0("Part I total expenses and disbursements (", pf_columns[[col]],
              ") = operating expenses", if (length(parts) > 1L) " + contributions paid" else ""),
       sum_to(paste0(P1, "EXP_TOT_EXP_DISBMT_", col), parts))
}))

pf_asset_lines <- c("CASH", "SAVING", "ACC", "PLEDGE", "GRANT", "RECVB_OFF", "OTH_NOTE",
                    "INV_SALE", "EXP_PREPAID", "INVEST_GOV", "INVEST_STCK", "INVEST_BOND",
                    "INVEST_LAND", "INVEST_MTG", "INVEST_OTH", "LAND", "OTH")
pf_liab_lines <- c("ACC", "GRANT", "REV_DEFERRED", "LOAN_OFF", "MTG_NOTE", "OTH")
pf_na_lines <- c("UNRESTRICT", "RESTRICT", "CAP_STCK", "CAP_SURPLUS", "EARNING_RETAIN")
pf_bs_defs <- list(list("pf_bs_assets_eoy_fmv", "subtotal",
  "Part II total assets (EOY fair market value) = sum of asset lines",
  sum_to(paste0(P2, "ASSET_TOT_EOY_FMV"), paste0(P2, "ASSET_", pf_asset_lines, "_EOY_FMV"))))
for (per in c("BOY", "EOY")) {
  v <- paste0("_", per, "_BV"); lab <- paste0(" (", per, " book value)")
  pf_bs_defs <- c(pf_bs_defs, list(
    list(paste0("pf_bs_balance_", tolower(per)), "balance",
         paste0("Total assets = total liabilities and net assets", lab),
         sum_to(paste0(P2, "ASSET_TOT", v), paste0(P2, "NAFB_TOT_LIAB_NAFB", v))),
    list(paste0("pf_bs_assets_", tolower(per)), "subtotal",
         paste0("Total assets = sum of asset lines", lab),
         sum_to(paste0(P2, "ASSET_TOT", v), paste0(P2, "ASSET_", pf_asset_lines, v))),
    list(paste0("pf_bs_liabilities_", tolower(per)), "subtotal",
         paste0("Total liabilities = sum of liability lines", lab),
         sum_to(paste0(P2, "LIAB_TOT", v), paste0(P2, "LIAB_", pf_liab_lines, v))),
    list(paste0("pf_bs_net_assets_", tolower(per)), "subtotal",
         paste0("Total net assets = sum of net asset and fund balance lines", lab),
         sum_to(paste0(P2, "NAFB_TOT", v), paste0(P2, "NAFB_", pf_na_lines, v))),
    list(paste0("pf_bs_liab_net_assets_", tolower(per)), "subtotal",
         paste0("Total liabilities and net assets = liabilities + net assets", lab),
         sum_to(paste0(P2, "NAFB_TOT_LIAB_NAFB", v), paste0(P2, c("LIAB_TOT", "NAFB_TOT"), v)))))
}

# Part III reconciles beginning to ending net assets and ties back to Parts I
# and II. The ties span tables, so they are evaluated only when all three
# parts are in the panel.
pf_na_defs <- list(
  list("pf_na_subtotal", "subtotal", "Part III line 4 = BOY net assets + excess revenue + other increases",
       sum_to(paste0(P3, "NAFB_CHANGE_SUBTOT"), paste0(P3, c("NAFB_TOT_BOY_BV", "EXCESS_REV_OVER_EXP_BOOKS",
         "NAFB_OTH_INCREASE")))),
  list("pf_na_eoy", "net", "Part III EOY net assets = line 4 - other decreases",
       net_of(paste0(P3, "NAFB_TOT_EOY"), paste0(P3, "NAFB_CHANGE_SUBTOT"), paste0(P3, "NAFB_OTH_DECREASE"))),
  list("pf_na_tie_excess", "tie", "Part III excess revenue = Part I excess revenue (books)",
       sum_to(paste0(P3, "EXCESS_REV_OVER_EXP_BOOKS"), paste0(P1, "EXCESS_REV_OVER_EXP_BOOKS"))),
  list("pf_na_tie_boy", "tie", "Part III BOY net assets = Part II BOY total net assets",
       sum_to(paste0(P3, "NAFB_TOT_BOY_BV"), paste0(P2, "NAFB_TOT_BOY_BV"))),
  list("pf_na_tie_eoy", "tie", "Part III EOY net assets = Part II EOY total net assets",
       sum_to(paste0(P3, "NAFB_TOT_EOY"), paste0(P2, "NAFB_TOT_EOY_BV")))
)

# ============================== assemble & save ==============================
accounting_identities <- rbind(
  expand(rev_defs, "revenue"),
  expand(exp_defs, "expenses"),
  expand(bs_defs,  "balance_sheet"),
  expand(pf_rev_defs, "revenue", "PF"),
  expand(pf_exp_defs, "expenses", "PF"),
  expand(pf_bs_defs,  "balance_sheet", "PF"),
  expand(pf_na_defs,  "net_assets", "PF")
)
rownames(accounting_identities) <- NULL

load("data/field_concordance.rda")
load("data/field_concordance_pf.rda")
known <- function(scope) if (scope == "PF") field_concordance_pf$variable_name else
  field_concordance$variable_name
unknown <- unlist(lapply(split(accounting_identities, accounting_identities$form_scope),
                         function(x) setdiff(unique(x$variable), known(x$form_scope[[1]]))))
if (length(unknown))
  stop("Unknown variable(s) not in the concordance for their form:\n  ",
       paste(unknown, collapse = "\n  "))

ids <- unique(accounting_identities[, c("identity", "form_scope", "section")])
cat("identities:", nrow(ids), " rows:", nrow(accounting_identities),
    " variables:", length(unique(accounting_identities$variable)), "\n")
print(table(ids$form_scope, ids$section))
cat("all variables validated against the concordance for their form.\n")

save(accounting_identities, file = "data/accounting_identities.rda", compress = "xz")
cat("wrote data/accounting_identities.rda\n")
