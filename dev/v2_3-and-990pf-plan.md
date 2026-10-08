# efile v2.3 impact check and 990-PF integration plan

Checked 2026-10-08 against the S3 listings for `efile_v2_2`, `efile_v2_3`, and
`efilepf_v2_3`. Columns were compared using the 2022 CSV header of every table.
Other years were spot-checked only.

## Part 1. Impact of v2.3 on the 990/990EZ side

### What did not change

- **Aliased core tables.** The tables behind the `.EFILE_ALIASES` short
  names have the same names and the same columns in v2.2 and v2.3: `P00`,
  `P01`, `P08`, `P09`, `P10`, `P11`, `P12`, and `A01`. `A01` lost five columns
  (see below), but its name is the same.
- **Core financial variables.** `financial_fields("core")` returns 328 fields.
  None of them was renamed or removed in v2.3. Four of the 328 are pre-2018
  balance-sheet fields: `F9_10_NAFB_RESTRICT_PERM/TEMP_BOY/EOY`. They exist in
  2012 and 2016 files and are absent from 2019 onward, which is expected
  because of the form change.
- **One variable that is never published.** `F9_08_REV_OTH_FUNDR_NET_RLTD`
  comes from 2009 schemas only, and ef2 does not emit it in either release.
  `accounting_identities` uses it. This problem predates v2.3 and is minor.
- **Shared header.** `F9-P00-T00-HEADER` has the same structural key block in
  the 990 and PF releases. The PF copy carries 33 columns and the 990 copy
  carries 77. Every PF column also exists in the 990 copy.

### What changed and affects panel990

1. **Default version.** `.EFILE_VERSION` is `"v2_2"` in
   `R/source.R`. Change it to `"v2_3"`. Also update
   `tests/testthat/test-source-download.R:123` and the
   `data_source()` docs.
2. **The `.EFILE_TABLES` catalog is stale.**
   - Five tables in the catalog no longer exist:
     - `SD-P07-T01-INVESTMENTS-OTH-DERIVATIVES` is now `SD-P07-T00-...`.
     - `SD-P07-T01-INVESTMENTS-OTH-EQUITY` is now `SD-P07-T00-...`.
     - `SG-P02-T01-FUNDRAISING-EVENTS` was merged into
       `SG-P02-T00-FUNDRAISING-EVENTS`. That table grew from 17 to 57 columns.
     - `SH-P99-T00-FAP-COMMUNITY-BENEFIT-POLICY` is now `SH-P99-T01-...`.
     - `SO-T99-SUPPLEMENTAL-INFO` is now `SO-P00-T99-SUPPLEMENTAL-INFO`.
   - Thirteen v2.3 tables are missing from the catalog:
     - `F9-P00-T01-AFFILIATE-LISTING`
     - `SA-P01-T02-HOSPITAL-NAME-ADDRESS` and `SA-P01-T03-AGRI-RESEARCH-UNIV`
     - `SB-P00-T00-HEADER`, `SB-P02-T01`, `SB-P03-T00`, and `SB-P03-T01`
     - `SC-P02-T01-AFFILIATED-GROUP`
     - `SD-P07-T00` (two tables)
     - `SH-P05-T03-FACILITY-POLICIES-PRACTICES`
     - `SH-P99-T01`
     - `SO-P00-T99`
   - The T99 supplemental tables are first published in v2.3. v2.2 had none
     of them on S3.
   - **Option:** generate the catalog from `concordance990::table_names()`
     instead of maintaining it by hand.
3. **The bundled `field_concordance` is built from the old master concordance
   file, not from concordance990.**
   - **New variables are missing.** 55 variables published in v2.3 are not in
     it. They include the affiliate listing and the Schedule C affiliated
     group, plus `F9_04_SCHED_B_NOT_REQ_X`, `F9_05_170C_PREMIUM_DECL_TEXT`,
     and others.
     - On a parquet read these columns stay as character, because types come
       from `field_concordance`.
     - `normalize()` has no rule for them.
     - The sample-frame column resolver treats them as "custom" columns.
   - **Renamed variables.**
     - `SB_01_CONTRIBUTOR_TYPE` is now `SB_01_CONTRIBUTOR_NUM`.
     - `SH_01_CHNA_DESC_RESOURCES_X` is now `SH_05_CHNA_DESC_RESOURCES_X`.
   - **Moved variables.** 126 variables now live in a different table:
     - Schedule G events.
     - Schedule H facility policies, which moved out of
       `SH-P05-T00` (102 to 18 columns) into `SH-P05-T03`.
     - Schedule A hospital address, which moved to `SA-P01-T02`.
     - `F9_07_COMP_DTK_NONE_HCE` and `F9_07_COMP_KONTR_NONE`, which moved
       into `F9-P07-T00`.
   - **Effect of the moves.** `rdb_table` is stale for these variables. That
     affects `.sfw_expand_tables()`, so a sample frame with
     `tables = "SH-P05"` resolves the wrong column set.
   - **Fix:** rebuild `data-raw/build-concordance.R` on
     `concordance990::data_dictionary("F990")`. Keep panel990's derived
     columns, which are `money_field`, `blank_meaning`, and `forms`.
     concordance990 has **no** financial or money flag and no blank-meaning
     column. The money rule in panel990 (`data_type_xsd` matches
     `USAmount*`) must be kept. concordance990's `concordance()` carries
     `data_type_xsd`.
