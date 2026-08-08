# =============================================================================
#  sample-frame.R
#  A free-standing "sample frame" (sfw): a small set of keys + typed rules + meta
#  + policy that specifies which rows and columns belong in a research dataset,
#  and can be applied to, or checked against, any data frame.
#
#  The sfw is just a registry of rules. Each rule is a typed record; the engine
#  knows how to execute each type. Rule types:
#    subset  (row)     restrict to a captured set of entity ids
#    filter  (row)     structured {column, op, values} OR an {expr} string
#    dedup   (row)     one filing per entity x time (via deduplicate())
#    label   (derived) an id -> value map; filterable like a column
#    refresh (recompute) a function re-run after row-dimension changes
#    select  (column)  which columns to keep (scope/tables/vars/drop)
#    check   (report)  a predicate reported, never enforced
#    view    (report)  a crosstab/tapply summary
#    function(archive) reusable code, referenced by other operations
#
#  Structured filters are primary (introspectable -> pushdown, validation,
#  captured-by-value). Opaque `expr` strings are the escape hatch only.
#  Value semantics: every mutator returns a NEW frame and re-stamps `updated`.
# =============================================================================

.SFW_RULE_TYPES <- c("subset", "filter", "dedup", "label", "refresh",
                     "select", "check", "view", "function")
.SFW_OPS <- c("in", "not_in", "==", "!=", ">", ">=", "<", "<=",
              "between", "is_true", "is_false")

# Friendly sugar aliases -> (column, op). "@id"/"@time" resolve to the frame's
# entity/time keys; BMF aliases match bmf_merge() output columns.
.SFW_ALIASES <- list(
  years        = list(col = "@time", op = "in"),
  year         = list(col = "@time", op = "in"),
  tax_year     = list(col = "@time", op = "in"),
  eins         = list(col = "@id",   op = "in"),
  ein          = list(col = "@id",   op = "in"),
  formtype     = list(col = "RETURN_TYPE", op = "in"),
  form_type    = list(col = "RETURN_TYPE", op = "in"),
  return_type  = list(col = "RETURN_TYPE", op = "in"),
  state        = list(col = "geo_state_abbr", op = "in"),
  county       = list(col = "geo_county", op = "in"),
  msa          = list(col = "geo_metro_area", op = "in"),
  metro        = list(col = "geo_metro_area", op = "in"),
  ntee         = list(col = "ntee_code_clean", op = "in"),
  ntee_industry = list(col = "ntee_code_major_group", op = "in"),
  ntee_type    = list(col = "nteev2_org_type", op = "in"),
  subsection   = list(col = "subsection_code", op = "in"),
  filter_501c  = list(col = "subsection_code", op = "in")
)

`%||%` <- function(a, b) if (is.null(a)) b else a
.sfw_time <- function() Sys.time()
.sfw_pkg_version <- function()
  tryCatch(as.character(utils::packageVersion("panel990")),
           error = function(e) NA_character_)
.sfw_check <- function(sfw)
  if (!inherits(sfw, "sfw")) stop("`sfw` must be a sample frame (see create_sfw).")
.sfw_touch <- function(sfw) { sfw$meta$updated <- .sfw_time(); sfw }
.sfw_key <- function(sfw, type) {
  for (k in sfw$keys) if (identical(k$type, type)) return(k$var)
  NA_character_
}

# ---- predicate evaluation (filters & checks) --------------------------------

.sfw_truthy <- function(x) {
  if (is.logical(x)) return(!is.na(x) & x)
  v <- toupper(trimws(as.character(x)))
  !is.na(v) & v %in% c("X", "TRUE", "T", "1", "Y", "YES")
}

.sfw_test <- function(x, op, values) {
  norm <- function(v) if (is.character(v)) toupper(trimws(v)) else v
  switch(op,
    "in"       = norm(x) %in% norm(values),
    "not_in"   = !(norm(x) %in% norm(values)),
    "=="       = x == values,
    "!="       = x != values,
    ">"        = x >  values,
    ">="       = x >= values,
    "<"        = x <  values,
    "<="       = x <= values,
    "between"  = x >= values[[1L]] & x <= values[[2L]],
    "is_true"  = .sfw_truthy(x),
    "is_false" = !.sfw_truthy(x),
    stop("Unsupported op: ", op)
  )
}

