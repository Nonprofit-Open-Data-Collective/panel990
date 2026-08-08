# =============================================================================
#  sample-frame.R
#  A free-standing, structured specification object ("sample frame") that stores
#  reusable rules -- row filters, column selection, enumerated cohorts, derived
#  classifier labels, and operation policies -- and can be applied to, or checked
#  against, any data frame.
#
#  Design notes:
#   * Filters are generic records: {column, op, values, origin, label}. `origin`
#     is an optional pushdown hint only; a filter applies to any data frame that
#     has `column`. Left NULL, everything still works.
#   * The object is a plain classed list (value semantics): every mutator returns
#     a NEW frame and re-stamps `updated`. Nothing is mutated in place.
#   * Derived labels (e.g. panel type) are stored as id -> value maps and can be
#     filtered on exactly like real columns.
# =============================================================================

.SFW_OPS <- c("in", "not_in", "==", "!=", ">", ">=", "<", "<=",
              "between", "is_true", "is_false", "expr")

# Friendly constructor/sugar aliases -> (column, op). "@id"/"@time" resolve to
# the frame's key columns; BMF aliases match the package's bmf_merge() output.
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

.sfw_time <- function() Sys.time()

.sfw_pkg_version <- function()
  tryCatch(as.character(utils::packageVersion("panel990")),
           error = function(e) NA_character_)

.sfw_check <- function(sfw)
  if (!inherits(sfw, "sample_frame")) stop("`sfw` must be a `sample_frame`.")

.sfw_touch <- function(sfw) { sfw$meta$updated <- .sfw_time(); sfw }

# ---- filter construction / evaluation ---------------------------------------

.sfw_auto_label <- function(column, op, values) {
  if (op == "expr") return(paste0("expr(", substr(as.character(values), 1L, 40L), ")"))
  v <- if (is.null(values)) "" else paste(utils::head(as.character(values), 4L), collapse = ",")
  paste0(column, " ", op, if (nzchar(v)) paste0(" ", v) else "")
}

.sfw_make_filter <- function(column, op = "in", values = NULL,
                             origin = NULL, label = NULL) {
  if (length(op) != 1L || !op %in% .SFW_OPS)
    stop("`op` must be one of: ", paste(.SFW_OPS, collapse = ", "))
  if (op == "expr") {
    if (!is.character(values) || length(values) != 1L || !nzchar(values))
      stop("`expr` filters need a single expression string in `values`.")
    column <- if (is.null(column)) NA_character_ else column
  } else {
    if (is.null(column) || !is.character(column) || length(column) != 1L || !nzchar(column))
      stop("`column` must be a single non-empty name.")
    if (op %in% c("is_true", "is_false")) values <- NULL
    else if (op == "between") {
      if (length(values) != 2L) stop("`between` needs length-2 `values`.")
    } else if (op %in% c("==", "!=", ">", ">=", "<", "<=")) {
      if (length(values) != 1L) stop("`", op, "` needs length-1 `values`.")
    } else if (is.null(values) || !length(values)) {
      stop("`", op, "` needs non-empty `values`.")
    }
  }
  if (is.null(label) || !nzchar(label)) label <- .sfw_auto_label(column, op, values)
  list(column = column, op = op, values = values,
       origin = if (is.null(origin)) NA_character_ else origin, label = label)
}

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

# Returns a logical keep-vector, or NULL when the filter cannot be resolved
# against this data frame (column absent and no matching derived attribute).
.sfw_eval_filter <- function(df, sfw, f) {
  if (f$op == "expr") {
    val <- tryCatch(eval(parse(text = f$values), envir = df),
                    error = function(e) {
                      warning("expr filter failed (", f$values, "): ",
                              conditionMessage(e), call. = FALSE); NULL
                    })
    if (is.null(val)) return(NULL)
    val <- as.logical(val); val[is.na(val)] <- FALSE
    return(val)
  }
  col <- f$column
  if (col %in% names(df)) {
    x <- df[[col]]
  } else if (col %in% names(sfw$attributes)) {
    x <- unname(sfw$attributes[[col]]$values[as.character(df[[sfw$meta$id_col]])])
  } else {
    return(NULL)
  }
  keep <- .sfw_test(x, f$op, f$values)
  keep[is.na(keep)] <- FALSE
  as.logical(keep)
}