4. **Alias A01 (`SA-P01-T00`) lost five hospital-address columns.** They
   moved to `SA-P01-T02`, a MANY table. Code or vignettes that read
   `SA_01_PCSTAT_HOSPITAL_*` from `A01` will now get nothing.

## Part 2. 990-PF integration

### How the PF release is shaped

- **Location.** PF files are in a separate prefix, `public/efilepf_v2_3/`. It
  holds 84 tables for the years 2009 to 2024. `RETURN_TYPE` is `"990PF"`.
  - Shared tables: `F9-P00-T00-HEADER`, `F9-P02-T00-SIGNATURE`, and Schedule B
    `SB-*`. These have the same table names as in the 990 release, but they
    are **different files**.
  - PF-specific tables: `PF-P00-T00-HEADER`, `PF-P01` through `PF-P17`, and
    about 38 `PF-P99-Txx` supporting-statement tables. Most of the
    `PF-P99-Txx` tables are T01 and up, which means MANY.
- **Financial structure.** The PF financials are a different structure, not
  a relabeled 990.
  - `PF-P01-T00-REVENUE-EXPENSE` has four columns for each line: `_BOOKS`,
    `_NET` (net investment income), `_ADJ_NET`, and `_DISBMT`.
  - `PF-P02-T00-BALANCE-SHEET` has `_BOY_BV`, `_EOY_BV`, and `_EOY_FMV`.
- **PF type metadata.** concordance990 types 513 PF rows as `USAmount*`, so the
  XSD money rule panel990 uses for the 990 works for PF too. (An earlier
  draft of this plan said otherwise; that came from a misread of the PF file.)

### What breaks or misbehaves for PF data today

| Component | Problem with PF data |
|---|---|
| `data_source()` / `.efile_version_root()` | Hardcodes the `efile_` prefix, so the PF release cannot be reached except through `root =`. |
| Cache layout `path/<year>/<table>-<year>.ext` | `F9-P00-T00-HEADER-2022.parquet` is the same filename in both releases, so the 990 and PF copies collide. A PF run would reuse the 990 header, and the reverse. **This is the most dangerous issue.** |
| `.EFILE_ALIASES`, `table_catalog()` | These are 990 only. `P01`, `P08`, and `P10` mean different things on the PF. |
| Parquet type casting (`.p990_efile_types`) | No `PF_*` field is in `field_concordance`, so every PF numeric column stays character. |
| `normalize()` / `concordance()` | `PF_*` fields have no rules. HD and SG rules work because their forms are `"*"`. |
| `financial_fields()`, `panel_normalize()` | The table regex is `F9-P(01\|08\|09\|10\|11)`, so PF fields never match. `.pn_detect_ez()` is harmless: it returns FALSE for 990PF. |
| `accounting_check()`, `reconcile()` | The identities are for 990 Parts VIII to X only. PF needs its own registry: column totals across the four columns, the balance-sheet equation, and P01 revenue minus expenses. |
| `fields_in_scope()`, sample-frame `scope` | These offer `both`, `990`, `990EZ`, and `all`, and none of them is meaningful for PF. |
| Form-agnostic code: panel build, merge, deduplicate, classify, balance, complete, impute, smooth, BMF join | Works unchanged. It all keys on `EIN2`, `TAX_YEAR`, and `OBJECTID`, and PF tables carry the same key block. |

### Decision: one form family per source, chosen on `data_source()`

Add `form = c("990", "990PF")` to `data_source()`. It is a choice between the
two, not a combination:

- `"990"` is the `efile_` release. It already holds full-990 and 990EZ filers
  together, told apart by `RETURN_TYPE`, and that behavior is unchanged.
- `"990PF"` is the `efilepf_` release, which holds 990PF filers only.

A panel never mixes the two. Private foundations are filtered out of 990
panels by construction, because the 990 release contains no PF filers.