.sfw_filter_payload <- function(dots) {
  if (!is.null(dots$expr)) {
    if (!is.character(dots$expr) || length(dots$expr) != 1L || !nzchar(dots$expr))
      stop("`expr` must be a single non-empty string.")
    return(list(column = NA_character_, op = NA_character_, values = NULL,
                expr = dots$expr))
  }
  column <- dots$column
  if (is.null(column) || !is.character(column) || length(column) != 1L || !nzchar(column))
    stop("filter/check needs a single `column` (or an `expr` string).")
  op <- dots$op %||% "in"
  if (!op %in% .SFW_OPS) stop("`op` must be one of: ", paste(.SFW_OPS, collapse = ", "))
  values <- dots$values
  if (op %in% c("is_true", "is_false")) values <- NULL
  else if (op == "between") { if (length(values) != 2L) stop("`between` needs length-2 `values`.") }
  else if (op %in% c("==", "!=", ">", ">=", "<", "<=")) {
    if (length(values) != 1L) stop("`", op, "` needs length-1 `values`.")
  } else if (is.null(values) || !length(values)) stop("`", op, "` needs `values`.")
  list(column = column, op = op, values = values, expr = NULL)
}

.sfw_label_payload <- function(dots) {
  if (!is.null(dots$map)) {
    m <- dots$map
    if (is.data.frame(m)) {
      if (ncol(m) < 2L) stop("label `map` data frame needs id and value columns.")
      v <- stats::setNames(m[[2L]], as.character(m[[1L]]))
    } else {
      v <- m
      if (is.null(names(v))) stop("label `map` must be named by id.")
    }
    col <- dots$label %||% dots$column
    if (is.null(col)) stop("label rule needs `label` (the derived column name).")
  } else if (!is.null(dots$from)) {
    from <- dots$from; keys <- dots$keys; label <- dots$label
    if (!is.data.frame(from) || is.null(keys) || is.null(label))
      stop("label from-source needs `from`, `keys`, and `label`.")
    if (!all(c(keys, label) %in% names(from)))
      stop("`from` must contain the `keys` and `label` columns.")
    v <- stats::setNames(from[[label]], as.character(from[[keys]]))
    col <- label
  } else stop("label rule needs `map`, or (`from`, `keys`, `label`).")
  list(column = col, map = v)
}

# ---- construction & keys ----------------------------------------------------

#' Create a sample frame
#'
#' A sample frame (`sfw`) is a free-standing registry of keys and typed rules
#' that specifies which rows and columns belong in a dataset. It applies to, and
#' validates against, any data frame. See [add_rule()] for the rule types and
#' [apply_sfw()] to realize them.
#'
#' Default entity and time keys are registered from `entity`/`time`; add a
#' filing-level key with [add_key()]. Named `...` are convenience filters
#' (`state = "GA"`, `years = 2020:2022`).
#'
#' @param name Project/panel name (used for identification and logging).
#' @param entity Entity (organization) key column. Default `"EIN2"`. `NULL` to
#'   register none.
#' @param time Time key column. Default `"TAX_YEAR"`. `NULL` to register none.
#' @param record Optional filing-level (`unique_record`) key column, e.g.
#'   `"OBJECTID"`.
#' @param source Optional data-source description stored in metadata.
#' @param ... Convenience filters lowered into filter rules.
#' @return An object of class `sfw`.
#' @export
create_sfw <- function(name, entity = "EIN2", time = "TAX_YEAR",
                       record = NULL, source = NA_character_, ...) {
  if (missing(name) || !is.character(name) || length(name) != 1L)
    stop("`name` is required and must be a single string.")
  sfw <- structure(list(
    meta = list(name = trimws(name), source = source, created = .sfw_time(),
                updated = .sfw_time(), pkg_version = .sfw_pkg_version()),
    keys = list(), rules = list(), policy = list()
  ), class = "sfw")
  if (!is.null(entity)) sfw <- add_key(sfw, "entity", "entity", entity)
  if (!is.null(time))   sfw <- add_key(sfw, "time", "time", time)
  if (!is.null(record)) sfw <- add_key(sfw, "record", "unique_record", record)
  dots <- list(...)
  for (nm in names(dots)) sfw <- .sfw_sugar_filter(sfw, nm, dots[[nm]])
  sfw
}

