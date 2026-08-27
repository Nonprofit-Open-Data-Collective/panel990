# =============================================================================
#  sample_frame.R
#  Functions for defining, updating, printing, filtering, and logging a
#  reusable sample framework for efile panel datasets.
#
#  Functions exported:
#    sample_frame()               – constructor
#    update_sample_frame()        – non-destructive updater
#    print.sample_frame()         – S3 print method
#    filter_by_sample_frame()     – apply all filters to a data frame
#    log_sample_frame()           – filter + write append-mode manifest log
#
#  Internal objects:
#    .efile_dict_full             – 2,440-row data dictionary (variable + form_type)
#    .efile_dict_filter           – 2,318-row lookup used for column filtering
# =============================================================================


# -----------------------------------------------------------------------------
#  Internal data dictionaries (built from concordance.csv)
# -----------------------------------------------------------------------------

.efile_dict_full <- local({
  d <- utils::read.csv(
    "https://raw.githubusercontent.com/Nonprofit-Open-Data-Collective/irs-efile-master-concordance-file/master/concordance.csv",
    stringsAsFactors = FALSE,
    fileEncoding     = "latin1"
  )
  keep <- c("variable_name","variable_scope","rdb_table","label","description",
            "location_code_family","location_code","form","form_type","form_part")
  d    <- d[ , keep, drop = FALSE ]
  d    <- d[ !duplicated( paste( d$variable_name, d$form_type ) ), ]
  rownames( d ) <- NULL
  d
})

.efile_dict_filter <- local({
  d <- .efile_dict_full[ , c("variable_name","variable_scope","rdb_table"), drop = FALSE ]
  d <- d[ !duplicated( d$variable_name ), ]
  rownames( d ) <- NULL
  d
})


# -----------------------------------------------------------------------------
#  Helpers
# -----------------------------------------------------------------------------

#' Normalise a tables= argument into full rdb_table strings
#'
#' Bare part tokens like "P01" or "P08" are expanded to "F9-P01-*" pattern
#' matching against the dictionary. Schedule prefixes (SA_, SB_, PF_ …) are
#' matched by prefix against rdb_table.
#'
#' @keywords internal
.resolve_tables <- function( tables ) {
  if ( is.null( tables ) ) return( NULL )
  all_tables <- unique( .efile_dict_filter$rdb_table )
  resolved   <- character(0)

  for ( tbl in tables ) {
    tbl_up <- toupper( trimws( tbl ) )

    # bare part token: P01, P08, …
    if ( grepl( "^P[0-9]{2}$", tbl_up ) ) {
      matched <- all_tables[ grepl( paste0( "-", tbl_up, "-" ), all_tables ) ]
      resolved <- c( resolved, matched )
      next
    }

    # full or partial rdb_table string – match by prefix
    matched <- all_tables[ startsWith( all_tables, tbl_up ) ]
    if ( length( matched ) == 0L ) {
      warning( paste0( "No rdb_table entries matched for tables value: '", tbl, "'" ) )
    }
    resolved <- c( resolved, matched )
  }

  unique( resolved )
}


#' Derive the set of dictionary variables that should be kept given a
#' sample_frame's var_scope and tables criteria.
#'
#' Header variables (scope == "HD") are always retained.
#'
#' @keywords internal
.resolve_dict_vars <- function( var_scope, tables ) {
  dd <- .efile_dict_filter

  # always keep HD
  hd_vars <- dd$variable_name[ dd$variable_scope == "HD" ]

  # scope filter
  if ( !is.null( var_scope ) ) {
    scope_vars <- dd$variable_name[ dd$variable_scope %in% toupper( var_scope ) ]
  } else {
    scope_vars <- dd$variable_name
  }

  # table filter
  if ( !is.null( tables ) ) {
    resolved_tables <- .resolve_tables( tables )
    table_vars      <- dd$variable_name[ dd$rdb_table %in% resolved_tables ]
  } else {
    table_vars <- dd$variable_name
  }

  union( hd_vars, intersect( scope_vars, table_vars ) )
}


#' Sanitise a project name into a log filename
#' @keywords internal
.make_log_stem <- function( name ) {
  stem <- gsub( "[[:space:]]+", "_", trimws( name ) )
  paste0( "data_manifest_", stem )
}