.sfw_sugar_filter <- function(sfw, name, values) {
  a <- .SFW_ALIASES[[tolower(name)]]
  if (is.null(a)) { col <- name; op <- "in" } else {
    col <- a$col; op <- a$op
    if (identical(col, "@time")) col <- sfw$meta$time_col
    if (identical(col, "@id"))   col <- sfw$meta$id_col
  }
  set_filter(sfw, column = col, op = op, values = values, label = name)
}

# ---- construction -----------------------------------------------------------

#' Create a sample frame
#'
#' A sample frame is a reusable, free-standing specification of which rows and
#' columns belong in a research dataset, plus derived labels and operation
#' policies. It stores rules as data so they can be applied, checked, logged,
#' and serialized consistently across a workflow.
#'
#' Named arguments in `...` are convenience filters: recognized aliases
#' (`years`, `formtype`, `state`, `county`, `msa`, `ntee`, `ntee_industry`,
#' `subsection`, `eins`) map to their columns; any other name is treated as a
#' literal column with an `in` filter.
#'
#' @param name Required project/panel name (used for logging and identification).
#' @param id_col Organization identifier column. Default `"EIN2"`.
#' @param time_col Panel time column. Default `"TAX_YEAR"`.
#' @param source Optional data-source description recorded in metadata.
#' @param ... Convenience filters, e.g. `state = "GA"`, `years = 2020:2022`.
#' @return A `sample_frame` object.
#' @seealso [add_filter()], [keep_cols()], [apply_sfw()], [conform()].
#' @export
create_sample_frame <- function(name, id_col = "EIN2", time_col = "TAX_YEAR",
                                source = NA_character_, ...) {
  if (missing(name) || !is.character(name) || length(name) != 1L ||
      !nzchar(trimws(name)))
    stop("`name` is required and must be a non-empty character string.")
  sfw <- structure(list(
    meta = list(name = trimws(name), id_col = id_col, time_col = time_col,
                source = source, created = .sfw_time(), updated = .sfw_time(),
                pkg_version = .sfw_pkg_version()),
    filters    = list(),
    cohorts    = list(),
    columns    = list(keep = NULL, scope = NULL, tables = NULL, drop = NULL),
    attributes = list(),
    policy     = list(),
    log        = list()
  ), class = "sample_frame")
  dots <- list(...)
  for (nm in names(dots)) sfw <- .sfw_sugar_filter(sfw, nm, dots[[nm]])
  sfw
}

#' Update a sample frame
#'
#' Returns a new frame with the supplied changes; unspecified fields carry
#' forward. Named `...` arguments are applied as replace-by-column convenience
#' filters (the same aliases as [create_sample_frame()]).
#'
#' @param sfw A `sample_frame`.
#' @param ... Convenience filters to set/replace.
#' @param name,id_col,time_col Optional metadata/key overrides.
#' @return The updated `sample_frame`.
#' @export
update_sample_frame <- function(sfw, ..., name = NULL, id_col = NULL,
                                time_col = NULL) {
  .sfw_check(sfw)
  if (!is.null(name))     sfw$meta$name <- trimws(name)
  if (!is.null(id_col))   sfw$meta$id_col <- id_col
  if (!is.null(time_col)) sfw$meta$time_col <- time_col
  dots <- list(...)
  for (nm in names(dots)) sfw <- .sfw_sugar_filter(sfw, nm, dots[[nm]])
  .sfw_touch(sfw)
}

# ---- row filters ------------------------------------------------------------

#' Row filters for a sample frame
#'
#' Add, replace, remove, list, or clear the row-filter specifications. A filter
#' is a record of `column`, `op`, and `values`; `add_filter()` appends,
#' `set_filter()` replaces any existing filter on the same column.
#'
#' @param sfw A `sample_frame`.
#' @param column Column or derived-attribute name to test (ignored for `expr`).
#' @param op One of `in`, `not_in`, `==`, `!=`, `>`, `>=`, `<`, `<=`, `between`,
#'   `is_true`, `is_false`, `expr`.
#' @param values Operand(s): a vector for `in`/`not_in`, a scalar for
#'   comparisons, length-2 for `between`, an expression string for `expr`.
#' @param origin Optional pushdown hint (`"efile"`, `"bmf"`, `"derived"`); may be
#'   `NULL` -- filters apply to any data frame that has the column.
#' @param label Optional human-readable label used in logs.
#' @param index Integer position(s) to drop (`remove_filter`).
#' @param ids Character vector of identifiers (`set_ids`).
#' @return The updated `sample_frame`, or a data frame for `get_filters()`.
#' @name sample_frame_filters
NULL

