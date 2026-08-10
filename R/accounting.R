# Accounting-identity checking and minimal-change reconciliation for 990 panels.
# Identities are the bundled `accounting_identities` registry (see data.R).

.accounting_identities <- function() {
  env <- new.env(parent = emptyenv())
  utils::data("accounting_identities", package = "panel990", envir = env)
  env$accounting_identities
}

# Registry (optionally by section) restricted to identities whose EVERY variable
# is present in `vars`; returns a named list of coefficient vectors.
.acct_registry <- function(section, vars) {
  reg <- .accounting_identities()
  if (!is.null(section)) reg <- reg[reg$section %in% section, , drop = FALSE]
  out <- list()
  for (nm in unique(reg$identity)) {
    sub <- reg[reg$identity == nm, , drop = FALSE]
    if (all(sub$variable %in% vars))
      out[[nm]] <- stats::setNames(sub$coefficient, sub$variable)
  }
  out
}

.acct_ginv <- function(M) {                       # base-R Moore-Penrose inverse
  s <- svd(M)
  tol <- max(dim(M)) * max(s$d) * .Machine$double.eps
  k <- s$d > tol
  if (!any(k)) return(t(M) * 0)
  s$v[, k, drop = FALSE] %*% (diag(1 / s$d[k], sum(k)) %*% t(s$u[, k, drop = FALSE]))
}

#' Check 990 rows against accounting identities
#'
#' Evaluates the bundled [accounting_identities] against each row of a panel and
#' reports the residual of every identity that can be evaluated (all of its
#' variables present as columns). A residual is `total - sum(parts)`; it should
#' be zero.
#'
#' @param data A data frame of 990 financial fields (e.g. a merged panel).
#' @param section Identity sections to check (`"revenue"`, `"expenses"`,
#'   `"balance_sheet"`). `NULL` (default) checks all.
#' @param id,time Identifier columns carried onto the report (if present).
#' @param tol Absolute tolerance for calling a residual a violation.
#' @param violations_only Return only the rows that violate an identity
#'   (default `TRUE`); `FALSE` returns every evaluated identity.
#' @return A data frame with one row per (record, identity): the id/time keys,
#'   `identity`, `residual`, and `ok`.
#' @seealso [reconcile()], [accounting_identities].
#' @export
accounting_check <- function(data, section = NULL, id = "EIN2",
                             time = "TAX_YEAR", tol = 1, violations_only = TRUE) {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  reg <- .acct_registry(section, names(data))
  keys <- intersect(c(id, time), names(data))
  if (!length(reg)) return(data.frame())

  parts <- lapply(names(reg), function(nm) {
    co <- reg[[nm]]
    m <- as.matrix(data[, names(co), drop = FALSE])
    res <- as.numeric(m %*% co)
    out <- data.frame(data[, keys, drop = FALSE], identity = nm,
                      residual = res, ok = abs(res) <= tol,
                      stringsAsFactors = FALSE, row.names = NULL)
    out
  })
  report <- do.call(rbind, parts)
  if (isTRUE(violations_only))
    report <- report[!is.na(report$residual) & !report$ok, , drop = FALSE]
  report <- report[order(-abs(report$residual)), , drop = FALSE]
  rownames(report) <- NULL
  report
}

#' Reconcile 990 rows to accounting identities with the least change
#'
#' Adjusts values as little as possible (weighted least squares) so that each
#' row satisfies the bundled [accounting_identities]. Columns named in `fixed`
#' are held exactly; among the rest, `weights` set how resistant each variable is
#' to change (larger = moves less). Only rows with no missing values in the
#' relevant fields are reconciled.
#'
#' @param data A data frame of 990 financial fields.
#' @param section Identity sections to enforce. `NULL` (default) uses all.
#' @param fixed Character vector of columns to hold fixed (e.g. reported totals).
#' @param weights Optional named vector of per-variable weights (default equal).
#' @param rows Rows to reconcile: a logical/integer index. Default is rows where
#'   `imputed_row` is `TRUE` if that column exists, otherwise all rows.
#' @param id,time Identifier columns (unused by the math; kept for symmetry).
#' @return `data` with reconciled values; an `"reconciled"` attribute records how
#'   many rows were adjusted and how many were skipped for missing values.
#' @seealso [accounting_check()], [panel_complete()].
#' @export
reconcile <- function(data, section = NULL, fixed = NULL, weights = NULL,
                      rows = NULL, id = "EIN2", time = "TAX_YEAR") {
  if (!is.data.frame(data)) stop("`data` must be a data.frame.")
  reg <- .acct_registry(section, names(data))
  if (!length(reg)) return(data)
  rvars <- unique(unlist(lapply(reg, names), use.names = FALSE))
  A <- matrix(0, length(reg), length(rvars),
              dimnames = list(names(reg), rvars))
  for (nm in names(reg)) A[nm, names(reg[[nm]])] <- reg[[nm]]

  free <- setdiff(rvars, fixed)
  w <- stats::setNames(rep(1, length(free)), free)
  if (!is.null(weights)) {
    hit <- intersect(names(weights), free)
    w[hit] <- weights[hit]
  }
  Af <- A[, free, drop = FALSE]
  Winv <- diag(1 / w, length(w))
  AWA_inv <- .acct_ginv(Af %*% Winv %*% t(Af))

  if (is.null(rows)) rows <- if ("imputed_row" %in% names(data))
    which(as.logical(data$imputed_row)) else seq_len(nrow(data))
  if (is.logical(rows)) rows <- which(rows)

  adjusted <- 0L; skipped <- 0L
  for (i in rows) {
    x <- as.numeric(data[i, rvars])
    if (anyNA(x)) { skipped <- skipped + 1L; next }
    names(x) <- rvars
    r <- as.numeric(A %*% x)
    if (all(abs(r) < 1e-9)) next
    delta <- as.numeric(Winv %*% t(Af) %*% AWA_inv %*% (-r))
    data[i, free] <- as.list(x[free] + delta)
    adjusted <- adjusted + 1L
  }
  attr(data, "reconciled") <- list(rows_adjusted = adjusted, rows_skipped = skipped)
  data
}