Everything that differs between the two releases flows through the source
object:

- the S3 prefix (`efile_` or `efilepf_`)
- the alias table and the catalog
- the cache subdirectory
- which concordance supplies types and normalization rules

`panelize()`, `download_tables()`, and `read_tables()` therefore need no new
arguments.

### `panelize_pf()` is a thin wrapper

The real change is form-aware `data_source()` and the lookups keyed on it.
`panelize_pf()` exists for discoverability and sensible defaults. Its source
defaults to `data_source(form = "990PF")`, and it passes `version` and
`format` through:

```r
panelize_pf <- function(sfw = NULL, tables = c("PF00", "PF01", "PF02"),
                        years, version = efile_version(),
                        format = .efile_default_format(), ...) {
  panelize(sfw = sfw, tables = tables, years = years,
           source = data_source(form = "990PF", version = version,
                                format = format), ...)
}
```

`panelize()` itself errors when its tables and source disagree, for example a
`PF-*` table requested from a 990 source. That error message points to
`panelize_pf()`.

### Form-specific behavior

Where behavior really differs, dispatch on the form family:

- **Financial helpers.** Give `financial_fields()`, `panel_normalize()`, and
  `accounting_check()` a `form` argument. It defaults from the panel's
  recorded source.
- **Scope.** Give `fields_in_scope()` a value `"990PF"`, which returns
  `PF` + `HD` + `SG`.
  - In the sample frame, `scope` is an error for a PF source. A PF return has
    one form, so 990-versus-EZ structural blanks do not arise.
  - Within PF there is a related problem: shaded cells, such as the NET and
    ADJ_NET columns on contribution lines. Handle it in `blank_meaning` for
    each field, not through scope.
- **Mixed 990 and PF panels.** Deferred, since this is not core
  functionality. Until then, users can build the two panels separately and
  bind them on the shared header columns.

### Implementation steps

1. **Done: refresh for v2.3, 990 side only.** See
   [Nonprofit-Open-Data-Collective/panel990#5](https://github.com/Nonprofit-Open-Data-Collective/panel990/pull/5).
2. **Done: 990PF integration in panel990** (branch `feat/990pf`).
   - **Source.** `data_source(form = "990PF")` reads the `efilepf_` prefix and
     carries its own aliases. The aliases are `P00`, `PF00`, `PF01`, `PF02`,
     and `PF03`; no 990 alias is reused with a different meaning. The source
     also carries its own 84-table catalog.
   - **Wrong-release requests.** `resolve_tables()` stops when a table from
     the other release is requested, before any download starts.
   - **Cache.** PF files are cached under `<path>/990PF/<year>/`. The 990
     layout is unchanged, so existing caches still work.
   - **Concordance.** `field_concordance_pf` has 1,093 variables. It is built
     by the same script and with the same rules as `field_concordance`.
     - **Correction to the earlier finding:** concordance990 *does* type most
       PF amounts as `USAmount*` (513 rows). The XSD money rule therefore
       works for PF, and every numeric field in Parts I-III is a money field.
   - **Types.** Parquet types come from one lookup over both concordances.
     The read paths do not need to know the form family.
   - **Financial helpers.**
     - `financial_fields(form = "990PF")` returns the PF core fields.
     - `panel_normalize()` zeroes PF fields for 990PF rows only.
   - **Accounting identities.** There are 29 PF identities, with
     `form_scope == "PF"`. Each one holds for at least 98% of 2021-2022
     filings.
   - **`panelize_pf()`.** The wrapper is added. A 990 form scope in a PF
     frame is an error.
   - **Vignette.** Added a fifth tutorial, "Private foundations (990PF)".
   - **Bug fix.** `panel_normalize()` always reported 0 values zeroed. The
     data was zeroed correctly; only the count in the message and audit was
     wrong.
3. **Next, upstream in concordance990.** Add `money_field` and
   `blank_meaning` to the data dictionary for both forms, so the rule lives in
   one place. panel990's build script would then read these columns instead
   of deriving them.
   - **Money flags.** These can start from the XSD rule panel990 uses now.
     Review the PF numeric fields that have no XSD type and are therefore
     treated as `literal_missing`, such as the `PF_AX19`/`PF_AX21` sale
     amounts and `PF_13_UNDIST_INCOME_PY_*`.
   - **Missing PF fields.** Five PF text fields are published in v2.3 but
     absent from the concordance: `PF_AX09_COMP_*`, `PF_AX14_COMP_EMPL_*`,
     and `PF_AX44_CAUSE_EXPLANATION`.

### Deferred

- A combined 990 + PF panel helper (`panel_bind()` with a crosswalk of
  comparable totals).