#' Register a key on a sample frame
#'
#' Keys are structural columns that other operations reference. There is one key
#' per `type`; re-registering a type replaces it.
#'
#' @param sfw A sample frame.
#' @param name Human-readable key name.
#' @param type Key role: `"entity"`, `"time"`, `"unique_record"` (or a custom
#'   role).
#' @param var The column name.
#' @return The updated sample frame.
#' @seealso [get_keys()]
#' @export
add_key <- function(sfw, name, type, var) {
  .sfw_check(sfw)
  if (!is.character(type) || length(type) != 1L) stop("`type` must be a single string.")
  key <- list(name = name, type = type, var = var)
  idx <- which(vapply(sfw$keys, function(k) identical(k$type, type), logical(1L)))
  if (length(idx)) sfw$keys[[idx[1L]]] <- key else sfw$keys[[length(sfw$keys) + 1L]] <- key
  .sfw_touch(sfw)
}

#' @rdname add_key
#' @export
get_keys <- function(sfw) {
  .sfw_check(sfw)
  if (!length(sfw$keys))
    return(data.frame(name = character(), type = character(), var = character(),
                      stringsAsFactors = FALSE))
  do.call(rbind, lapply(sfw$keys, function(k) data.frame(
    name = k$name, type = k$type, var = k$var, stringsAsFactors = FALSE)))
}

.sfw_sugar_filter <- function(sfw, name, values) {
  a <- .SFW_ALIASES[[tolower(name)]]
  if (is.null(a)) { col <- name; op <- "in" } else {
    col <- a$col; op <- a$op
    if (identical(col, "@time")) col <- .sfw_key(sfw, "time")
    if (identical(col, "@id"))   col <- .sfw_key(sfw, "entity")
  }
  add_rule(sfw, name = paste0("filter:", col), type = "filter",
           column = col, op = op, values = values)
}

# ---- rules ------------------------------------------------------------------

.sfw_auto_name <- function(sfw, type) {
  k <- sum(vapply(sfw$rules, function(r) identical(r$type, type), logical(1L)))
  paste0(type, "_", k + 1L)
}

