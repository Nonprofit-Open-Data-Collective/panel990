# data-raw/build-concordance.R
# Build the bundled field-scope / normalization concordance for panel990 from
# the concordance990 package's xpath concordance (the successor to the IRS
# Efile Master Concordance File, "MCF" below).
#
# Source (ODC-By v1.0, attribution required):
#   https://github.com/Nonprofit-Open-Data-Collective/concordance990
#   file: concordance.csv  (one row per xpath, 990/990EZ and 990PF combined)
#
# Output (one row per RDB variable_name each):
#   data/field_concordance.rda     990/990EZ release (efile_)
#   data/field_concordance_pf.rda  990PF release (efilepf_)
#
# Run with:  Rscript data-raw/build-concordance.R

# --- 1. Load the concordance (cached copy, or download) -----------------------
local_csv  <- "data-raw/concordance990.csv"
source_url <- paste0(
  "https://raw.githubusercontent.com/Nonprofit-Open-Data-Collective/",
  "concordance990/main/concordance.csv"
)
src <- if (file.exists(local_csv)) local_csv else source_url
src_all <- data.table::fread(src, data.table = FALSE, colClasses = "character",
                             encoding = "UTF-8")

# The 990/990EZ (efile_) and 990PF (efilepf_) releases are separate databases.
# Each gets its own concordance, built from the tables its release publishes:
# the 990 release has no PF-* tables, and the PF release carries only the PF-*
# tables plus copies of the shared header, signature, and Schedule B tables.
pf_shared_tables <- c("F9-P00-T00-HEADER", "F9-P02-T00-SIGNATURE")
is_pf_table <- grepl("^PF-", src_all$rdb_table)
mcf_990 <- src_all[!is_pf_table, , drop = FALSE]
mcf_pf  <- src_all[is_pf_table | grepl("^SB-", src_all$rdb_table) |
                     src_all$rdb_table %in% pf_shared_tables, , drop = FALSE]

# --- 2. Mapping rules (REVIEW THESE) ------------------------------------------
# blank_meaning: how to read a blank on a form where the field IS in scope.
#   checkbox                 -> implicit_false
#   numeric & money (USD)    -> implicit_zero      (blank dollar amount = 0)
#   numeric & non-money      -> literal_missing    (counts/ratios/years/ids)
#   text / date              -> literal_missing
# Money is detected from the XSD schema type (data_type_xsd), which is far more
# reliable than field-name matching. Resolved per variable via the modal rule.
money_xsd_pattern <- "amount|amt|money|currenc"   # matches USAmountType, USAmountNNType
blank_default <- "literal_missing"                # for empty/unknown data_type

blank_meaning_for <- function(dtype, is_money) {
  if (is.na(dtype)) return(blank_default)
  if (dtype == "checkbox") return("implicit_false")
  if (dtype == "numeric")  return(if (isTRUE(is_money)) "implicit_zero" else "literal_missing")
  if (dtype %in% c("text", "date")) return("literal_missing")
  blank_default
}

# variable_scope -> applicable return forms (used by normalize()).
# PC = full 990 only; EZ = 990EZ only; PZ = both; PF = 990PF; HD/SG =
# structural (all forms).
scope_to_forms <- list(
  PC = "990",
  EZ = "990EZ",
  PZ = c("990", "990EZ"),
  PF = "990PF",
  HD = "*",
  SG = "*"
)

# Precedence for resolving the (few) variables with conflicting metadata.
scope_priority <- c("PZ", "PC", "EZ", "HD", "SG")

# The MCF flags many single-form fields as PZ when the *concept* exists on both
# forms (e.g. Part X line 1 cash is PZ because the 990EZ has a combined line 22
# cash/savings/investments, which is a different variable). Taken literally,
# that zero-fills 990EZ filers on full-990-only lines and vice versa. For
# main-form fields, scope is therefore derived from where the variable's xpaths
# actually live, across all schema versions: under IRS990/ -> PC, IRS990EZ/ ->
# EZ, both -> PZ. Header, signature, and schedule fields keep the MCF value.
xpath_form_scope <- function(xpaths, mcf_scope) {
  if (is.na(mcf_scope) || !mcf_scope %in% c("PC", "EZ", "PZ")) return(mcf_scope)
  on_pc <- any(grepl("^/Return/ReturnData/IRS990/",   xpaths))
  on_ez <- any(grepl("^/Return/ReturnData/IRS990EZ/", xpaths))
  if (on_pc && on_ez) "PZ" else if (on_pc) "PC" else if (on_ez) "EZ" else mcf_scope
}

# In the PF release every non-structural field, Schedule B included, is filed
# on a 990PF return, so it is PF-scoped whatever the source says.
pf_form_scope <- function(xpaths, mcf_scope) {
  if (!is.na(mcf_scope) && mcf_scope %in% c("HD", "SG")) mcf_scope else "PF"
}
type_priority  <- c("numeric", "checkbox", "date", "text")

# --- 3. Collapse to one row per variable_name ---------------------------------
is_true <- function(x) toupper(trimws(x)) %in% c("T", "TRUE", "1", "YES")

# The MCF marks some identifier and code fields numeric, but their XSD types
# are strings: EINs and phone numbers carry leading zeros, PTINs and CUSIPs are
# alphanumeric, and the Schedule D *_MOV fields hold a valuation-method label.
# A numeric cast would drop the zeros or turn the value into NA, so a variable
# whose resolved XSD type is one of these is text, whatever data_type_simple
# says. Applied per variable rather than per row: older schema versions often
# carry no XSD type, and overriding row by row would leave those rows numeric
# and report a spurious type_conflict.
identifier_xsd <- c("EINType", "PhoneNumberType", "PTINType", "CUSIPNumberType",
                    "AlphaNumericType", "StringType", "LineExplanationType")

