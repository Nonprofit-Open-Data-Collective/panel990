# Add or replace a rule on a sample frame

Appends a typed rule, or replaces the rule with the same `name`
(upsert). The payload arguments depend on `type`:

- `filter`, `check`:

  `column`, `op`, `values` (structured) **or** `expr` (a predicate
  string). `op` in `in`, `not_in`, `==`, `!=`, `>`, `>=`, `<`, `<=`,
  `between`, `is_true`, `is_false`.

- `subset`:

  `subset` – a vector of entity ids to keep (captured).

- `label`:

  `map` (an id-named vector) or `from` (a data frame) with `keys` and
  `label` column names; `label` also names the derived column.

- `select`:

  `vars`, `scope`, `tables`, `drop` (resolved via
  [field_concordance](https://nonprofit-open-data-collective.github.io/panel990/reference/field_concordance.md)).

- `dedup`:

  `group`, `partial`, `amended`, `timestamp` column overrides for
  [`deduplicate()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_deduplicate.md).

- `refresh`:

  `fn` – a function taking and returning a data frame.

- `view`:

  `rows`, `cols`, `value`, `fun` – a crosstab/tapply summary.

- `function`:

  `value`/`code` (a string) or `fn` (a function).

## Usage

``` r
add_rule(sfw, name = NULL, type, ...)
```

## Arguments

- sfw:

  A sample frame.

- name:

  Rule name. Empty/`NULL` auto-generates `<type>_<n>`. An existing name
  replaces that rule.

- type:

  One of the rule types above.

- ...:

  Type-specific payload (see Details).

## Value

The updated sample frame.

## See also

[`update_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_rules.md),
[`get_rules()`](https://nonprofit-open-data-collective.github.io/panel990/reference/sfw_rules.md),
[`apply_sfw()`](https://nonprofit-open-data-collective.github.io/panel990/reference/apply_sfw.md).