#' Format a count with comma separators
#' @keywords internal
.fmt <- function( n ) format( n, big.mark = ",", scientific = FALSE, trim = TRUE )


# -----------------------------------------------------------------------------
#  1.  sample_frame()  –  constructor
# -----------------------------------------------------------------------------

#' Create a sample framework object
#'
#' Defines a reusable set of criteria that can be applied consistently across
#' build, retrieve, and filter steps in a panel analysis workflow.
#'
#' @param name     Required. Free-form project or panel name used to name
#'   logfiles (e.g. `"housing panel 2024"`).
#' @param eins     Character vector of EINs to retain. `NULL` keeps all.
#' @param vars     Character vector of explicit variable names to retain.
#'   `NULL` means no explicit variable list (use `var_scope` / `tables`).
#' @param var_scope Character vector of variable scope codes to retain:
#'   `"PC"`, `"EZ"`, `"PZ"`, `"HD"`, `"SG"`. `NULL` keeps all scopes.
#'   Header variables (`HD`) are always retained regardless of this setting.
#' @param tables   Character vector of table identifiers. Bare part tokens
#'   (`"P01"`, `"P08"`) are expanded to all matching `F9-P0x-*` rdb_tables.
#'   Schedule prefixes (`"SA_"`, `"SB_"`, `"PF_"`) are matched by prefix.
#'   `NULL` keeps all tables.
#' @param form_type Character vector of form types to retain. Default
#'   `c("990","990EZ")`.
#' @param filter_501c Character vector of 501(c) sub-type codes to retain
#'   (e.g. `"3"`, `c("3","4")`). `NULL` keeps all.
#' @param geography_state  Character vector of two-letter state codes. `NULL` keeps all.
#' @param geography_county Character vector of county FIPS codes. `NULL` keeps all.
#' @param geography_msa    Character vector of MSA codes. `NULL` keeps all.
#' @param ntee         Character vector of full NTEE codes. `NULL` keeps all.
#' @param ntee_industry Character vector of NTEE industry/major-group codes. `NULL` keeps all.
#' @param ntee_type    Character vector of NTEE type codes. `NULL` keeps all.
#' @param panel_types  Character vector of panel membership types to retain:
#'   `"balanced"`, `"entrant"`, `"exit"`, `"interloper"`. Applied at
#'   `filter_by_sample_frame()` time via `panel_composition()`. `NULL` keeps all.
#' @param group_returns Logical. If `FALSE` (default), group/consolidated
#'   returns are excluded.
#' @param path Character. Base directory for logfile output. Default is
#'   `getwd()`.
#'
#' @return An object of class `"sample_frame"` (a named list).
#'
#' @export
sample_frame <- function(
    name,
    eins            = NULL,
    vars            = NULL,
    var_scope       = NULL,
    tables          = NULL,
    form_type       = c( "990", "990EZ" ),
    filter_501c     = "3",
    geography_state  = NULL,
    geography_county = NULL,
    geography_msa    = NULL,
    ntee            = NULL,
    ntee_industry   = NULL,
    ntee_type       = NULL,
    panel_types     = NULL,
    group_returns   = FALSE,
    path            = getwd()
) {

  if ( missing( name ) || !is.character( name ) || nchar( trimws( name ) ) == 0L )
    stop( "`name` is required and must be a non-empty character string." )

  if ( !is.null( var_scope ) ) {
    valid_scopes <- c( "PC", "EZ", "PZ", "HD", "SG" )
    bad <- setdiff( toupper( var_scope ), valid_scopes )
    if ( length( bad ) )
      warning( paste0( "Unrecognised var_scope value(s): ", paste( bad, collapse = ", " ) ) )
  }

  if ( !is.null( panel_types ) ) {
    valid_pt <- c( "balanced", "entrant", "exit", "interloper" )
    bad <- setdiff( panel_types, valid_pt )
    if ( length( bad ) )
      warning( paste0( "Unrecognised panel_types value(s): ", paste( bad, collapse = ", " ) ) )
  }

  if ( !is.character( path ) || length( path ) != 1L )
    stop( "`path` must be a single character string." )

  structure(
    list(
      name             = trimws( name ),
      eins             = eins,
      vars             = vars,
      var_scope        = if ( !is.null( var_scope ) ) toupper( var_scope ) else NULL,
      tables           = tables,
      form_type        = form_type,
      filter_501c      = filter_501c,
      geography        = list(
        state  = geography_state,
        county = geography_county,
        msa    = geography_msa
      ),
      ntee             = ntee,
      ntee_industry    = ntee_industry,
      ntee_type        = ntee_type,
      panel_types      = panel_types,
      group_returns    = group_returns,
      path             = path,
      created          = Sys.time(),
      updated          = Sys.time()
    ),
    class = "sample_frame"
  )
}


