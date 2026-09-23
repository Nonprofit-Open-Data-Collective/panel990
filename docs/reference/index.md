# Package index

## Sample frame

Define a reusable specification of keys and typed rules, then apply it
to, or validate it against, any data frame.

- [`create_sfw()`](https://nonprofit-open-data-collective.github.io/panel990/reference/create_sfw.md)
  : Create a sample frame
- [`add_key()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_key.md)
  [`get_keys()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_key.md)
  : Register a key on a sample frame
- [`add_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_rule.md)
  : Add or replace a rule on a sample frame
- [`update_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_rules.md)
  [`remove_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_rules.md)
  [`get_rules()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_rules.md)
  : Update, drop, or list sample-frame rules
- [`add_meta()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_config.md)
  [`set_policy()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_config.md)
  [`add_function()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_config.md)
  [`add_view()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_config.md)
  [`add_refresh()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_config.md)
  : Metadata, policies, and rule sugar for a sample frame
- [`classify_panel()`](https://nonprofit-open-data-collective.github.io/panel990/reference/classify_panel.md)
  : Classify panel membership and store it as label rules
- [`apply_sfw()`](https://nonprofit-open-data-collective.github.io/panel990/reference/apply_sfw.md)
  : Apply a sample frame to a data frame
- [`resolve_frame()`](https://nonprofit-open-data-collective.github.io/panel990/reference/resolve_frame.md)
  : Resolve a sample frame's cross-year requirements against the source
- [`apply_check()`](https://nonprofit-open-data-collective.github.io/panel990/reference/apply_check.md)
  : Run a sample frame's check rules
- [`views()`](https://nonprofit-open-data-collective.github.io/panel990/reference/views.md)
  : Compute a sample frame's view rules against a data frame
- [`conform()`](https://nonprofit-open-data-collective.github.io/panel990/reference/conform.md)
  : Check whether a data frame conforms to a sample frame

## The panel object

Bundle data with its sample frame; extract and report provenance.

- [`as_panel()`](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md)
  [`is_panel()`](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md)
  : Bundle a data frame with a sample frame
- [`panel_data()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_data.md)
  [`sample_frame()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_data.md)
  : Extract the data frame or sample frame from a panel
- [`manifest()`](https://nonprofit-open-data-collective.github.io/panel990/reference/manifest.md)
  : Report a panel's provenance ledger

## Acquire & assemble

Download, read, merge, and stack efile tables into a panel.

- [`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md)
  : Download, filter, merge, append BMF, and stack a panel
- [`data_source()`](https://nonprofit-open-data-collective.github.io/panel990/reference/data_source.md)
  : Create an efile source configuration
- [`efile_version()`](https://nonprofit-open-data-collective.github.io/panel990/reference/efile_version.md)
  : Current default efile release
- [`table_catalog()`](https://nonprofit-open-data-collective.github.io/panel990/reference/table_catalog.md)
  : Catalog of canonical efile tables
- [`resolve_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/resolve_tables.md)
  : Resolve aliases and literal efile table names
- [`download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.md)
  : Download or reuse efile table files
- [`read_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/read_tables.md)
  : Read acquired efile tables
- [`merge_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/merge_tables.md)
  : Merge efile tables using explicit filing keys
- [`retrieval_log()`](https://nonprofit-open-data-collective.github.io/panel990/reference/retrieval_log.md)
  : List retrieval runs recorded in a cache directory

## Organization traits (BMF)

Attach NCCS Business Master File fields by EIN.

- [`bmf_merge()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_merge.md)
  : Merge native BMF fields onto efile data
- [`bmf_retrieve()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_retrieve.md)
  : Retrieve and prepare the NCCS unified BMF
- [`bmf_prepare()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_prepare.md)
  : Prepare current-schema BMF data
- [`bmf_url()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_url.md)
  : Return the current NCCS unified BMF URL
- [`bmf_vars()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_vars.md)
  : Return the default native BMF fields
- [`bmf_states()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_states.md)
  : Return the published BMF state mart codes
- [`bmf_manifest()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_manifest.md)
  : Read the published BMF build manifest

## Normalize & clean

Form-aware normalization of source encodings and record deduplication.

- [`concordance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/concordance.md)
  : Construct a field-level data-normalization concordance
- [`normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/normalize.md)
  : Normalize efile source encodings using form-aware rules
- [`panel_normalize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_normalize.md)
  : Normalize blank financial fields to zero, form-scoped
- [`financial_fields()`](https://nonprofit-open-data-collective.github.io/panel990/reference/financial_fields.md)
  : Core 990 financial fields
- [`fields_in_scope()`](https://nonprofit-open-data-collective.github.io/panel990/reference/fields_in_scope.md)
  : Select efile fields by form scope
- [`panel_deduplicate()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_deduplicate.md)
  [`deduplicate()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_deduplicate.md)
  : Select one filing per organization-year

## Panel analysis

Classify, label, filter, impute, and smooth panels over time.

- [`panel_describe()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_describe.md)
  : Describe panel coverage and membership
- [`panel_update()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_update.md)
  : Refresh panel-membership labels
- [`panel_label()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_label.md)
  : Label rows with panel membership
- [`panel_filter()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_filter.md)
  : Select panel organizations by membership type
- [`panel_balance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_balance.md)
  : Trim a panel to a balanced rectangle
- [`panel_complete()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_complete.md)
  : Complete panel spans by filling interior gaps
- [`panel_impute()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_impute.md)
  : Insert and fill missing panel years
- [`panel_smooth()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_smooth.md)
  : Smooth numeric variables within panel IDs

## Accounting consistency

Check and reconcile 990 rows against accounting identities.

- [`accounting_check()`](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_check.md)
  : Check 990 rows against accounting identities
- [`reconcile()`](https://nonprofit-open-data-collective.github.io/panel990/reference/reconcile.md)
  : Reconcile 990 rows to accounting identities with the least change

## Data

- [`field_concordance`](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md)
  : Field-scope and normalization concordance for IRS 990 efile
  variables
- [`accounting_identities`](https://nonprofit-open-data-collective.github.io/panel990/reference/accounting_identities.md)
  : Accounting-identity registry for IRS 990 financial fields
