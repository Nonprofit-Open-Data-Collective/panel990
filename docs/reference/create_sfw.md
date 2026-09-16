# Create a sample frame

A sample frame (`sfw`) is a free-standing registry of keys and typed
rules that specifies which rows and columns belong in a dataset. It
applies to, and validates against, any data frame. See
[`add_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_rule.md)
for the rule types and
[`apply_sfw()`](https://nonprofit-open-data-collective.github.io/panel990/reference/apply_sfw.md)
to realize them.

## Usage

``` r
create_sfw(
  name,
  entity = "EIN2",
  time = "TAX_YEAR",
  record = NULL,
  source = NA_character_,
  ...
)
```

## Arguments

- name:

  Project/panel name (used for identification and logging).

- entity:

  Entity (organization) key column. Default `"EIN2"`. `NULL` to register
  none.

- time:

  Time key column. Default `"TAX_YEAR"`. `NULL` to register none.

- record:

  Optional filing-level (`unique_record`) key column, e.g. `"OBJECTID"`.

- source:

  Optional data-source description stored in metadata.

- ...:

  Convenience filters lowered into filter rules.

## Value

An object of class `sfw`.

## Details

Default entity and time keys are registered from `entity`/`time`; add a
filing-level key with
[`add_key()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_key.md).
Named `...` are convenience filters (`state = "GA"`,
`years = 2020:2022`).
