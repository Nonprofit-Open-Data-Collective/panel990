# Register a key on a sample frame

Keys are structural columns that other operations reference. There is
one key per `type`; re-registering a type replaces it.

## Usage

``` r
add_key(sfw, name, type, var)

get_keys(sfw)
```

## Arguments

- sfw:

  A sample frame.

- name:

  Human-readable key name.

- type:

  Key role: `"entity"`, `"time"`, `"unique_record"` (or a custom role).

- var:

  The column name.

## Value

The updated sample frame.

## See also

`get_keys()`
