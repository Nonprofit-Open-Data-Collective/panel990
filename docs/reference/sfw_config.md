# Metadata, policies, and rule sugar for a sample frame

Thin convenience wrappers over
[`add_rule()`](https://nonprofit-open-data-collective.github.io/panel990/reference/add_rule.md)
plus metadata/policy setters.

## Usage

``` r
add_meta(sfw, ...)

set_policy(sfw, ...)

add_function(sfw, name, value = NULL, fn = NULL)

add_view(sfw, name, rows, cols = NULL, value = NULL, fun = "length")

add_refresh(
  sfw,
  name,
  fn = NULL,
  action = NULL,
  cols = NULL,
  by = NULL,
  value = NULL,
  into = NULL,
  fun = NULL
)
```

## Arguments

- sfw:

  A sample frame.

- ...:

  Named metadata (`add_meta`) or named policies (`set_policy`).

- name:

  Rule name.

- value:

  A function body string (`add_function`) or a view's value column
  (`add_view`).

- fn:

  A function object (`add_function`/`add_refresh`).

- rows, cols:

  A view's grouping column(s) (`add_view`); `cols` also names the
  columns for a `droplevels`/`factor` refresh.

- fun:

  A view's aggregation, or the statistic for a `group_stat` refresh.

- action:

  A built-in refresh: `"droplevels"`, `"factor"`, or `"group_stat"`
  (`add_refresh`).

- by, into:

  Group column and output column for a `group_stat` refresh.

## Value

The updated sample frame.