# -----------------------------------------------------------------------------
#  2.  update_sample_frame()
# -----------------------------------------------------------------------------

#' Update a sample framework object
#'
#' Returns a new `sample_frame` with any supplied arguments overwriting their
#' current values. Arguments not supplied are carried forward unchanged.
#'
#' @param sf      An existing `sample_frame` object.
#' @param ...     Any arguments accepted by `sample_frame()` except `name`
#'   (use `name` explicitly if you want to rename the project).
#' @param name    Optional new project name.
#'
#' @return An updated `sample_frame` object.
#' @export
update_sample_frame <- function( sf, ..., name = NULL ) {

  if ( !inherits( sf, "sample_frame" ) )
    stop( "`sf` must be a `sample_frame` object." )

  args <- list( ... )
  geo_args <- c( "geography_state", "geography_county", "geography_msa" )

  # rebuild geography if any geo arg supplied
  new_geo <- sf$geography
  for ( g in geo_args ) {
    slot <- sub( "geography_", "", g )
    if ( g %in% names( args ) ) new_geo[[ slot ]] <- args[[ g ]]
  }
  args[ geo_args ] <- NULL   # consumed

  # apply remaining args directly
  updatable <- c( "eins","vars","var_scope","tables","form_type","filter_501c",
                  "ntee","ntee_industry","ntee_type","panel_types",
                  "group_returns","path" )

  for ( arg in intersect( names( args ), updatable ) ) {
    sf[[ arg ]] <- args[[ arg ]]
  }

  sf$geography <- new_geo
  if ( !is.null( name ) ) sf$name <- trimws( name )

  if ( !is.null( sf$var_scope ) )
    sf$var_scope <- toupper( sf$var_scope )

  sf$updated <- Sys.time()
  sf
}


# -----------------------------------------------------------------------------
#  3.  print.sample_frame()  –  S3 method
# -----------------------------------------------------------------------------

