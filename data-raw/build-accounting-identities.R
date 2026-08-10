# data-raw/build-accounting-identities.R
# Build the bundled accounting-identity registry for the IRS 990 revenue
# section (Part VIII), keyed to ef2 variable_names. Each identity is a linear
# combination of fields that must equal zero. Stored long: one row per
# (identity, variable, coefficient).
#
# Only high-confidence identities whose structure is unambiguous from the ef2
# naming are included; the registry is designed to be extended (expenses,
# balance sheet).
#
# Run with:  Rscript data-raw/build-accounting-identities.R

# --- identity builders --------------------------------------------------------
sum_to  <- function(total, parts)               # total = sum(parts)
  stats::setNames(c(1, rep(-1, length(parts))), c(total, parts))
net_of  <- function(net, gross, cost)           # net = gross - cost
  stats::setNames(c(1, -1, 1), c(net, gross, cost))
add_up  <- function(total, parts) sum_to(total, parts)

P <- "F9_08_REV_"           # revenue field prefix
cols4 <- function(base)     # base_TOT = base_RLTD + base_UBIZ + base_EXCL
  sum_to(paste0(base, "_TOT"), paste0(base, c("_RLTD", "_UBIZ", "_EXCL")))

defs <- list(
  # -- column identities: total column A = related + unrelated + excluded ------
  list("rev_grand_columns",   "column",   "Total revenue: col A = related + unrelated + excluded",
       cols4(paste0(P, "TOT"))),
  list("rev_prog_columns",    "column",   "Program service (other): A = B + C + D",
       cols4(paste0(P, "PROG_OTH"))),
  list("rev_misc_columns",    "column",   "Miscellaneous (other): A = B + C + D",
       cols4(paste0(P, "MISC_OTH"))),
  list("rev_invest_columns",  "column",   "Investment income: A = B + C + D",
       cols4(paste0(P, "OTH_INVEST_INCOME"))),
  list("rev_bond_columns",    "column",   "Tax-exempt bond proceeds: A = B + C + D",
       cols4(paste0(P, "OTH_INVEST_BOND"))),
  list("rev_royalty_columns", "column",   "Royalties: A = B + C + D",
       cols4(paste0(P, "OTH_ROY"))),
  list("rev_rent_columns",    "column",   "Net rental income: A = B + C + D",
       cols4(paste0(P, "OTH_RENT_NET"))),
  list("rev_sales_columns",   "column",   "Net gain on asset sales: A = B + C + D",
       cols4(paste0(P, "OTH_SALE_GAIN_NET"))),
  list("rev_fundr_columns",   "column",   "Net fundraising: A = B + C + D",
       cols4(paste0(P, "OTH_FUNDR_NET"))),
  list("rev_gaming_columns",  "column",   "Net gaming: A = B + C + D",
       cols4(paste0(P, "OTH_GAMING_NET"))),
  list("rev_inventory_columns","column",  "Net inventory sales: A = B + C + D",
       cols4(paste0(P, "OTH_INV_NET"))),

  # -- subtotal ---------------------------------------------------------------
  list("rev_contributions_subtotal", "subtotal",
       "Total contributions = federated + dues + events + related orgs + govt + other",
       sum_to(paste0(P, "CONTR_TOT"), paste0(P, c(
         "CONTR_FED_CAMP", "CONTR_MEMBSHIP_DUE", "CONTR_FUNDR_EVNT",
         "CONTR_RLTD_ORG", "CONTR_GOVT_GRANT", "CONTR_OTH")))),

  # -- net-of-expense ---------------------------------------------------------
  list("rev_rent_income_real", "net",  "Rental income (real) = gross - expenses",
       net_of(paste0(P, "OTH_RENT_INCOME_REAL"), paste0(P, "OTH_RENT_GRO_REAL"),
              paste0(P, "OTH_RENT_LESS_EXP_REAL"))),
  list("rev_rent_income_pers", "net",  "Rental income (personal) = gross - expenses",
       net_of(paste0(P, "OTH_RENT_INCOME_PERS"), paste0(P, "OTH_RENT_GRO_PERS"),
              paste0(P, "OTH_RENT_LESS_EXP_PERS"))),
  list("rev_rent_net",         "subtotal", "Net rental income = real + personal",
       add_up(paste0(P, "OTH_RENT_NET_TOT"),
              paste0(P, c("OTH_RENT_INCOME_REAL", "OTH_RENT_INCOME_PERS")))),
  list("rev_sale_gain_sec",    "net",  "Gain on securities = gross sales - cost basis",
       net_of(paste0(P, "OTH_SALE_GAIN_SEC"), paste0(P, "OTH_SALE_ASSET_SEC"),
              paste0(P, "OTH_SALE_LESS_COST_SEC"))),
  list("rev_sale_gain_oth",    "net",  "Gain on other assets = gross sales - cost basis",
       net_of(paste0(P, "OTH_SALE_GAIN_OTH"), paste0(P, "OTH_SALE_ASSET_OTH"),
              paste0(P, "OTH_SALE_LESS_COST_OTH"))),
  list("rev_sale_net",         "subtotal", "Net gain on sales = securities + other",
       add_up(paste0(P, "OTH_SALE_GAIN_NET_TOT"),
              paste0(P, c("OTH_SALE_GAIN_SEC", "OTH_SALE_GAIN_OTH")))),
  list("rev_gaming_net",       "net",  "Net gaming = gross - direct expenses",
       net_of(paste0(P, "OTH_GAMING_NET_TOT"), paste0(P, "OTH_GAMING"),
              paste0(P, "OTH_GAMING_DIRECT_EXP"))),
  list("rev_inventory_net",    "net",  "Net inventory sales = gross - cost of goods",
       net_of(paste0(P, "OTH_INV_NET_TOT"), paste0(P, "OTH_INV_GRO_SALE"),
              paste0(P, "OTH_INV_COST_GOODS"))),

  # -- grand total (line 12, column A) ----------------------------------------
  list("rev_grand_total", "grand_total",
       "Total revenue (line 12) = sum of all revenue line totals",
       sum_to(paste0(P, "TOT_TOT"), paste0(P, c(
         "CONTR_TOT", "PROG_TOT_TOT", "OTH_INVEST_INCOME_TOT",
         "OTH_INVEST_BOND_TOT", "OTH_ROY_TOT", "OTH_RENT_NET_TOT",
         "OTH_SALE_GAIN_NET_TOT", "OTH_FUNDR_NET_TOT", "OTH_GAMING_NET_TOT",
         "OTH_INV_NET_TOT", "MISC_TOT_TOT"))))
)

# --- expand to long form ------------------------------------------------------
rows <- lapply(defs, function(d) {
  coef <- d[[4]]
  data.frame(identity = d[[1]], section = "revenue", form_scope = "PC",
             type = d[[2]], description = d[[3]],
             variable = names(coef), coefficient = as.numeric(coef),
             stringsAsFactors = FALSE)
})
accounting_identities <- do.call(rbind, rows)
rownames(accounting_identities) <- NULL

# --- validate every variable exists in the shipped concordance ---------------
load("data/field_concordance.rda")
unknown <- setdiff(unique(accounting_identities$variable),
                   field_concordance$variable_name)
if (length(unknown))
  stop("Unknown variable(s) not in field_concordance: ",
       paste(unknown, collapse = ", "))

cat("identities:", length(unique(accounting_identities$identity)),
    " rows:", nrow(accounting_identities),
    " variables:", length(unique(accounting_identities$variable)), "\n")
cat("all variables validated against field_concordance.\n")
print(table(unique(accounting_identities[, c("identity", "type")])$type))

save(accounting_identities, file = "data/accounting_identities.rda", compress = "xz")
cat("wrote data/accounting_identities.rda\n")
