# Sample Framework Design Document

**Package context:** IRS efile nonprofit panel analysis toolkit  
**Last updated:** 2026-08-07

---

## 1. Purpose and Motivation

The sample framework system provides a single, reusable specification object that defines which organizations and variables belong in a research dataset. The core problem it solves is **consistency**: in a typical panel-building workflow, the same set of inclusion criteria (organization type, geography, NTEE classification, form type, panel membership) must be applied repeatedly across build, retrieve, filter, and documentation steps. Without a shared specification object, those criteria drift across scripts, producing panels that are difficult to reproduce or audit.

Secondary goals:

- Allow researchers to define criteria once and reference named vectors (e.g. `eins = housing_orgs`) that are captured by value at construction time, surviving downstream object changes.
- Produce a machine-readable and human-readable data manifest log that can be included directly in research publications as a methods appendix.
- Integrate cleanly with the rest of the panel toolkit (`panel_composition()`, `panel_impute_interlopers()`) rather than duplicating their logic.

---

## 2. Key Design Decisions

### 2.1 Object representation: S3 list

The `sample_frame` object is a plain named R list with a custom S3 class. This was chosen over R6 or environment-based reference objects for three reasons:

- **Portability.** It can be saved with `saveRDS()`, passed to any function, and inspected with `str()` without additional dependencies.
- **Immutability by default.** Because it is a value object, passing it to a function does not risk silent mutation. Updates go through `update_sample_frame()`, which returns a new object.
- **Familiarity.** S3 lists are idiomatic in base R and require no knowledge of OOP systems to work with.

### 2.2 Separation of `vars` and `var_scope`

These were originally proposed as a single argument. They were separated because they serve different purposes:

- `vars` — an explicit, user-supplied list of column names to retain. User-defined; not validated against the dictionary.
- `var_scope` — a scope code filter (`"PC"`, `"EZ"`, `"PZ"`, `"HD"`, `"SG"`) applied against the internal efile data dictionary.

The final set of columns kept is the **intersection** of `vars`, `var_scope`, and `tables` (all non-NULL criteria), unioned with custom (non-dictionary) columns present in the data frame, which are always retained by default. This prevents accidental deletion of user-computed variables not in the dictionary.

### 2.3 Header variables are never dropped

Variables with `variable_scope == "HD"` in the efile dictionary (e.g. EIN, tax year, return type) are unconditionally retained regardless of `var_scope` or `tables` settings. These are structural identifiers required for all panel operations.

### 2.4 `tables` argument expansion

The `tables` argument accepts two formats:

- **Bare part tokens** (`"P01"`, `"P08"`) — expanded to all matching `F9-P0x-*` rdb_table strings via the dictionary. This is the common case for researchers working with F990 part-level data.
- **Schedule or format prefixes** (`"SA_"`, `"SB_"`, `"PF_"`) — matched by prefix against the full rdb_table vocabulary. Explicit full rdb_table strings are also accepted.

The expansion happens inside `.resolve_tables()` and is applied at filter time, not at construction time. The `sample_frame` object stores the raw user-supplied values.

### 2.5 `panel_types` is evaluated at filter time

The panel membership classification (`"balanced"`, `"entrant"`, `"exit"`, `"interloper"`) cannot be determined at construction time because it depends on the actual data, and the panel composition can change between pipeline steps (e.g. after imputation with `panel_impute_interlopers()`). Therefore:

- The `sample_frame` stores only the desired membership labels.
- `filter_by_sample_frame()` accepts an optional `panel_composition_result` argument (output of `panel_composition()` with `return_classification = TRUE`).
- If that argument is `NULL` and `panel_types` is defined, `panel_composition()` is called internally on the current data frame at filter time.

### 2.6 Logfile naming and append behavior

Logfiles are named `data_manifest_<project_name>.log` and `data_manifest_<project_name>_log.csv`, where spaces in the project name are replaced with underscores. The `"data_manifest_"` prefix ensures all logfiles sort together in a project directory regardless of project name.

Both files use **append mode**: each run adds a timestamped block rather than overwriting. The CSV file writes a header row only on first creation. This means multiple pipeline runs accumulate in the same file, making it straightforward to compare runs or trace how a dataset evolved over a project's lifetime. Because multiple panels in the same project directory would otherwise share a logfile, the project `name` argument is required and is the primary disambiguator — each panel should have a distinct name.

### 2.7 Custom filters and selects are first-class log entries

`log_sample_frame()` accepts `custom_filter` (a named list of quoted dplyr-style filter expressions) and `custom_select` (a character vector of column names). Each is applied as a discrete pipeline step and recorded in the log with its expression string and before/after dimensions. This means ad-hoc researcher choices — not expressible through the structured sample frame arguments — are still fully documented in the manifest.

### 2.8 `exclude` argument for per-call overrides

