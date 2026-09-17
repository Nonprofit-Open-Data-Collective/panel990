# Timeout budget for one transfer attempt

R's `timeout` option is a budget for the *whole* transfer, not an idle
timeout:
[`utils::download.file()`](https://rdrr.io/r/utils/download.file.html)
aborts once it elapses even while bytes are still arriving. A fixed
value therefore imposes a minimum transfer rate that rises with file
size – 3.6 GB in 1800 seconds demands a sustained 2 MB/s. Where the size
is known, convert it into the time it needs at `.P990_MIN_RATE` and keep
whichever budget is larger.

## Usage

``` r
.p990_timeout(timeout, bytes = NA_real_, floor = NULL)
```

## Arguments

- timeout:

  Requested per-attempt timeout in seconds.

- bytes:

  Expected transfer size in bytes, or `NA`.

- floor:

  A timeout already in force that must not be reduced.

## Value

A length-one integer number of seconds.

## Details

`floor` preserves a timeout the user raised globally, through
`options(timeout =)` or the `R_DEFAULT_INTERNET_TIMEOUT` environment
variable; [`?download.file`](https://rdrr.io/r/utils/download.file.html)
asks packages not to lower it.
