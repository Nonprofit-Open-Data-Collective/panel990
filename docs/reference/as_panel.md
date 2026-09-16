# Bundle a data frame with a sample frame

Bundle a data frame with a sample frame

## Usage

``` r
as_panel(data, sfw = NULL)

is_panel(data)
```

## Arguments

- data:

  A data frame, or an existing `panel` (returned unchanged).

- sfw:

  An optional
  [`create_sfw()`](https://nonprofit-open-data-collective.github.io/panel990/reference/create_sfw.md)
  sample frame; a fresh empty frame is created when `NULL`.

## Value

A `panel` object: a list of `data`, `sfw`, and a label-freshness flag.

## See also

[`sample_frame()`](https://nonprofit-open-data-collective.github.io/panel990/reference/panel_data.md),
[`manifest()`](https://nonprofit-open-data-collective.github.io/panel990/reference/manifest.md).
