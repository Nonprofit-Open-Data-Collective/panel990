# Resolve a sample frame's cross-year requirements against the source

Executes every active `require` rule on the frame and replaces them with
a single captured `subset` rule, so the resulting frame specifies one
concrete set of entity ids that
[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md)
can push down to read-time and
[`apply_sfw()`](https://nonprofit-open-data-collective.github.io/panel990/reference/apply_sfw.md)
can execute against any data frame.

A `require` rule is the one rule type that cannot be evaluated against a
data frame, because it asserts something across table-years – "filed in
all three years", "was a 990EZ filer every year". See
[`add_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_rule.md)
for the payload.

Resolution reads only the entity key, the time key, and any column a
predicate names, so it is far cheaper than building the panel and
filtering it: the condition is answered before the financial columns are
ever touched. On a `data_source(format = "parquet")` release this is two
columns of one table.

## Usage

``` r
resolve_frame(
  sfw,
  years,
  source = data_source(),
  name = "resolved",
  verbose = TRUE
)
```

## Arguments

- sfw:

  A sample frame carrying at least one `require` rule.

- years:

  Tax years the requirement is evaluated over. Years the release does
  not carry are skipped, and `present_in = "all"` then means all of the
  years that exist.

- source:

  An
  [`data_source()`](https://nonprofit-open-data-collective.github.io/panel990/reference/data_source.md)
  configuration.

- name:

  Name for the `subset` rule that receives the resolved ids.

- verbose:

  Print a line per resolved rule.

## Value

The updated sample frame: `require` rules deactivated, one `subset` rule
added, and a receipt appended to the provenance log.

## Details

Multiple `require` rules intersect: an entity must satisfy all of them.
The rules themselves are deactivated rather than dropped, so the frame
still records the condition that produced the sample;
[`get_rules()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_rules.md)
shows both the original requirement and the resolved subset, and
[`manifest()`](https://nonprofit-open-data-collective.github.io/panel990/reference/manifest.md)
logs the resolution with the id count.

## See also

[`add_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_rule.md),
[`panelize()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panelize.md),
[`manifest()`](https://nonprofit-open-data-collective.github.io/panel990/reference/manifest.md)

## Examples

``` r
frame <- create_sfw("balanced 990EZ filers")
frame <- add_rule(frame, type = "require", table = "P00",
                  present_in = "all", column = "RETURN_TYPE",
                  op = "in", values = "990EZ", holds = "every")
get_rules(frame)
#>        name    type active                                               detail
#> 1 require_1 require   TRUE P00: present in all; every year RETURN_TYPE in 990EZ
if (FALSE) { # \dontrun{
# Reads EIN2, TAX_YEAR, and RETURN_TYPE only.
frame <- resolve_frame(frame, years = 2019:2021,
                       source = data_source(format = "parquet"))
get_rules(frame)
} # }
```