#' Add or replace a rule on a sample frame
#'
#' Appends a typed rule, or replaces the rule with the same `name` (upsert). The
#' payload arguments depend on `type`:
#' \describe{
#'   \item{`filter`, `check`}{`column`, `op`, `values` (structured) **or**
#'     `expr` (a predicate string). `op` in `in`, `not_in`, `==`, `!=`, `>`,
#'     `>=`, `<`, `<=`, `between`, `is_true`, `is_false`.}
#'   \item{`subset`}{`subset` -- a vector of entity ids to keep (captured).}
#'   \item{`label`}{`map` (an id-named vector) or `from` (a data frame) with
#'     `keys` and `label` column names; `label` also names the derived column.}
#'   \item{`select`}{`vars`, `scope`, `tables`, `drop` (resolved via
#'     [field_concordance]).}
#'   \item{`dedup`}{`group`, `partial`, `amended`, `timestamp` column overrides
#'     for [deduplicate()].}
#'   \item{`refresh`}{`fn` -- a function taking and returning a data frame.}
#'   \item{`view`}{`rows`, `cols`, `value`, `fun` -- a crosstab/tapply summary.}
#'   \item{`function`}{`value`/`code` (a string) or `fn` (a function).}
#' }
#'
#' @param sfw A sample frame.
#' @param name Rule name. Empty/`NULL` auto-generates `<type>_<n>`. An existing
#'   name replaces that rule.
#' @param type One of the rule types above.
#' @param ... Type-specific payload (see Details).
#' @return The updated sample frame.
#' @seealso [update_rule()], [get_rules()], [apply_sfw()].
#' @export
add_rule <- function(sfw, name = NULL, type, ...) {
  .sfw_check(sfw)
  if (missing(type) || length(type) != 1L || !type %in% .SFW_RULE_TYPES)
    stop("`type` must be one of: ", paste(.SFW_RULE_TYPES, collapse = ", "))
  dots <- list(...)
  payload <- switch(type,
    filter = ,
    check  = .sfw_filter_payload(dots),
    subset = list(ids = as.character(dots$subset %||% dots$ids %||%
                                       stop("subset rule needs `subset`."))),
    label  = .sfw_label_payload(dots),
    select = Filter(Negate(is.null),
                    list(vars = dots$vars, scope = dots$scope,
                         tables = dots$tables, drop = dots$drop)),
    dedup  = dots[intersect(names(dots),
                            c("group", "partial", "amended", "timestamp"))],
    refresh = { if (!is.function(dots$fn)) stop("refresh rule needs `fn` (a function).")
                list(fn = dots$fn) },
    view   = Filter(Negate(is.null),
                    list(rows = dots$rows, cols = dots$cols,
                         value = dots$value, fun = dots$fun %||% "length")),
    "function" = { code <- dots$value %||% dots$code
                   if (is.null(code) && is.null(dots$fn))
                     stop("function rule needs `value`/`code` or `fn`.")
                   list(code = code, fn = dots$fn) }
  )
  nm <- if (is.null(name) || !nzchar(name)) .sfw_auto_name(sfw, type) else name
  rule <- c(list(name = nm, type = type, active = TRUE), payload)
  idx <- which(vapply(sfw$rules, function(r) identical(r$name, nm), logical(1L)))
  if (length(idx)) sfw$rules[[idx[1L]]] <- rule
  else sfw$rules[[length(sfw$rules) + 1L]] <- rule
  .sfw_touch(sfw)
}

#' Update, drop, or list sample-frame rules
#'
#' @param sfw A sample frame.
#' @param name Rule name to update or drop.
#' @param ... Payload fields to overwrite on the named rule (same as
#'   [add_rule()] for its type).
#' @param drop If `TRUE`, remove the named rule instead of updating it.
#' @return The updated sample frame, or a data frame for `get_rules()`.
#' @name sfw_rules
NULL

#' @rdname sfw_rules
#' @export
update_rule <- function(sfw, name, ..., drop = FALSE) {
  .sfw_check(sfw)
  idx <- which(vapply(sfw$rules, function(r) identical(r$name, name), logical(1L)))
  if (!length(idx)) stop("No rule named: ", name)
  if (isTRUE(drop)) { sfw$rules[[idx[1L]]] <- NULL; return(.sfw_touch(sfw)) }
  r <- sfw$rules[[idx[1L]]]
  base <- r[setdiff(names(r), c("name", "type", "active"))]
  merged <- utils::modifyList(base, list(...))
  sfw$rules[[idx[1L]]] <- NULL
  do.call(add_rule, c(list(sfw = sfw, name = name, type = r$type), merged))
}

#' @rdname sfw_rules
#' @export
remove_rule <- function(sfw, name) update_rule(sfw, name, drop = TRUE)

.sfw_rule_detail <- function(r) {
  switch(r$type,
    filter = , check = if (!is.null(r$expr)) paste0("expr: ", r$expr) else
      paste(r$column, r$op, paste(utils::head(as.character(r$values), 4L), collapse = ",")),
    subset = paste0(length(r$ids), " ids"),
    label  = paste0("-> ", r$column, " (", length(r$map), " ids)"),
    select = paste(c(
      if (!is.null(r$scope)) paste0("scope=", paste(r$scope, collapse = ",")),
      if (!is.null(r$tables)) paste0("tables=", paste(r$tables, collapse = ",")),
      if (!is.null(r$vars)) paste0("vars=", length(r$vars)),
      if (!is.null(r$drop)) paste0("drop=", length(r$drop))), collapse = "; "),
    dedup  = "one per entity-time",
    refresh = "recompute fn",
    view   = paste0(r$rows %||% "", if (!is.null(r$cols)) paste0(" x ", r$cols) else ""),
    "function" = if (!is.null(r$fn)) "fn" else "code",
    ""
  )
}