#' Print a sample_frame object
#'
#' Displays a formatted console summary of all defined criteria. When
#' `var_scope` or `tables` are set, also reports which dictionary variables
#' would be dropped from a hypothetical full-scope dataset.
#'
#' @param x   A `sample_frame` object.
#' @param ...  Ignored.
#' @export
print.sample_frame <- function( x, ... ) {

  .section <- function( label, values, collapse = TRUE ) {
    if ( is.null( values ) || ( is.logical( values ) && !values ) ) {
      cat( sprintf( "  %-20s %s\n", label, "<all / not set>" ) )
    } else if ( is.logical( values ) ) {
      cat( sprintf( "  %-20s %s\n", label, values ) )
    } else if ( collapse ) {
      cat( sprintf( "  %-20s %s\n", label,
                    paste( values, collapse = ", " ) ) )
    } else {
      cat( sprintf( "  %-20s [ %d values ]\n", label, length( values ) ) )
    }
  }

  cat( "\n" )
  cat( "========================================\n" )
  cat( " Sample Frame:", x$name, "\n" )
  cat( "========================================\n" )
  cat( " Created:", format( x$created, "%Y-%m-%d %H:%M:%S" ), "\n" )
  cat( " Updated:", format( x$updated, "%Y-%m-%d %H:%M:%S" ), "\n" )
  cat( " Logfile:", file.path( x$path, paste0( .make_log_stem( x$name ), ".log" ) ), "\n" )
  cat( "\n--- Row Filters ---\n" )
  if ( !is.null( x$eins ) ) {
    cat( sprintf( "  %-20s [ %s EINs ]\n", "eins", .fmt( length( x$eins ) ) ) )
  } else {
    .section( "eins", NULL )
  }
  .section( "form_type",     x$form_type )
  .section( "501(c) type",   x$filter_501c )
  .section( "state",         x$geography$state )
  .section( "county",        x$geography$county )
  .section( "msa",           x$geography$msa )
  .section( "ntee",          x$ntee )
  .section( "ntee_industry", x$ntee_industry )
  .section( "ntee_type",     x$ntee_type )
  .section( "panel_types",   x$panel_types )
  .section( "group_returns", x$group_returns )

  cat( "\n--- Column Filters ---\n" )
  if ( !is.null( x$vars ) ) {
    cat( sprintf( "  %-20s [ %s explicit vars ]\n", "vars", .fmt( length( x$vars ) ) ) )
  } else {
    .section( "vars", NULL )
  }
  .section( "var_scope", x$var_scope )
  .section( "tables",    x$tables )

  # report which dictionary variables would be dropped
  if ( !is.null( x$var_scope ) || !is.null( x$tables ) ) {
    kept      <- .resolve_dict_vars( x$var_scope, x$tables )
    all_vars  <- .efile_dict_filter$variable_name
    dropped   <- setdiff( all_vars, kept )
    n_dropped <- length( dropped )
    n_kept    <- length( kept )
    cat( "\n--- Variable Resolution (dictionary) ---\n" )
    cat( sprintf( "  %-20s %s\n", "dict vars kept",    .fmt( n_kept ) ) )
    cat( sprintf( "  %-20s %s\n", "dict vars dropped", .fmt( n_dropped ) ) )
    if ( n_dropped > 0L && n_dropped <= 20L ) {
      cat( "  Dropped vars:\n" )
      for ( v in dropped ) cat( "    -", v, "\n" )
    } else if ( n_dropped > 20L ) {
      cat( sprintf( "  (use `attr(sf, 'dropped_vars')` to see all %s dropped vars)\n",
                    .fmt( n_dropped ) ) )
      attr( x, "dropped_vars" ) <<- dropped
    }
  }

  cat( "\n" )
  invisible( x )
}


# -----------------------------------------------------------------------------
#  4.  filter_by_sample_frame()
# -----------------------------------------------------------------------------