#' @rdname sample_frame_filters
#' @export
add_filter <- function(sfw, column = NULL, op = "in", values = NULL,
                       origin = NULL, label = NULL) {
  .sfw_check(sfw)
  spec <- .sfw_make_filter(column, op, values, origin, label)
  sfw$filters[[length(sfw$filters) + 1L]] <- spec
  .sfw_touch(sfw)
}

#' @rdname sample_frame_filters
#' @export
set_filter <- function(sfw, column = NULL, op = "in", values = NULL,
                       origin = NULL, label = NULL) {
  .sfw_check(sfw)
  sfw$filters <- Filter(function(f) is.na(f$column) || !identical(f$column, column),
                        sfw$filters)
  add_filter(sfw, column, op, values, origin, label)
}

#' @rdname sample_frame_filters
#' @export
remove_filter <- function(sfw, column = NULL, label = NULL, index = NULL) {
  .sfw_check(sfw)
  if (!is.null(index)) {
    sfw$filters[index] <- NULL
  } else {
    sfw$filters <- Filter(function(f) !(
      (!is.null(column) && !is.na(f$column) && f$column %in% column) ||
      (!is.null(label) && f$label %in% label)), sfw$filters)
  }
  .sfw_touch(sfw)
}

#' @rdname sample_frame_filters
#' @export
clear_filters <- function(sfw) { .sfw_check(sfw); sfw$filters <- list(); .sfw_touch(sfw) }

#' @rdname sample_frame_filters
#' @export
get_filters <- function(sfw) {
  .sfw_check(sfw)
  if (!length(sfw$filters))
    return(data.frame(column = character(), op = character(), values = character(),
                      origin = character(), label = character(),
                      stringsAsFactors = FALSE))
  do.call(rbind, lapply(sfw$filters, function(f) data.frame(
    column = f$column, op = f$op,
    values = paste(utils::head(as.character(f$values), 6L), collapse = ","),
    origin = f$origin, label = f$label, stringsAsFactors = FALSE)))
}

#' @rdname sample_frame_filters
#' @export
set_ids <- function(sfw, ids)
  set_filter(sfw, column = sfw$meta$id_col, op = "in",
             values = as.character(ids), label = "ids")

# ---- keys, columns, cohorts, policies ---------------------------------------

#' Configure a sample frame's keys, columns, cohorts, and policies
#'
#' @param sfw A `sample_frame`.
#' @param id,time Key column names (`set_keys`).
#' @param vars Explicit variable names to keep (additive; `keep_cols`).
#' @param scope Column scope: form codes `PC`/`EZ`/`PZ`/`HD`/`SG`, or a form
#'   presence value `"both"`/`"990"`/`"990EZ"`/`"all"` (resolved via
#'   [fields_in_scope()]). Header (`HD`) fields are always kept.
#' @param tables Table specs to keep columns from: bare part tokens (`"P01"`) or
#'   `rdb_table` prefixes.
#' @param drop Columns to drop (never drops header/key columns).
#' @param name Cohort name (`add_cohort`).
#' @param ids Character vector of identifiers for the cohort (`add_cohort`).
#' @param rule Deduplication rule/preset passed to downstream steps (`set_dedup`).
#' @param ... Named metadata (`set_meta`) or named policies (`set_policy`).
#' @return The updated `sample_frame`.
#' @name sample_frame_config
NULL

#' @rdname sample_frame_config
#' @export
set_keys <- function(sfw, id = NULL, time = NULL) {
  .sfw_check(sfw)
  if (!is.null(id))   sfw$meta$id_col <- id
  if (!is.null(time)) sfw$meta$time_col <- time
  .sfw_touch(sfw)
}