#' @rdname sfw_rules
#' @export
get_rules <- function(sfw) {
  .sfw_check(sfw)
  if (!length(sfw$rules))
    return(data.frame(name = character(), type = character(),
                      active = logical(), detail = character(),
                      stringsAsFactors = FALSE))
  do.call(rbind, lapply(sfw$rules, function(r) data.frame(
    name = r$name, type = r$type, active = isTRUE(r$active),
    detail = .sfw_rule_detail(r), stringsAsFactors = FALSE)))
}

#' Classify panel membership and store it as label rules
#'
#' Runs [panel_describe()] on `df` and adds two `label` rules keyed by entity:
#' `panel_type` (`persistent`/`entrant`/`exit`/`transient`/`empty`) and
#' `panel_spell` (`seamless`/`segmented`). Filter on them via, e.g.,
#' `apply_sfw(df, sfw, panel_type = "persistent")`.
#'
#' @param sfw A sample frame.
#' @param df A panel data frame with the frame's entity and time key columns.
#' @param method Classifier to use. Currently `"describe"`.
#' @return The updated sample frame.
#' @export
classify_panel <- function(sfw, df, method = c("describe")) {
  .sfw_check(sfw)
  if (!is.data.frame(df)) stop("`df` must be a data.frame.")
  method <- match.arg(method)
  entity <- .sfw_key(sfw, "entity"); time <- .sfw_key(sfw, "time")
  s <- panel_describe(df, time = time, id = entity, print = FALSE)
  cls <- attr(s, "classification")
  ids <- as.character(cls[[entity]])
  sfw <- add_rule(sfw, "panel_type", "label", label = "panel_type",
                  map = stats::setNames(as.character(cls$panel_type), ids))
  sfw <- add_rule(sfw, "panel_spell", "label", label = "panel_spell",
                  map = stats::setNames(as.character(cls$panel_spell), ids))
  .sfw_touch(sfw)
}

# ---- meta, policy, functions ------------------------------------------------

#' Metadata, policies, and archived functions on a sample frame
#'
#' @param sfw A sample frame.
#' @param name Function rule name (`add_function`).
#' @param value,fn A function body string (`value`) or a function object (`fn`).
#' @param ... Named metadata (`add_meta`) or named policies (`set_policy`).
#' @return The updated sample frame.
#' @name sfw_config
NULL

#' @rdname sfw_config
#' @export
add_meta <- function(sfw, ...) {
  .sfw_check(sfw); m <- list(...)
  for (nm in names(m)) sfw$meta[[nm]] <- m[[nm]]
  .sfw_touch(sfw)
}

#' @rdname sfw_config
#' @export
set_policy <- function(sfw, ...) {
  .sfw_check(sfw); p <- list(...)
  for (nm in names(p)) sfw$policy[[nm]] <- p[[nm]]
  .sfw_touch(sfw)
}

#' @rdname sfw_config
#' @export
add_function <- function(sfw, name, value = NULL, fn = NULL)
  add_rule(sfw, name = name, type = "function", value = value, fn = fn)

# ---- column resolution ------------------------------------------------------

.sfw_expand_tables <- function(tables, fc) {
  all_tables <- unique(fc$rdb_table)
  res <- character(0)
  for (t in tables) {
    tu <- toupper(trimws(t))
    if (grepl("^P[0-9]{2}$", tu))
      res <- c(res, all_tables[grepl(paste0("-", tu, "-"), all_tables)])
    else res <- c(res, all_tables[startsWith(toupper(all_tables), tu)])
  }
  unique(res)
}

