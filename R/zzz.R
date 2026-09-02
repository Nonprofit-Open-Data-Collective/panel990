# data.table gates its S3 methods on cedta() -- "calling environment data.table
# aware". A package that only imports data.table without setting this flag gets
# NextMethod() fallbacks to the base data.frame methods, silently and with no
# warning. duplicated.data.table is the one that matters here: without the flag
# it falls through to duplicated.data.frame, which builds a per-row list via
# Map() and dispatches [[ on every element. On a 555k x 80 efile header table
# that is roughly 50 seconds against under a second for the data.table method.
#
# Setting this also gives data.table `[` semantics to data.table objects inside
# package code. Nothing here relies on that: fread() results are converted with
# setDF() and rbindlist() results with as.data.frame() before any subsetting,
# so every `[` in this package operates on a plain data.frame.
#
# See ?data.table::cedta and the "Importing data.table" vignette.
.datatable.aware <- TRUE