#' @rdname sample_frame_config
#' @export
set_meta <- function(sfw, ...) {
  .sfw_check(sfw); m <- list(...)
  for (nm in names(m)) sfw$meta[[nm]] <- m[[nm]]
  .sfw_touch(sfw)
}

#' @rdname sample_frame_config
#' @export
keep_cols <- function(sfw, vars = NULL, scope = NULL, tables = NULL, drop = NULL) {
  .sfw_check(sfw)
  if (!is.null(vars))   sfw$columns$keep <- vars
  if (!is.null(scope))  sfw$columns$scope <- scope
  if (!is.null(tables)) sfw$columns$tables <- tables
  if (!is.null(drop))   sfw$columns$drop <- drop
  .sfw_touch(sfw)
}

#' @rdname sample_frame_config
#' @export
add_cohort <- function(sfw, name, ids) {
  .sfw_check(sfw); sfw$cohorts[[name]] <- as.character(ids); .sfw_touch(sfw)
}

#' @rdname sample_frame_config
#' @export
set_dedup <- function(sfw, rule) {
  .sfw_check(sfw); sfw$policy$dedup <- rule; .sfw_touch(sfw)
}

#' @rdname sample_frame_config
#' @export
set_policy <- function(sfw, ...) {
  .sfw_check(sfw); p <- list(...)
  for (nm in names(p)) sfw$policy[[nm]] <- p[[nm]]
  .sfw_touch(sfw)
}

# ---- derived attributes -----------------------------------------------------

#' Derived attributes (class labels) on a sample frame
#'
#' Attach or drop per-organization labels that live in the frame rather than the
#' data. Once attached, an attribute can be filtered on exactly like a column.
#' [classify_panel()] runs [panel_describe()] and stores its labels.
#'
#' @param sfw A `sample_frame`.
#' @param name Attribute name.
#' @param map A named vector (names are ids) or a two-column data frame
#'   (id, value).
#' @param ids Optional ids when `map` is unnamed.
#' @return The updated `sample_frame`.
#' @name sample_frame_attributes
NULL

#' @rdname sample_frame_attributes
#' @export
attach_attribute <- function(sfw, name, map, ids = NULL) {
  .sfw_check(sfw)
  if (is.data.frame(map)) {
    if (ncol(map) < 2L) stop("`map` data frame needs id and value columns.")
    v <- stats::setNames(map[[2L]], as.character(map[[1L]]))
  } else {
    v <- map
    if (is.null(names(v))) {
      if (is.null(ids)) stop("`map` must be named by id, or supply `ids`.")
      names(v) <- as.character(ids)
    }
  }
  sfw$attributes[[name]] <- list(values = v, ids = names(v), computed = .sfw_time())
  .sfw_touch(sfw)
}

#' @rdname sample_frame_attributes
#' @export
drop_attribute <- function(sfw, name) {
  .sfw_check(sfw); sfw$attributes[[name]] <- NULL; .sfw_touch(sfw)
}

#' Classify panel membership and store it on a sample frame
#'
#' Runs [panel_describe()] on `df` and stores two derived attributes keyed by
#' organization id: `panel_type` (`persistent`, `entrant`, `exit`, `transient`,
#' `empty`) and `panel_spell` (`seamless`/`segmented`). Filter on them via, e.g.,
#' `apply_sfw(df, sfw, panel_type = "persistent", spell = "seamless")`.
#'
#' @param sfw A `sample_frame`.
#' @param df A panel data frame containing the frame's id and time columns.
#' @param method Classifier to use. Currently `"describe"`.
#' @return The updated `sample_frame`.
#' @export
classify_panel <- function(sfw, df, method = c("describe")) {
  .sfw_check(sfw)
  if (!is.data.frame(df)) stop("`df` must be a data.frame.")
  method <- match.arg(method)
  id_col <- sfw$meta$id_col; time_col <- sfw$meta$time_col
  s <- panel_describe(df, time = time_col, id = id_col, print = FALSE)
  cls <- attr(s, "classification")
  ids <- as.character(cls[[id_col]])
  sfw <- attach_attribute(sfw, "panel_type",
                          stats::setNames(as.character(cls$panel_type), ids))
  sfw <- attach_attribute(sfw, "panel_spell",
                          stats::setNames(as.character(cls$panel_spell), ids))
  .sfw_touch(sfw)
}