.sfw_resolve_columns <- function(cs, df_names) {
  fc <- .field_concordance()
  dict_vars <- fc$variable_name
  hd_vars   <- fc$variable_name[fc$variable_scope == "HD"]
  form_vals <- c("both", "990", "990EZ", "all")
  scope_vars <- if (is.null(cs$scope)) dict_vars else if (all(cs$scope %in% form_vals))
    unique(unlist(lapply(cs$scope, fields_in_scope), use.names = FALSE)) else
      fc$variable_name[fc$variable_scope %in% toupper(cs$scope)]
  table_vars <- if (is.null(cs$tables)) dict_vars else
    fc$variable_name[fc$rdb_table %in% .sfw_expand_tables(cs$tables, fc)]
  keep <- union(hd_vars, intersect(scope_vars, table_vars))
  if (!is.null(cs$keep)) keep <- union(keep, cs$keep)
  custom_cols <- setdiff(df_names, dict_vars)
  final <- union(intersect(df_names, keep), custom_cols)
  if (!is.null(cs$drop)) {
    final <- setdiff(final, cs$drop)
    final <- union(final, intersect(df_names, hd_vars))
  }
  intersect(df_names, final)
}

# ---- apply / conform --------------------------------------------------------

.sfw_label_maps <- function(sfw) {
  out <- list()
  for (r in sfw$rules)
    if (identical(r$type, "label") && isTRUE(r$active)) out[[r$column]] <- r$map
  out
}

.sfw_eval_predicate <- function(df, rule, entity, labels) {
  if (!is.null(rule$expr)) {
    val <- tryCatch(eval(parse(text = rule$expr), envir = df),
                    error = function(e) {
                      warning("expr rule '", rule$name, "' failed: ",
                              conditionMessage(e), call. = FALSE); NULL })
    if (is.null(val)) return(NULL)
    val <- as.logical(val); val[is.na(val)] <- FALSE; return(val)
  }
  col <- rule$column
  if (col %in% names(df)) x <- df[[col]]
  else if (col %in% names(labels)) x <- unname(labels[[col]][as.character(df[[entity]])])
  else return(NULL)
  keep <- .sfw_test(x, rule$op, rule$values)
  keep[is.na(keep)] <- FALSE
  as.logical(keep)
}

.sfw_apply_dedup <- function(df, sfw, rule) {
  args <- list(data = df, id = .sfw_key(sfw, "entity"),
               year = .sfw_key(sfw, "time"), verbose = FALSE)
  for (k in c("group", "partial", "amended", "timestamp"))
    if (!is.null(rule[[k]])) args[[k]] <- rule[[k]]
  do.call(deduplicate, args)
}

.sfw_run_checks <- function(df, checks, entity, labels) {
  if (!length(checks)) return(NULL)
  do.call(rbind, lapply(checks, function(r) {
    keep <- .sfw_eval_predicate(df, r, entity, labels)
    if (is.null(keep))
      data.frame(check = r$name, n = nrow(df), pass = NA_integer_,
                 fail = NA_integer_, ok = NA, note = "column absent",
                 stringsAsFactors = FALSE)
    else data.frame(check = r$name, n = length(keep), pass = sum(keep),
                    fail = sum(!keep), ok = all(keep), note = "",
                    stringsAsFactors = FALSE)
  }))
}

.sfw_compute_view <- function(df, r) {
  if (!is.null(r$rows) && !is.null(r$cols)) {
    if (!all(c(r$rows, r$cols) %in% names(df))) return(NULL)
    table(df[[r$rows]], df[[r$cols]])
  } else if (!is.null(r$rows)) {
    if (!r$rows %in% names(df)) return(NULL)
    if (!is.null(r$value) && r$value %in% names(df))
      tapply(df[[r$value]], df[[r$rows]], match.fun(r$fun %||% "length"))
    else table(df[[r$rows]])
  } else NULL
}