Both `filter_by_sample_frame()` and `log_sample_frame()` accept an `exclude` character vector that names filter groups to skip for that specific call. Valid group names are: `"eins"`, `"form_type"`, `"501c"`, `"geography"`, `"ntee"`, `"panel_types"`, `"group_returns"`, `"columns"`. This supports partial application — for example, applying all filters except column selection during an exploratory step — without requiring a separate sample frame object.

---

## 3. The `sample_frame` Object

### 3.1 Constructor signature

```r
sample_frame(
  name,                          # required; drives logfile naming
  eins             = NULL,       # character vector of EINs
  vars             = NULL,       # explicit variable names to keep
  var_scope        = NULL,       # scope codes: "PC", "EZ", "PZ", "HD", "SG"
  tables           = NULL,       # rdb_table specs or bare part tokens
  form_type        = c("990", "990EZ"),
  filter_501c      = "3",        # 501(c) sub-type codes; NULL = keep all
  geography_state  = NULL,       # two-letter state codes
  geography_county = NULL,       # county FIPS codes
  geography_msa    = NULL,       # MSA codes
  ntee             = NULL,       # full NTEE codes
  ntee_industry    = NULL,       # NTEE major-group codes
  ntee_type        = NULL,       # NTEE type codes
  panel_types      = NULL,       # "balanced","entrant","exit","interloper"
  group_returns    = FALSE,
  path             = getwd()     # base directory for logfile output
)
```

### 3.2 Internal structure

The object is a named list with class `"sample_frame"` and the following slots:

| Slot | Type | Notes |
|---|---|---|
| `name` | character(1) | Free-form project label |
| `eins` | character or NULL | Captured by value at construction |
| `vars` | character or NULL | Explicit variable list |
| `var_scope` | character or NULL | Uppercased at construction |
| `tables` | character or NULL | Stored as supplied; expanded at filter time |
| `form_type` | character | Default `c("990","990EZ")` |
| `filter_501c` | character or NULL | Stored as character for safe comparison |
| `geography` | named list | Slots: `state`, `county`, `msa` |
| `ntee` | character or NULL | |
| `ntee_industry` | character or NULL | |
| `ntee_type` | character or NULL | |
| `panel_types` | character or NULL | Evaluated at filter time |
| `group_returns` | logical | |
| `path` | character(1) | Base directory for logs |
| `created` | POSIXct | Set at construction |
| `updated` | POSIXct | Updated by `update_sample_frame()` |

### 3.3 Typical usage pattern

```r
# Define once
sf <- sample_frame(
  name            = "housing panel 2024",
  eins            = housing_orgs,          # pre-defined vector
  var_scope       = c("PC", "HD"),
  tables          = c("P01", "P08", "P09"),
  filter_501c     = "3",
  geography_state = c("AZ", "CA", "NV"),
  ntee_industry   = "L",                   # Housing & Shelter
  panel_types     = c("balanced", "entrant"),
  path            = "output/housing_panel"
)

# Inspect
print(sf)

# Apply to a data frame
df_filtered <- filter_by_sample_frame(df_raw, sf)

# Apply and log
df_final <- log_sample_frame(
  df           = df_raw,
  sf           = sf,
  custom_filter = list(
    revenue_positive = "F9_01_REV_TOTAL > 0"
  )
)

# Update for a sensitivity check
sf_broad <- update_sample_frame(
  sf,
  panel_types = NULL,   # drop panel type restriction
  name        = "housing panel 2024 broad"
)
```

---

## 4. Package Architecture

### 4.1 Exported functions

| Function | Role |
|---|---|
| `sample_frame()` | Constructor. Validates inputs, captures argument values, returns classed list. |
| `update_sample_frame()` | Returns a new `sample_frame` with specified fields overwritten; re-timestamps `updated`. Does not mutate in place. |
| `print.sample_frame()` | S3 method. Console summary of all defined criteria. Reports dictionary variable drop counts when `var_scope` or `tables` are set. |
| `filter_by_sample_frame()` | Applies all non-NULL filters to a data frame in fixed order. Accepts `exclude` for per-call overrides and `panel_composition_result` to avoid redundant recomputation. |
| `log_sample_frame()` | Wraps `filter_by_sample_frame()` step-by-step, recording before/after dimensions at each stage. Appends to `.log` and `_log.csv` in `sf$path`. Accepts `custom_filter` and `custom_select`. |

### 4.2 Internal objects

| Object | Description |
|---|---|
| `.efile_dict_full` | 2,440-row data frame. Unique by `variable_name + form_type`. Columns: `variable_name`, `variable_scope`, `rdb_table`, `label`, `description`, `location_code_family`, `location_code`, `form`, `form_type`, `form_part`. Used for variable lookup and documentation. |
| `.efile_dict_filter` | 2,318-row data frame. Unique by `variable_name` only. Columns: `variable_name`, `variable_scope`, `rdb_table`. Used for all column-filtering logic. |

