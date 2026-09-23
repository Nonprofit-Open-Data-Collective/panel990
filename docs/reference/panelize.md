# Download, filter, merge, append BMF, and stack a panel

The workhorse acquisition recipe: resolve tables and years, download (or
virtually scan) the source files, project columns and push the sample
frame's entity restriction down to read-time, merge the tables within
each year, stack the years, optionally append BMF organization traits,
then apply the frame's rules. Returns a
[panel](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md)
bundling the data with the frame and a provenance log.

## Usage

``` r
panelize(
  sfw = NULL,
  tables,
  years,
  source = data_source(),
  bmf = "auto",
  backend = "memory",
  cache = c("retain", "temporary", "none"),
  path = "PANEL990",
  filters = NULL,
  columns = NULL,
  include_many = FALSE,
  collision = c("error", "prefix"),
  unique_rows = TRUE,
  overwrite = FALSE,
  retry_max = 3L,
  timeout = 1800,
  verbose = TRUE
)
```

## Arguments

- sfw:

  Optional
  [`create_sfw()`](https://nonprofit-open-data-collective.github.io/panel990/reference/create_sfw.md)
  sample frame governing the build. Filters prefilter reads and merges;
  `select` rules project columns.

- tables:

  Aliases or literal table names.

- years:

  Tax years.

- source:

  Efile source configuration.

- bmf:

  Append BMF fields: `"auto"` (default – attach when the frame
  references a BMF field), `FALSE`, `TRUE` (the NCCS master), or a BMF
  source (data frame, path, or URL).

- backend:

  `"memory"` (default) or `"duckdb"` (`"db"` is accepted).

- cache:

  `"retain"`, `"temporary"`, or `"none"` (DuckDB-only virtual scan).

- path:

  Retained-cache directory.

- filters:

  Optional named value filters (merged with the frame's).

- columns:

  Optional source fields to retain (union with the frame's).

- include_many:

  Join one-to-many and supplemental tables.

- collision:

  Non-key collision policy.

- unique_rows:

  Remove exact duplicate source rows during the read. `TRUE` (default)
  preserves the historical behaviour but prevents the column projection
  from being pushed into a parquet scan; see
  [`read_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/read_tables.md).

- overwrite:

  Replace cached files.

- retry_max:

  Download attempts.

- timeout:

  Minimum per-attempt download timeout in seconds. This is a budget for
  a whole transfer rather than an idle timeout, so it is raised
  automatically for large files; see
  [`download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.md).

- verbose:

  Print progress.

## Value

A `panel` (see
[`as_panel()`](https://nonprofit-open-data-collective.github.io/panel990/reference/as_panel.md))
whose `data` is the stacked frame, whose `sfw` carries the rules and
provenance log
([`manifest()`](https://nonprofit-open-data-collective.github.io/panel990/reference/manifest.md)),
plus download/table/join manifests and BMF diagnostics.

## Details

Keys are set automatically from the efile schema (entity `EIN2`, time
`TAX_YEAR`, record `OBJECTID`).

## Reading parquet

The source format comes from `source`, so
`data_source(format = "parquet")` builds the same panel from the parquet
release. Parquet only pays off for selective reads, and the frame's row
and column restrictions are what make a read selective – so the
combination that matters is a frame with an entity subset or a `select`
rule, `backend = "duckdb"`, `cache = "none"`, and `unique_rows = FALSE`.
See
[`data_source()`](https://nonprofit-open-data-collective.github.io/panel990/reference/data_source.md)
for the format's type contract and
[`read_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/read_tables.md)
for why deduplication blocks the projection.
