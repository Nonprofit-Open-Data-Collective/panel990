# data-raw/build-concordance.R
# Build the bundled field-scope / normalization concordance for panel990 from
# the IRS Efile Master Concordance File (MCF).
#
# Source (ODC-By v1.0, attribution required):
#   https://github.com/Nonprofit-Open-Data-Collective/irs-efile-master-concordance-file
#   file: concordance.csv  (one row per xpath / schema version)
#
# Output: data/field_concordance.rda  (one row per RDB variable_name)
#
# Run with:  Rscript data-raw/build-concordance.R

# --- 1. Load the master concordance (cached copy, or download) ----------------
local_csv  <- "data-raw/concordance-master.csv"
source_url <- paste0(
  "https://raw.githubusercontent.com/Nonprofit-Open-Data-Collective/",
  "irs-efile-master-concordance-file/master/concordance.csv"
)
src <- if (file.exists(local_csv)) local_csv else source_url
# Source is Windows-1252; read as Latin-1 so smart quotes decode correctly.
mcf <- data.table::fread(src, data.table = FALSE, colClasses = "character",
                         encoding = "Latin-1")

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
# PC = full 990 only; EZ = 990EZ only; PZ = both; HD/SG = structural (all forms).
scope_to_forms <- list(
  PC = "990",
  EZ = "990EZ",
  PZ = c("990", "990EZ"),
  HD = "*",
  SG = "*"
)

# Precedence for resolving the (few) variables with conflicting metadata.
scope_priority <- c("PZ", "PC", "EZ", "HD", "SG")
type_priority  <- c("numeric", "checkbox", "date", "text")

# --- 3. Collapse to one row per variable_name ---------------------------------
is_true <- function(x) toupper(trimws(x)) %in% c("T", "TRUE", "1", "YES")
mcf$.current <- is_true(mcf$current_version)
mcf$data_type_simple[is.na(mcf$data_type_simple) | mcf$data_type_simple == ""] <-
  "text"  # ExplanationType blanks -> text

pick <- function(values, priority) {
  values <- values[!is.na(values) & values != ""]
  if (!length(values)) return(NA_character_)
  tab <- sort(table(values), decreasing = TRUE)
  top <- names(tab)[tab == max(tab)]                 # modal value(s)
  if (length(top) == 1L) return(top)
  hit <- priority[priority %in% top]                 # break ties by priority
  if (length(hit)) hit[[1]] else sort(top)[[1]]
}

vars <- sort(unique(mcf$variable_name))
vars <- vars[!is.na(vars) & vars != ""]

rows <- lapply(vars, function(v) {
  sub_all <- mcf[mcf$variable_name == v, , drop = FALSE]
  sub <- if (any(sub_all$.current)) sub_all[sub_all$.current, , drop = FALSE] else sub_all
  scope <- pick(sub$variable_scope,   scope_priority)
  dtype <- pick(sub$data_type_simple, type_priority)
  xsd   <- pick(sub$data_type_xsd,    character())
  is_money <- !is.na(dtype) && dtype == "numeric" &&
    !is.na(xsd) && grepl(money_xsd_pattern, xsd, ignore.case = TRUE)
  tables_all <- sort(unique(sub$rdb_table[!is.na(sub$rdb_table) & sub$rdb_table != ""]))
  data.frame(
    variable_name    = v,
    description      = pick(sub$description, character()),
    variable_scope   = scope,
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
field_concordance <- do.call(rbind, rows)
rownames(field_concordance) <- NULL

# Transliterate text to ASCII (source uses Windows-1252 smart quotes/dashes)
# so the bundled dataset passes R CMD check's non-ASCII test.
to_ascii <- function(x) {
  out <- iconv(x, from = "latin1", to = "ASCII//TRANSLIT", sub = "")
  bad <- is.na(out) & !is.na(x)
  out[bad] <- iconv(x[bad], to = "ASCII", sub = "")
  out
}
char_cols <- names(field_concordance)[vapply(field_concordance, is.character, logical(1L))]
for (col in char_cols) field_concordance[[col]] <- to_ascii(field_concordance[[col]])

# --- 4. Report ----------------------------------------------------------------
fc <- field_concordance
cat("field_concordance:", nrow(fc), "variables\n\n")
cat("scope:\n");   print(table(fc$variable_scope))
cat("\ndata_type_simple:\n"); print(table(fc$data_type_simple))
cat("\nblank_meaning:\n"); print(table(fc$blank_meaning))
cat("\nnumeric split (money -> zero, non-money -> missing):\n")
print(table(numeric_type = fc$data_type_simple == "numeric", money = fc$money_field))
cat("\nscope x blank_meaning:\n")
print(table(fc$variable_scope, fc$blank_meaning))
cat("\nconflicts resolved  scope:", sum(fc$scope_conflict),
    " type:", sum(fc$type_conflict), "\n")
cat("both-forms (PZ) fields:", sum(fc$variable_scope == "PZ"), "\n")

# --- 5. Save ------------------------------------------------------------------
if (!dir.exists("data")) dir.create("data")
save(field_concordance, file = "data/field_concordance.rda", compress = "xz")
utils::write.csv(field_concordance, "data-raw/field_concordance_review.csv",
                 row.names = FALSE, na = "")
cat("\nwrote data/field_concordance.rda and data-raw/field_concordance_review.csv\n")
