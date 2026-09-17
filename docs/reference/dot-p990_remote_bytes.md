# Ask a server how many bytes a resource holds

Best effort: any failure returns `NA` and the caller falls back to the
requested timeout. The probe runs under its own short timeout so an
unreachable host fails here in seconds rather than consuming the
transfer budget.

## Usage

``` r
.p990_remote_bytes(url, timeout = 30)
```

## Arguments

- url:

  Remote URL.

- timeout:

  Seconds allowed for the header request.

## Value

The reported `Content-Length` in bytes, or `NA_real_`.