Both are built lazily at package load time from the canonical concordance CSV hosted at the Nonprofit Open Data Collective GitHub repository.

### 4.3 Internal helper functions

| Function | Role |
|---|---|
| `.resolve_tables(tables)` | Expands bare part tokens (`"P01"`) and schedule prefixes (`"SA_"`) into full `rdb_table` strings matched against the dictionary. |
| `.resolve_dict_vars(var_scope, tables)` | Returns the set of `variable_name` values from `.efile_dict_filter` that pass scope and table criteria. Always unions in HD-scope variables. |
| `.make_log_stem(name)` | Converts a project name to a logfile stem: spaces → underscores, prepend `"data_manifest_"`. |
| `.get_panel_classification(x, id)` | Extracts the classification data frame from a `panel_composition()` result (from attribute or direct return). Shared with `panel_impute_interlopers()`. |
| `.fmt(n)` | Formats an integer with comma separators for console and log output. |
| `.print_composition_summary(class_df)` | Prints a four-row panel composition count table. Shared with `panel_impute_interlopers()`. |

### 4.4 Filter application order

`filter_by_sample_frame()` and `log_sample_frame()` apply filters in the following fixed order to ensure reproducible, documented results:

1. `eins` — row filter on organization identifier
2. `form_type` — row filter on return type
3. `501c` — row filter on subsection code
4. `geography` — row filter on state, county, MSA (applied together as one logged step)
5. `ntee` — row filter on NTEE code, industry, and type (applied together)
6. `group_returns` — row filter excluding consolidated returns
7. `panel_types` — row filter on panel membership classification
8. `columns` — column filter resolving `vars`, `var_scope`, and `tables`
9. `custom_filter` entries — in the order supplied (log only)
10. `custom_select` — final column selection (log only)

Column filtering (step 8) always occurs after all row filters so that the variable resolution step operates on the smallest possible dataset.

### 4.5 Logfile format

**`.log` file** (human-readable, append-mode):

```
======================================================================
 Data Manifest: housing panel 2024
 Run timestamp: 2026-08-07 14:22:05
======================================================================
  INPUT                       rows: 1,234,567   cols: 412

  eins                        rows: 1,234,567 -> 88,402  (-1,146,165)   cols: 412 -> 412  (-0)
  form_type                   rows: 88,402 -> 81,990  (-6,412)           cols: 412 -> 412  (-0)
  501c                        rows: 81,990 -> 79,204  (-2,786)           cols: 412 -> 412  (-0)
  geography                   rows: 79,204 -> 31,017  (-48,187)          cols: 412 -> 412  (-0)
  ntee                        rows: 31,017 -> 14,388  (-16,629)          cols: 412 -> 412  (-0)
  group_returns               rows: 14,388 -> 14,201  (-187)             cols: 412 -> 412  (-0)
  panel_types                 rows: 14,201 -> 11,840  (-2,361)           cols: 412 -> 412  (-0)
  columns                     rows: 11,840 -> 11,840  (-0)               cols: 412 -> 87   (-325)
  custom_filter: revenue_pos  rows: 11,840 -> 11,122  (-718)             cols: 87 -> 87    (-0)

  OUTPUT                      rows: 11,122   cols: 87
----------------------------------------------------------------------
```

**`_log.csv` file** (machine-readable, append-mode):

Columns: `run_timestamp`, `project`, `step`, `criteria`, `rows_before`, `rows_after`, `rows_dropped`, `cols_before`, `cols_after`, `cols_dropped`.

One row per filter step per run. Header written only on first file creation.

### 4.6 Dependencies

| Package | Usage |
|---|---|
| `data.table` | All internal data manipulation in `panel_composition()` and `panel_impute_interlopers()` |
| `dplyr` + `rlang` | `custom_filter` expression evaluation in `log_sample_frame()` |
| `utils` | `read.csv()` for dictionary loading; `write.table()` for CSV log |
| `bit64` | Optional; used only when `as_integers = TRUE` and integer64 columns are present |

The `sample_frame` object itself and all five sample-frame functions have no runtime dependencies beyond base R. `dplyr` and `rlang` are only required if `custom_filter` is used.

---

## 5. Relationship to Other Package Functions

```
sample_frame()
    │
    ├─► filter_by_sample_frame()   ◄── panel_composition()
    │         │                              │
    │         └── used inside               └── used inside
    │                                            panel_impute_interlopers()
    └─► log_sample_frame()
              │
              ├── wraps filter_by_sample_frame() step-by-step
              └── writes  data_manifest_<name>.log
                          data_manifest_<name>_log.csv
```

`panel_composition()` and `panel_impute_interlopers()` operate independently of the sample framework — they do not require a `sample_frame` object. The sample framework calls into them as needed (for `panel_types` filtering) but does not own or replace their functionality.

---

*End of document.*