#' Apply a sample framework's filters to a data frame
#'
#' Applies all non-NULL criteria defined in `sf` to `df` in a consistent
#' order. Filters can be selectively skipped per call via `exclude`.
#'
#' Column filtering uses the intersection of:
#'   1. Explicit `vars` in the sample frame (if defined)
#'   2. Dictionary variables passing `var_scope` and `tables` criteria
#'   3. Custom variables present in `df` but absent from the dictionary
#'      (always retained unless explicitly listed in `vars` and absent
#'      from the df — in which case a warning is issued)
#'
#' Header variables (`HD` scope) are never dropped by column filters.
#'
#' @param df        A data frame to filter.
#' @param sf        A `sample_frame` object.
#' @param id        Name of the EIN/ID column. Default `"EIN2"`.
#' @param time      Name of the time column. Default `"TAX_YEAR"`.
#' @param ein_col   Name of the EIN column in `df` for EIN filtering.
#'   Default `"EIN2"`.
#' @param col_501c  Name of the 501(c) sub-type column. Default `"SUBSECTION"`.
#' @param col_state  Name of the state column. Default `"STATE"`.
#' @param col_county Name of the county FIPS column. Default `"COUNTY"`.
#' @param col_msa    Name of the MSA column. Default `"MSA"`.
#' @param col_ntee   Name of the full NTEE column. Default `"NTEE_CC"`.
#' @param col_ntee_industry Name of the NTEE industry/major-group column.
#'   Default `"NTEE_INDUSTRY"`.
#' @param col_ntee_type     Name of the NTEE type column. Default `"NTEE_TYPE"`.
#' @param col_group_return  Name of the group-return indicator column.
#'   Default `"GROUP_RETURN"`.
#' @param panel_composition_result  Optional output of `panel_composition()`
#'   (with `return_classification = TRUE`). Required if `sf$panel_types` is
#'   set. If `NULL` and `panel_types` is defined, `panel_composition()` is
#'   called internally.
#' @param exclude   Character vector of filter names to skip for this call.
#'   Valid values: `"eins"`, `"form_type"`, `"501c"`, `"geography"`,
#'   `"ntee"`, `"panel_types"`, `"group_returns"`, `"columns"`.
#'
#' @return A filtered data frame.
#' @export
filter_by_sample_frame <- function(
    df,
    sf,
    id                       = "EIN2",
    time                     = "TAX_YEAR",
    ein_col                  = "EIN2",
    col_501c                 = "SUBSECTION",
    col_state                = "STATE",
    col_county               = "COUNTY",
    col_msa                  = "MSA",
    col_ntee                 = "NTEE_CC",
    col_ntee_industry        = "NTEE_INDUSTRY",
    col_ntee_type            = "NTEE_TYPE",
    col_group_return         = "GROUP_RETURN",
    panel_composition_result = NULL,
    exclude                  = character(0)
) {

  if ( !is.data.frame( df ) )            stop( "`df` must be a data.frame." )
  if ( !inherits( sf, "sample_frame" ) ) stop( "`sf` must be a `sample_frame` object." )

  skip <- function( name ) name %in% exclude

  # ── EIN filter ──────────────────────────────────────────────────────────────
  if ( !skip("eins") && !is.null( sf$eins ) ) {
    if ( ein_col %in% names( df ) ) {
      df <- df[ df[[ ein_col ]] %in% sf$eins, , drop = FALSE ]
    } else {
      warning( paste0( "EIN filter skipped: column '", ein_col, "' not found in df." ) )
    }
  }

  # ── Form type filter ─────────────────────────────────────────────────────────
  if ( !skip("form_type") && !is.null( sf$form_type ) ) {
    form_candidates <- c( "FORM_TYPE", "form_type", "FormType" )
    col_form <- intersect( form_candidates, names( df ) )[1]
    if ( !is.na( col_form ) ) {
      df <- df[ df[[ col_form ]] %in% sf$form_type, , drop = FALSE ]
    } else {
      warning( "form_type filter skipped: no form type column found in df." )
    }
  }

  # ── 501(c) filter ────────────────────────────────────────────────────────────
  if ( !skip("501c") && !is.null( sf$filter_501c ) ) {
    if ( col_501c %in% names( df ) ) {
      df <- df[ as.character( df[[ col_501c ]] ) %in% as.character( sf$filter_501c ),
                , drop = FALSE ]
    } else {
      warning( paste0( "501(c) filter skipped: column '", col_501c, "' not found in df." ) )
    }
  }

  # ── Geography filters ────────────────────────────────────────────────────────
  if ( !skip("geography") ) {
    geo_map <- list(
      state  = list( val = sf$geography$state,  col = col_state ),
      county = list( val = sf$geography$county, col = col_county ),
      msa    = list( val = sf$geography$msa,    col = col_msa )
    )
    for ( g in geo_map ) {
      if ( !is.null( g$val ) ) {
        if ( g$col %in% names( df ) ) {
          df <- df[ df[[ g$col ]] %in% g$val, , drop = FALSE ]
        } else {
          warning( paste0( "Geography filter skipped: column '", g$col, "' not found in df." ) )
        }
      }
    }
  }

  # ── NTEE filters ─────────────────────────────────────────────────────────────
  if ( !skip("ntee") ) {
    ntee_map <- list(
      list( val = sf$ntee,          col = col_ntee ),
      list( val = sf$ntee_industry, col = col_ntee_industry ),
      list( val = sf$ntee_type,     col = col_ntee_type )
    )
    for ( n in ntee_map ) {
      if ( !is.null( n$val ) ) {
        if ( n$col %in% names( df ) ) {
          df <- df[ df[[ n$col ]] %in% n$val, , drop = FALSE ]
        } else {
          warning( paste0( "NTEE filter skipped: column '", n$col, "' not found in df." ) )
        }
      }
    }
  }

  # ── Group returns ────────────────────────────────────────────────────────────
  if ( !skip("group_returns") && isFALSE( sf$group_returns ) ) {
    if ( col_group_return %in% names( df ) ) {
      df <- df[ is.na( df[[ col_group_return ]] ) |
                  df[[ col_group_return ]] %in% c( FALSE, 0L, "0", "N", "No", "no" ),
                , drop = FALSE ]
    }
    # if column absent, silently skip — not all datasets carry this flag
  }

  # ── Panel type filter ────────────────────────────────────────────────────────
  if ( !skip("panel_types") && !is.null( sf$panel_types ) ) {
    pc_result <- panel_composition_result

    if ( is.null( pc_result ) ) {
      message( "[ filter_by_sample_frame ] Running panel_composition() for panel_types filter..." )
      pc_result <- panel_composition( df, time = time, id = id,
                                      return_classification = TRUE,
                                      print_table          = FALSE )
    }

    class_df <- .get_panel_classification( pc_result, id = id )
    keep_ids  <- class_df[[ id ]][ class_df$group %in% sf$panel_types ]

    if ( id %in% names( df ) ) {
      df <- df[ df[[ id ]] %in% keep_ids, , drop = FALSE ]
    } else {
      warning( paste0( "panel_types filter skipped: id column '", id, "' not found in df." ) )
    }
  }

  # ── Column filter ────────────────────────────────────────────────────────────
  if ( !skip("columns") &&
       ( !is.null( sf$vars ) || !is.null( sf$var_scope ) || !is.null( sf$tables ) ) ) {

    # dictionary-derived keep set
    dict_keep <- .resolve_dict_vars( sf$var_scope, sf$tables )

    # explicit vars override (intersection with what exists in df)
    if ( !is.null( sf$vars ) ) {
      missing_explicit <- setdiff( sf$vars, names( df ) )
      if ( length( missing_explicit ) )
        warning( paste0( "vars not found in df (ignored): ",
                         paste( missing_explicit, collapse = ", " ) ) )
      dict_keep <- union( dict_keep, intersect( sf$vars, names( df ) ) )
    }

    # custom (non-dictionary) columns in df are retained by default
    all_dict_vars  <- .efile_dict_filter$variable_name
    custom_cols    <- setdiff( names( df ), all_dict_vars )

    final_keep <- union( intersect( names( df ), dict_keep ), custom_cols )
    df <- df[ , final_keep, drop = FALSE ]
  }

  rownames( df ) <- NULL
  df
}