#' Apply a sample frame to a data frame
#'
#' Runs the frame's active rules in phase order -- `subset`, `filter`, `dedup`,
#' `refresh`, then `select` -- recording a per-step manifest as the `"sfw_steps"`
#' attribute. `check` and `view` rules are evaluated and attached as
#' `"sfw_checks"` / `"sfw_views"` without altering the data. Ad-hoc `...` filters
#' (e.g. `panel_type = "persistent"`) apply on top of the stored rules.
#'
#' @param df A data frame.
#' @param sfw A sample frame.
#' @param ... Ad-hoc convenience filters.
#' @param columns Apply `select` rules? Default `TRUE`.
#' @param checks Evaluate `check`/`view` rules? Default `TRUE`.
#' @param verbose Print a one-line summary.
#' @return The filtered/selected data frame, with manifest attributes.
#' @export
apply_sfw <- function(df, sfw, ..., columns = TRUE, checks = TRUE, verbose = TRUE) {
  .sfw_check(sfw)
  if (!is.data.frame(df)) stop("`df` must be a data.frame.")
  entity <- .sfw_key(sfw, "entity")
  labels <- .sfw_label_maps(sfw)
  steps <- list()
  rec <- function(step, crit, r0, c0, r1, c1)
    steps[[length(steps) + 1L]] <<- data.frame(
      step = step, criteria = crit, rows_before = r0, rows_after = r1,
      cols_before = c0, cols_after = c1, stringsAsFactors = FALSE)

  active <- Filter(function(r) isTRUE(r$active), sfw$rules)
  extra <- list(...)
  for (nm in names(extra))
    active[[length(active) + 1L]] <-
      c(list(name = paste0("adhoc:", nm), type = "filter", active = TRUE),
        .sfw_filter_payload(.sfw_adhoc_spec(sfw, nm, extra[[nm]])))
  of_type <- function(t) Filter(function(r) identical(r$type, t), active)

  for (r in of_type("subset")) {
    r0 <- nrow(df); c0 <- ncol(df)
    df <- df[as.character(df[[entity]]) %in% r$ids, , drop = FALSE]
    rec(paste0("subset: ", r$name), paste0(length(r$ids), " ids"),
        r0, c0, nrow(df), ncol(df))
  }
  for (r in of_type("filter")) {
    r0 <- nrow(df); c0 <- ncol(df)
    keep <- .sfw_eval_predicate(df, r, entity, labels)
    if (is.null(keep)) {
      if (verbose) message("apply_sfw: skipped '", r$name, "' (column absent)")
      next
    }
    df <- df[keep, , drop = FALSE]
    rec(paste0("filter: ", r$name), .sfw_rule_detail(r), r0, c0, nrow(df), ncol(df))
  }
  for (r in of_type("dedup")) {
    r0 <- nrow(df); c0 <- ncol(df)
    df <- .sfw_apply_dedup(df, sfw, r)
    rec(paste0("dedup: ", r$name), "one per entity-time", r0, c0, nrow(df), ncol(df))
  }
  for (r in of_type("refresh")) {
    r0 <- nrow(df); c0 <- ncol(df)
    df <- r$fn(df)
    if (!is.data.frame(df)) stop("refresh '", r$name, "' must return a data.frame.")
    rec(paste0("refresh: ", r$name), "recompute", r0, c0, nrow(df), ncol(df))
  }
  sels <- of_type("select")
  if (isTRUE(columns) && length(sels)) {
    r0 <- nrow(df); c0 <- ncol(df)
    cs <- list(
      scope  = unique(unlist(lapply(sels, `[[`, "scope"))),
      tables = unique(unlist(lapply(sels, `[[`, "tables"))),
      keep   = unique(unlist(lapply(sels, `[[`, "vars"))),
      drop   = unique(unlist(lapply(sels, `[[`, "drop"))))
    cs <- lapply(cs, function(x) if (length(x)) x else NULL)
    df <- df[, .sfw_resolve_columns(cs, names(df)), drop = FALSE]
    rec("select", "column selection", r0, c0, nrow(df), ncol(df))
  }

  rownames(df) <- NULL
  attr(df, "sfw_steps") <- if (length(steps)) do.call(rbind, steps) else NULL
  if (isTRUE(checks)) {
    attr(df, "sfw_checks") <- .sfw_run_checks(df, of_type("check"), entity, labels)
    vs <- of_type("view")
    if (length(vs))
      attr(df, "sfw_views") <- stats::setNames(
        lapply(vs, function(r) .sfw_compute_view(df, r)),
        vapply(vs, function(r) r$name, character(1L)))
  }
  if (verbose) message("apply_sfw: ", nrow(df), " rows x ", ncol(df), " cols")
  df
}

