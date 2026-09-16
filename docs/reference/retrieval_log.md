# List retrieval runs recorded in a cache directory

Each call to
[`download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.md)
or
[`bmf_retrieve()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_retrieve.md)
appends one row and leaves a full per-run manifest beside it in
`<path>/logs`.

## Usage

``` r
retrieval_log(path = "PANEL990")
```

## Arguments

- path:

  Cache directory used by
  [`download_tables()`](https://nonprofit-open-data-collective.github.io/panel990/reference/download_tables.md)
  or
  [`bmf_retrieve()`](https://nonprofit-open-data-collective.github.io/panel990/reference/bmf_retrieve.md).

## Value

A data frame of recorded runs, oldest first, or `NULL` when the cache
holds no run index.