# -----------------------------------------------------------------------------
#  5.  log_sample_frame()
# -----------------------------------------------------------------------------

#' Filter a data frame with a sample framework and write a manifest log
#'
#' Applies each filter step from `sf` sequentially, recording before/after
#' row and column counts at every stage. Appends a timestamped block to both
#' a human-readable `.log` file and a machine-readable `_log.csv` file in
#' `sf$path`. Custom filter and select expressions are also recorded.
#'
#' @param df        A data frame.
#' @param sf        A `sample_frame` object.
#' @param id        ID column name. Default `"EIN2"`.
#' @param time      Time column name. Default `"TAX_YEAR"`.
#' @param custom_filter A named list of dplyr-style filter expressions as
#'   quoted strings, e.g. `list(revenue_positive = "F9_01_REV_TOTAL > 0")`.
#'   Each entry is applied as a `dplyr::filter()` step and recorded in the log.
#' @param custom_select A character vector of column names to retain after all
#'   other filters. Recorded in the log.
#' @param exclude   Filter groups to skip — passed through to
#'   `filter_by_sample_frame()`.
#' @param panel_composition_result  Optional `panel_composition()` output.
#' @param ...       Additional column-name arguments passed to
#'   `filter_by_sample_frame()` (e.g. `col_501c`, `col_state`, etc.).
#'
#' @return The filtered data frame (invisibly).
#' @export
log_sample_frame <- function(
    df,
    sf,
    id                       = "EIN2",
    time                     = "TAX_YEAR",
    custom_filter            = NULL,
    custom_select            = NULL,
    exclude                  = character(0),
    panel_composition_result = NULL,
    ...
) {

  if ( !is.data.frame( df ) )            stop( "`df` must be a data.frame." )
  if ( !inherits( sf, "sample_frame" ) ) stop( "`sf` must be a `sample_frame` object." )

  if ( !dir.exists( sf$path ) )
    dir.create( sf$path, recursive = TRUE )

  stem     <- .make_log_stem( sf$name )
  log_path <- file.path( sf$path, paste0( stem, ".log" ) )
  csv_path <- file.path( sf$path, paste0( stem, "_log.csv" ) )

  run_ts <- format( Sys.time(), "%Y-%m-%d %H:%M:%S" )
  log_lines <- character(0)
  csv_rows  <- list()

  .log <- function( ... ) {
    log_lines <<- c( log_lines, paste0( ... ) )
  }

  .record <- function( step, criteria, rows_before, cols_before,
                        rows_after, cols_after ) {
    rows_dropped <- rows_before - rows_after
    cols_dropped <- cols_before - cols_after
    .log( sprintf( "  %-26s  rows: %s -> %s  (-%s)   cols: %s -> %s  (-%s)",
                   step,
                   .fmt( rows_before ), .fmt( rows_after ), .fmt( rows_dropped ),
                   .fmt( cols_before ), .fmt( cols_after ), .fmt( cols_dropped ) ) )
    csv_rows[[ length(csv_rows) + 1L ]] <<- data.frame(
      run_timestamp = run_ts,
      project       = sf$name,
      step          = step,
      criteria      = criteria,
      rows_before   = rows_before,
      rows_after    = rows_after,
      rows_dropped  = rows_dropped,
      cols_before   = cols_before,
      cols_after    = cols_after,
      cols_dropped  = cols_dropped,
      stringsAsFactors = FALSE
    )
  }

  # ── Header ───────────────────────────────────────────────────────────────────
  .log( "" )
  .log( strrep( "=", 70 ) )
  .log( " Data Manifest: ", sf$name )
  .log( " Run timestamp: ", run_ts )
  .log( strrep( "=", 70 ) )
  .log( sprintf( "  %-26s  rows: %s   cols: %s",
                 "INPUT",
                 .fmt( nrow( df ) ), .fmt( ncol( df ) ) ) )
  .log( "" )

  current <- df

  # ── Helper: one-step filter wrapper ─────────────────────────────────────────
  .apply_step <- function( data, filter_name, criteria_str, exclude_others ) {
    r0 <- nrow( data ); c0 <- ncol( data )
    out <- filter_by_sample_frame(
      df      = data,
      sf      = sf,
      id      = id,
      time    = time,
      exclude = setdiff( c( "eins","form_type","501c","geography",
                             "ntee","panel_types","group_returns","columns" ),
                         filter_name ),
      panel_composition_result = panel_composition_result,
      ...
    )
    .record( filter_name, criteria_str, r0, c0, nrow( out ), ncol( out ) )
    out
  }

  skip <- function( name ) name %in% exclude

  # ── Sequential filter steps ──────────────────────────────────────────────────
  if ( !skip("eins") && !is.null( sf$eins ) ) {
    current <- .apply_step( current, "eins",
                            paste0( .fmt( length( sf$eins ) ), " EINs" ),
                            "eins" )
  }

  if ( !skip("form_type") && !is.null( sf$form_type ) ) {
    current <- .apply_step( current, "form_type",
                            paste( sf$form_type, collapse = ", " ),
                            "form_type" )
  }

  if ( !skip("501c") && !is.null( sf$filter_501c ) ) {
    current <- .apply_step( current, "501c",
                            paste( sf$filter_501c, collapse = ", " ),
                            "501c" )
  }

  if ( !skip("geography") &&
       ( !is.null( sf$geography$state ) ||
         !is.null( sf$geography$county ) ||
         !is.null( sf$geography$msa ) ) ) {
    geo_str <- paste( c(
      if ( !is.null( sf$geography$state ) )
        paste0( "state=", paste( sf$geography$state, collapse="," ) ),
      if ( !is.null( sf$geography$county ) )
        paste0( "county=[", .fmt( length( sf$geography$county ) ), " codes]" ),
      if ( !is.null( sf$geography$msa ) )
        paste0( "msa=[", .fmt( length( sf$geography$msa ) ), " codes]" )
    ), collapse = "; " )
    current <- .apply_step( current, "geography", geo_str, "geography" )
  }

  if ( !skip("ntee") &&
       ( !is.null( sf$ntee ) || !is.null( sf$ntee_industry ) ||
         !is.null( sf$ntee_type ) ) ) {
    ntee_str <- paste( c(
      if ( !is.null( sf$ntee ) )
        paste0( "ntee=[", .fmt( length( sf$ntee ) ), " codes]" ),
      if ( !is.null( sf$ntee_industry ) )
        paste0( "industry=", paste( sf$ntee_industry, collapse="," ) ),
      if ( !is.null( sf$ntee_type ) )
        paste0( "type=", paste( sf$ntee_type, collapse="," ) )
    ), collapse = "; " )
    current <- .apply_step( current, "ntee", ntee_str, "ntee" )
  }

  if ( !skip("group_returns") && isFALSE( sf$group_returns ) ) {
    current <- .apply_step( current, "group_returns", "group_returns=FALSE", "group_returns" )
  }

  if ( !skip("panel_types") && !is.null( sf$panel_types ) ) {
    current <- .apply_step( current, "panel_types",
                            paste( sf$panel_types, collapse = ", " ),
                            "panel_types" )
  }

  if ( !skip("columns") &&
       ( !is.null( sf$vars ) || !is.null( sf$var_scope ) || !is.null( sf$tables ) ) ) {
    current <- .apply_step( current, "columns",
                            paste( c(
                              if ( !is.null( sf$var_scope ) )
                                paste0( "scope=", paste( sf$var_scope, collapse="," ) ),
                              if ( !is.null( sf$tables ) )
                                paste0( "tables=[", length( sf$tables ), " specs]" ),
                              if ( !is.null( sf$vars ) )
                                paste0( "explicit_vars=", length( sf$vars ) )
                            ), collapse="; " ),
                            "columns" )
  }

  # ── Custom filter steps ───────────────────────────────────────────────────────
  if ( !is.null( custom_filter ) ) {
    if ( !is.list( custom_filter ) || is.null( names( custom_filter ) ) )
      stop( "`custom_filter` must be a named list of quoted filter expressions." )

    for ( step_name in names( custom_filter ) ) {
      expr_str <- custom_filter[[ step_name ]]
      r0 <- nrow( current ); c0 <- ncol( current )
      current <- dplyr::filter( current, !!rlang::parse_expr( expr_str ) )
      .record( paste0( "custom_filter: ", step_name ),
               expr_str, r0, c0, nrow( current ), ncol( current ) )
    }
  }

  # ── Custom select ─────────────────────────────────────────────────────────────
  if ( !is.null( custom_select ) ) {
    r0 <- nrow( current ); c0 <- ncol( current )
    missing_sel <- setdiff( custom_select, names( current ) )
    if ( length( missing_sel ) )
      warning( paste0( "custom_select: columns not found (ignored): ",
                       paste( missing_sel, collapse = ", " ) ) )
    keep_sel <- intersect( custom_select, names( current ) )
    current  <- current[ , keep_sel, drop = FALSE ]
    .record( "custom_select",
             paste( custom_select, collapse = ", " ),
             r0, c0, nrow( current ), ncol( current ) )
  }

  # ── Footer ───────────────────────────────────────────────────────────────────
  .log( "" )
  .log( sprintf( "  %-26s  rows: %s   cols: %s",
                 "OUTPUT",
                 .fmt( nrow( current ) ), .fmt( ncol( current ) ) ) )
  .log( strrep( "-", 70 ) )

  # ── Write .log (append) ───────────────────────────────────────────────────────
  cat( paste( log_lines, collapse = "\n" ), "\n",
       file = log_path, append = TRUE )
  message( "[ log_sample_frame ] Log appended: ", log_path )

  # ── Write _log.csv (append) ───────────────────────────────────────────────────
  csv_df       <- do.call( rbind, csv_rows )
  write_header <- !file.exists( csv_path )
  utils::write.table(
    csv_df,
    file      = csv_path,
    sep       = ",",
    row.names = FALSE,
    col.names = write_header,
    append    = TRUE,
    quote     = TRUE
  )
  message( "[ log_sample_frame ] CSV log appended: ", csv_path )

  invisible( current )
}