# ---- column resolution ------------------------------------------------------

.sfw_expand_tables <- function(tables, fc) {
  all_tables <- unique(fc$rdb_table)
  res <- character(0)
  for (t in tables) {
    tu <- toupper(trimws(t))
    if (grepl("^P[0-9]{2}$", tu))
      res <- c(res, all_tables[grepl(paste0("-", tu, "-"), all_tables)])
    else
      res <- c(res, all_tables[startsWith(toupper(all_tables), tu)])
  }
  unique(res)
}

.sfw_has_colspec <- function(sfw) {
  cs <- sfw$columns
  !is.null(cs$keep) || !is.null(cs$scope) || !is.null(cs$tables) || !is.null(cs$drop)
}

.sfw_resolve_columns <- function(sfw, df_names) {
  fc <- .field_concordance()
  dict_vars <- fc$variable_name
  hd_vars   <- fc$variable_name[fc$variable_scope == "HD"]
  cs <- sfw$columns

  form_vals <- c("both", "990", "990EZ", "all")
  scope_vars <- if (is.null(cs$scope)) dict_vars else if (all(cs$scope %in% form_vals))
    unique(unlist(lapply(cs$scope, fields_in_scope), use.names = FALSE)) else
      fc$variable_name[fc$variable_scope %in% toupper(cs$scope)]

  table_vars <- if (is.null(cs$tables)) dict_vars else
    fc$variable_name[fc$rdb_table %in% .sfw_expand_tables(cs$tables, fc)]

  keep <- union(hd_vars, intersect(scope_vars, table_vars))
  if (!is.null(cs$keep)) keep <- union(keep, cs$keep)

  custom_cols <- setdiff(df_names, dict_vars)       # user/computed cols kept
  final <- union(intersect(df_names, keep), custom_cols)
  if (!is.null(cs$drop)) {
    final <- setdiff(final, cs$drop)
    final <- union(final, intersect(df_names, hd_vars))  # header never dropped
  }
  intersect(df_names, final)                         # preserve original order
}

# ---- apply & conform --------------------------------------------------------

#' Apply a sample frame to a data frame
#'
#' Applies all stored row filters (and any ad-hoc `...` filters), then the
#' column selection, recording a per-step manifest attached to the result as the
#' `"sfw_steps"` attribute. Ad-hoc `...` filters may reference derived attributes
#' (e.g. `panel_type = "persistent"`). Filters whose column is absent are skipped.
#'
#' @param df A data frame.
#' @param sfw A `sample_frame`.
#' @param ... Ad-hoc convenience filters applied on top of the stored ones.
#' @param cohort Optional named cohort ([add_cohort()]) to restrict ids to.
#' @param columns Apply the column selection? Default `TRUE`.
#' @param verbose Print a one-line summary.
#' @return The filtered data frame, with an `"sfw_steps"` manifest attribute.
#' @export
apply_sfw <- function(df, sfw, ..., cohort = NULL, columns = TRUE, verbose = TRUE) {
  .sfw_check(sfw)
  if (!is.data.frame(df)) stop("`df` must be a data.frame.")
  id_col <- sfw$meta$id_col
  steps <- list()
  rec <- function(step, crit, r0, c0, r1, c1)
    steps[[length(steps) + 1L]] <<- data.frame(
      step = step, criteria = crit, rows_before = r0, rows_after = r1,
      cols_before = c0, cols_after = c1, stringsAsFactors = FALSE)

  fl <- sfw$filters
  extra <- list(...)
  for (nm in names(extra))
    fl[[length(fl) + 1L]] <- .sfw_make_filter(nm, "in", extra[[nm]], NULL, nm)
  if (!is.null(cohort)) {
    ids <- sfw$cohorts[[cohort]]
    if (is.null(ids)) stop("Unknown cohort: ", cohort)
    fl <- c(list(.sfw_make_filter(id_col, "in", ids, NULL,
                                  paste0("cohort:", cohort))), fl)
  }

  for (f in fl) {
    r0 <- nrow(df); c0 <- ncol(df)
    keep <- .sfw_eval_filter(df, sfw, f)
    if (is.null(keep)) {
      if (verbose) message("apply_sfw: skipped '", f$label,
                           "' (column not in data)")
      next
    }
    df <- df[keep, , drop = FALSE]
    rec(paste0("filter: ", f$label), f$label, r0, c0, nrow(df), ncol(df))
  }

  if (isTRUE(columns) && .sfw_has_colspec(sfw)) {
    r0 <- nrow(df); c0 <- ncol(df)
    df <- df[, .sfw_resolve_columns(sfw, names(df)), drop = FALSE]
    rec("columns", "column selection", r0, c0, nrow(df), ncol(df))
  }

  rownames(df) <- NULL
  log_df <- if (length(steps)) do.call(rbind, steps) else NULL
  attr(df, "sfw_steps") <- log_df
  if (verbose)
    message("apply_sfw: ", nrow(df), " rows x ", ncol(df), " cols",
            if (!is.null(log_df)) paste0(" after ", nrow(log_df), " step(s)") else "")
  df
}