.sfw_adhoc_spec <- function(sfw, name, values) {
  a <- .SFW_ALIASES[[tolower(name)]]
  col <- if (is.null(a)) name else {
    c0 <- a$col
    if (identical(c0, "@time")) .sfw_key(sfw, "time")
    else if (identical(c0, "@id")) .sfw_key(sfw, "entity") else c0
  }
  list(column = col, op = "in", values = values)
}

#' Run a sample frame's check rules
#'
#' @param df A data frame.
#' @param sfw A sample frame.
#' @param verbose Print the results.
#' @return Invisibly, a data frame of check results.
#' @export
apply_check <- function(df, sfw, verbose = TRUE) {
  .sfw_check(sfw)
  if (!is.data.frame(df)) stop("`df` must be a data.frame.")
  checks <- Filter(function(r) identical(r$type, "check") && isTRUE(r$active), sfw$rules)
  res <- .sfw_run_checks(df, checks, .sfw_key(sfw, "entity"), .sfw_label_maps(sfw))
  if (is.null(res))
    res <- data.frame(check = character(), n = integer(), pass = integer(),
                      fail = integer(), ok = logical(), note = character(),
                      stringsAsFactors = FALSE)
  if (verbose) print(res, row.names = FALSE)
  invisible(res)
}

#' Check whether a data frame conforms to a sample frame
#'
#' Verifies that no row violates any `subset`/`filter` rule, that key columns are
#' present, and reports `check` rules. Use it to enforce the "contract" at any
#' point.
#'
#' @param df A data frame.
#' @param sfw A sample frame.
#' @param verbose Print a summary.
#' @return Invisibly, a list: `conformant`, `rows_total`, `rows_violating`,
#'   `missing_keys`, `checks`.
#' @export
conform <- function(df, sfw, verbose = TRUE) {
  .sfw_check(sfw)
  if (!is.data.frame(df)) stop("`df` must be a data.frame.")
  entity <- .sfw_key(sfw, "entity"); time <- .sfw_key(sfw, "time")
  labels <- .sfw_label_maps(sfw)
  missing_keys <- setdiff(c(entity, time), names(df))
  missing_keys <- missing_keys[!is.na(missing_keys)]
  keep <- rep(TRUE, nrow(df))
  for (r in sfw$rules) {
    if (!isTRUE(r$active)) next
    if (identical(r$type, "subset"))
      keep <- keep & as.character(df[[entity]]) %in% r$ids
    else if (identical(r$type, "filter")) {
      k <- .sfw_eval_predicate(df, r, entity, labels)
      if (!is.null(k)) keep <- keep & k
    }
  }
  viol <- sum(!keep)
  checks <- .sfw_run_checks(df, Filter(function(r)
    identical(r$type, "check") && isTRUE(r$active), sfw$rules), entity, labels)
  ok <- viol == 0L && length(missing_keys) == 0L &&
    (is.null(checks) || all(checks$ok %in% c(TRUE, NA)))
  if (verbose)
    message("conform: ", if (ok) "OK" else "NONCONFORMING", " (", viol,
            " violating row(s)",
            if (length(missing_keys))
              paste0(", missing keys: ", paste(missing_keys, collapse = ", ")) else "",
            ")")
  invisible(list(conformant = ok, rows_total = nrow(df), rows_violating = viol,
                 missing_keys = missing_keys, checks = checks))
}

# ---- print / summary --------------------------------------------------------

#' @export
print.sfw <- function(x, ...) {
  cat("<sfw>  ", x$meta$name, "\n", sep = "")
  cat("  keys:\n")
  for (k in x$keys)
    cat("    - ", k$type, ": ", k$var, "  (", k$name, ")\n", sep = "")
  cat("  rules: ", length(x$rules), "\n", sep = "")
  for (r in x$rules)
    cat("    - [", r$type, "] ", r$name,
        if (!isTRUE(r$active)) " (inactive)" else "", "\n", sep = "")
  if (length(x$policy))
    cat("  policy: ", paste(names(x$policy), collapse = ", "), "\n", sep = "")
  invisible(x)
}

#' @export
summary.sfw <- function(object, ...) {
  print(object)
  if (length(object$rules)) {
    cat("\nrules:\n")
    print(get_rules(object), row.names = FALSE)
  }
  invisible(get_rules(object))
}
