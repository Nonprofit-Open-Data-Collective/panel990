# Update, drop, or list sample-frame rules

Update, drop, or list sample-frame rules

## Usage

``` r
update_rule(sfw, name, ..., drop = FALSE)

remove_rule(sfw, name)

get_rules(sfw)
```

## Arguments

- sfw:

  A sample frame.

- name:

  Rule name to update or drop.

- ...:

  Payload fields to overwrite on the named rule (same as
  [`add_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_rule.md)
  for its type).

- drop:

  If `TRUE`, remove the named rule instead of updating it.

## Value

The updated sample frame, or a data frame for `get_rules()`.