pick <- function(values, priority) {
  values <- values[!is.na(values) & values != ""]
  if (!length(values)) return(NA_character_)
  tab <- sort(table(values), decreasing = TRUE)
  top <- names(tab)[tab == max(tab)]                 # modal value(s)
  if (length(top) == 1L) return(top)
  hit <- priority[priority %in% top]                 # break ties by priority
  if (length(hit)) hit[[1]] else sort(top)[[1]]
}

# Transliterate text to ASCII so the bundled dataset passes R CMD check's
# non-ASCII test.
to_ascii <- function(x) {
  out <- iconv(x, from = "latin1", to = "ASCII//TRANSLIT", sub = "")
  bad <- is.na(out) & !is.na(x)
  out[bad] <- iconv(x[bad], to = "ASCII", sub = "")
  out
}

# `form_scope` derives a variable's scope from its xpaths and source scope:
# xpath_form_scope() for the 990 release, pf_form_scope() for the PF release.
collapse_concordance <- function(mcf, form_scope) {
  mcf$.current <- is_true(mcf$current_version)
  mcf$data_type_simple[is.na(mcf$data_type_simple) | mcf$data_type_simple == ""] <-
    "text"  # ExplanationType blanks -> text
  vars <- sort(unique(mcf$variable_name))
  vars <- vars[!is.na(vars) & vars != ""]

  rows <- lapply(vars, function(v) {
    sub_all <- mcf[mcf$variable_name == v, , drop = FALSE]
    sub <- if (any(sub_all$.current)) sub_all[sub_all$.current, , drop = FALSE] else sub_all
    scope_mcf <- pick(sub$variable_scope, scope_priority)
    scope <- form_scope(sub_all$xpath, scope_mcf)
    dtype <- pick(sub$data_type_simple, type_priority)
    xsd   <- pick(sub$data_type_xsd,    character())
    if (!is.na(xsd) && xsd %in% identifier_xsd) dtype <- "text"
    is_money <- !is.na(dtype) && dtype == "numeric" &&
      !is.na(xsd) && grepl(money_xsd_pattern, xsd, ignore.case = TRUE)
    tables_all <- sort(unique(sub$rdb_table[!is.na(sub$rdb_table) & sub$rdb_table != ""]))
    data.frame(
      variable_name    = v,
      description      = pick(sub$description, character()),
      variable_scope   = scope,
      scope_mcf        = scope_mcf,
      form_type        = pick(sub$form_type, character()),
      data_type_simple = dtype,
      data_type_xsd    = xsd,
      money_field      = is_money,
      blank_meaning    = blank_meaning_for(dtype, is_money),
      forms            = paste(scope_to_forms[[scope]], collapse = "|"),
      rdb_table        = pick(sub$rdb_table, character()),
      rdb_tables_all   = paste(tables_all, collapse = ";"),
      rdb_relationship = pick(sub$rdb_relationship, c("MANY", "ONE")),
      current_version  = any(sub_all$.current),
      n_xpaths         = nrow(sub_all),
      scope_conflict   = length(unique(sub_all$variable_scope[!is.na(sub_all$variable_scope) &
                                                                sub_all$variable_scope != ""])) > 1L,
      type_conflict    = length(unique(sub_all$data_type_simple)) > 1L,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  char_cols <- names(out)[vapply(out, is.character, logical(1L))]
  for (col in char_cols) out[[col]] <- to_ascii(out[[col]])
  out
}

# --- 4. Report ----------------------------------------------------------------
report <- function(fc, name) {
  cat("\n==========", name, ":", nrow(fc), "variables\n\n")
  cat("scope:\n");   print(table(fc$variable_scope))
  cat("\ndata_type_simple:\n"); print(table(fc$data_type_simple))
  cat("\nblank_meaning:\n"); print(table(fc$blank_meaning))
  cat("\nnumeric split (money -> zero, non-money -> missing):\n")
  print(table(numeric_type = fc$data_type_simple == "numeric", money = fc$money_field))
  cat("\nscope x blank_meaning:\n")
  print(table(fc$variable_scope, fc$blank_meaning))
  cat("\nconflicts resolved  scope:", sum(fc$scope_conflict),
      " type:", sum(fc$type_conflict), "\n")
  cat("\nscope derived from source (MCF -> derived):\n")
  print(table(mcf = fc$scope_mcf, derived = fc$variable_scope))
}

field_concordance    <- collapse_concordance(mcf_990, xpath_form_scope)
field_concordance_pf <- collapse_concordance(mcf_pf,  pf_form_scope)
report(field_concordance, "field_concordance")
report(field_concordance_pf, "field_concordance_pf")

# --- 5. Save ------------------------------------------------------------------
if (!dir.exists("data")) dir.create("data")
save(field_concordance, file = "data/field_concordance.rda", compress = "xz")
save(field_concordance_pf, file = "data/field_concordance_pf.rda", compress = "xz")
utils::write.csv(field_concordance, "data-raw/field_concordance_review.csv",
                 row.names = FALSE, na = "")
utils::write.csv(field_concordance_pf, "data-raw/field_concordance_pf_review.csv",
                 row.names = FALSE, na = "")
cat("\nwrote data/field_concordance{,_pf}.rda and data-raw/*_review.csv\n")
