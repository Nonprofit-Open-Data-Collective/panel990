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

expand <- function(defs, section) do.call(rbind, lapply(defs, function(d) {
  coef <- d[[4]]
  data.frame(identity = d[[1]], section = section, form_scope = "PC",
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

# ============================== assemble & save ==============================
accounting_identities <- rbind(
  expand(rev_defs, "revenue"),
  expand(exp_defs, "expenses"),
  expand(bs_defs,  "balance_sheet")
)
rownames(accounting_identities) <- NULL

load("data/field_concordance.rda")
unknown <- setdiff(unique(accounting_identities$variable), field_concordance$variable_name)
if (length(unknown))
  stop("Unknown variable(s) not in field_concordance:\n  ", paste(unknown, collapse = "\n  "))

n_by_sec <- tapply(accounting_identities$identity, accounting_identities$section,
                   function(x) length(unique(x)))
cat("identities:", length(unique(accounting_identities$identity)),
    " rows:", nrow(accounting_identities),
    " variables:", length(unique(accounting_identities$variable)), "\n")
print(n_by_sec)
cat("all variables validated against field_concordance.\n")

save(accounting_identities, file = "data/accounting_identities.rda", compress = "xz")
cat("wrote data/accounting_identities.rda\n")
