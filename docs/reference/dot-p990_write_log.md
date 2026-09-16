# Write a per-run log and append to the run index

Every run writes its own timestamped file, so a later run can never
overwrite an earlier record.

## Usage

``` r
.p990_write_log(manifest, base_path, run_id, kind = "download")
```

## Arguments

- manifest:

  Data frame describing the run.

- base_path:

  Cache directory; logs are written to `<base_path>/logs`.

- run_id:

  Identifier from
  [`.p990_run_id()`](https://nonprofit-open-data-collective.github.io/panel990/reference/dot-p990_run_id.md).

- kind:

  Log family, such as `"download"` or `"bmf"`.

## Value

The normalized path of the per-run log file.
