# Normalize efile source encodings using form-aware rules

Interprets blank values according to a concordance. Applicable financial
blanks can become zero and applicable checkbox blanks can become
`FALSE`. A rule is never applied to a filing whose form is outside the
field's scope.

Checkbox values are matched case- and whitespace-insensitively against
the accepted vocabulary (`X`/`TRUE`/`T`/`1`/`Y`/`YES` -\> `TRUE`;
`FALSE`/`F`/`0`/`N`/`NO` -\> `FALSE`; blank -\> `FALSE`). An in-scope,
non-blank value outside that set is coerced to `NA`, but first raises a
**warning** naming the field, the number of affected rows, and the
unique offending values – an early signal of an upstream parsing
problem. The same counts are recorded in the audit's
`unrecognized_count` / `unrecognized_values` columns.

This function does not perform statistical normalization and does not
impute missing panel years.

## Usage

``` r
normalize(
  data,
  concordance,
  form = "RETURN_TYPE",
  audit = TRUE,
  strict = FALSE
)
```

## Arguments

- data:

  A data frame containing source fields and a return-type column.

- concordance:

  An object created by
  [`concordance()`](https://nonprofit-open-data-collective.github.io/panel990/reference/concordance.md).

- form:

  Name of the return-type column. Default `"RETURN_TYPE"`.

- audit:

  Logical. Attach a rule-level audit table as the
  `"normalization_audit"` attribute. Default `TRUE`.

- strict:

  Logical. If `TRUE`, error when a concordance field is absent;
  otherwise report it in the audit. Default `FALSE`.

## Value

A data frame with source blanks normalized only where rules apply.