#' Check whether a data frame conforms to a sample frame
#'
#' Verifies that no row violates any stored filter and that the key columns are
#' present. Use it to enforce the "contract" at any point in a pipeline.
#'
#' @param df A data frame.
#' @param sfw A `sample_frame`.
#' @param verbose Print a summary.
#' @return Invisibly, a list: `conformant`, `rows_total`, `rows_violating`,
#'   `missing_columns`.
#' @export
conform <- function(df, sfw, verbose = TRUE) {
  .sfw_check(sfw)
  if (!is.data.frame(df)) stop("`df` must be a data.frame.")
  missing_cols <- setdiff(c(sfw$meta$id_col, sfw$meta$time_col), names(df))
  keep <- rep(TRUE, nrow(df))
  for (f in sfw$filters) {
    k <- .sfw_eval_filter(df, sfw, f)
    if (!is.null(k)) keep <- keep & k
  }
  viol <- sum(!keep)
  ok <- viol == 0L && length(missing_cols) == 0L
  if (verbose)
    message("conform: ", if (ok) "OK" else "NONCONFORMING", " (", viol,
            " violating row(s)",
            if (length(missing_cols))
              paste0(", missing: ", paste(missing_cols, collapse = ", ")) else "",
            ")")
  invisible(list(conformant = ok, rows_total = nrow(df),
                 rows_violating = viol, missing_columns = missing_cols))
}

# ---- print / summary --------------------------------------------------------

#' @export
print.sample_frame <- function(x, ...) {
  cat("<sample_frame>\n")
  cat("  name:      ", x$meta$name, "\n", sep = "")
  cat("  keys:      id=", x$meta$id_col, "  time=", x$meta$time_col, "\n", sep = "")
  cat("  updated:   ", format(x$meta$updated, "%Y-%m-%d %H:%M:%S"), "\n", sep = "")
  cat("  filters:   ", length(x$filters), "\n", sep = "")
  for (f in x$filters) cat("    - ", f$label,
                           if (!is.na(f$origin)) paste0("  [", f$origin, "]") else "",
                           "\n", sep = "")
  if (.sfw_has_colspec(x)) cat("  columns:   ", .sfw_col_crit(x), "\n", sep = "")
  if (length(x$attributes)) cat("  attributes: ", paste(names(x$attributes), collapse = ", "), "\n", sep = "")
  if (length(x$cohorts))    cat("  cohorts:   ", paste(names(x$cohorts), collapse = ", "), "\n", sep = "")
  if (length(x$policy))     cat("  policy:    ", paste(names(x$policy), collapse = ", "), "\n", sep = "")
  invisible(x)
}

.sfw_col_crit <- function(sfw) {
  cs <- sfw$columns
  paste(c(
    if (!is.null(cs$scope))  paste0("scope=", paste(cs$scope, collapse = ",")),
    if (!is.null(cs$tables)) paste0("tables=", paste(cs$tables, collapse = ",")),
    if (!is.null(cs$keep))   paste0("keep=", length(cs$keep)),
    if (!is.null(cs$drop))   paste0("drop=", length(cs$drop))
  ), collapse = "; ")
}

#' @export
summary.sample_frame <- function(object, ...) {
  print(object)
  invisible(get_filters(object))
}
