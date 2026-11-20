test_that("panel smoothing preserves shape and fills missing focal values", {
  data <- data.frame(
    EIN2 = rep("A", 5), TAX_YEAR = 2018:2022,
    x = c(100, NaN, 300, 400, 500), y = 1:5
  )
  out <- panel_smooth(data, vars = "x", window = 3, verbose = FALSE)
  expect_equal(dim(out), dim(data))
  expect_equal(out$x[2], 200)
  expect_equal(out$y, data$y)
})

test_that("shifted edge windows and weighting modes are stable", {
  data <- data.frame(EIN2 = rep("A", 4), TAX_YEAR = 2020:2023, x = 1:4)
  equal <- panel_smooth(data, "x", weights = "equal", verbose = FALSE)
  decay <- panel_smooth(data, "x", weights = "decay", verbose = FALSE)
  expect_equal(equal$x, c(2, 2, 3, 3))
  expect_false(identical(equal$x[1], decay$x[1]))
})

test_that("smoothing validates window and fields", {
  data <- data.frame(EIN2 = "A", TAX_YEAR = 2020, x = 1)
  expect_error(panel_smooth(data, "x", window = 2), "odd")
  expect_error(panel_smooth(data, "missing"), "not found")
})

# ---- align -------------------------------------------------------------------

# Verbatim copy of the pre-`align` implementation, used as the reference for
# the centred default.
legacy_smooth <- function(data, vars, window = 3, weights = "equal",
                          time = "TAX_YEAR", id = "EIN2") {
  if (window == 1L) return(as.data.frame(data))
  out <- as.data.frame(data)
  groups <- split(seq_len(nrow(out)), out[[id]], drop = TRUE)
  for (rows in groups) {
    rows <- rows[order(out[[time]][rows])]
    n <- length(rows)
    width <- min(as.integer(window), n)
    for (variable in vars) {
      original <- out[[variable]][rows]
      smoothed <- rep(NA_real_, n)
      for (position in seq_len(n)) {
        start <- max(1L, min(position - floor(width / 2), n - width + 1L))
        pos <- start:(start + width - 1L)
        distance <- abs(pos - position)
        raw_weights <- switch(weights,
          equal = rep(1, width),
          half = if (width == 1L) 1 else {
            w <- rep(0.5 / (width - 1L), width)
            w[which.min(distance)] <- 0.5
            w
          },
          decay = 0.5^distance
        )
        values <- original[pos]
        values[is.nan(values)] <- NA_real_
        keep <- !is.na(values)
        smoothed[position] <- if (!any(keep)) NA_real_ else
          sum(values[keep] * raw_weights[keep]) / sum(raw_weights[keep])
      }
      out[[variable]][rows] <- smoothed
    }
  }
  rownames(out) <- NULL
  out
}

random_panel <- function(seed = 1) {
  set.seed(seed)
  ids <- rep(sprintf("E%02d", 1:30), times = sample(1:8, 30, replace = TRUE))
  data <- data.frame(EIN2 = ids, stringsAsFactors = FALSE)
  data$TAX_YEAR <- ave(seq_along(ids), ids, FUN = function(i)
    sort(sample(2010:2024, length(i))))
  data$x <- round(rnorm(nrow(data), 100, 30), 1)
  data$y <- rpois(nrow(data), 20)
  data$x[sample(nrow(data), 15)] <- NA
  data$x[sample(nrow(data), 3)] <- NaN
  data[sample(nrow(data)), ]   # scrambled row order
}

test_that("default and align = 'center' reproduce the legacy output exactly", {
  data <- random_panel()
  for (w in c(1, 3, 5)) for (wt in c("equal", "half", "decay")) {
    ref <- legacy_smooth(data, c("x", "y"), window = w, weights = wt)
    expect_identical(panel_smooth(data, c("x", "y"), window = w, weights = wt,
                                  verbose = FALSE), ref)
    expect_identical(panel_smooth(data, c("x", "y"), window = w, weights = wt,
                                  align = "center", verbose = FALSE), ref)
  }
})

test_that("align = 'right' never uses future values", {
  data <- random_panel(2)
  cutoff <- 2017
  later <- data$TAX_YEAR > cutoff
  shocked <- data
  shocked$x[later] <- shocked$x[later] * 1000 + 1e6
  for (wt in c("equal", "half", "decay")) {
    full <- panel_smooth(data, "x", window = 3, weights = wt, align = "right",
                         verbose = FALSE)
    out <- panel_smooth(shocked, "x", window = 3, weights = wt, align = "right",
                        verbose = FALSE)
    # perturbing every value after the cutoff leaves earlier rows untouched
    expect_identical(out$x[!later], full$x[!later])
  }
  # truncating the series at each year gives the same value for that year
  one <- data.frame(EIN2 = "A", TAX_YEAR = 2015:2022,
                    x = c(5, 9, 2, 7, 3, 8, 1, 6))
  full <- panel_smooth(one, "x", window = 3, weights = "decay", align = "right",
                       verbose = FALSE)$x
  for (i in seq_len(nrow(one))) {
    part <- panel_smooth(one[1:i, ], "x", window = 3, weights = "decay",
                         align = "right", verbose = FALSE)$x
    expect_equal(part[i], full[i])
  }
})

test_that("trailing windows count calendar years and do not bridge gaps", {
  data <- data.frame(EIN2 = "A", TAX_YEAR = c(2015, 2016, 2019, 2020, 2021),
                     x = c(10, 20, 30, 40, 50))
  out <- panel_smooth(data, "x", window = 3, align = "right", verbose = FALSE)$x
  # 2015: {2015}; 2016: {2015, 2016}; 2019: {2019} only (2017-18 missing and
  # 2016 is outside the window); 2020: {2019, 2020}; 2021: {2019, 2020, 2021}.
  expect_equal(out, c(10, 15, 30, 35, 40))
  # the row-based centred window, by contrast, bridges the 2016 -> 2019 gap
  cen <- panel_smooth(data, "x", window = 3, verbose = FALSE)$x
  expect_equal(cen[3], mean(c(20, 30, 40)))
})

test_that("left windows are forward-looking calendar windows", {
  data <- data.frame(EIN2 = "A", TAX_YEAR = c(2015, 2016, 2019, 2020, 2021),
                     x = c(10, 20, 30, 40, 50))
  out <- panel_smooth(data, "x", window = 3, align = "left", verbose = FALSE)$x
  expect_equal(out, c(15, 20, 40, 45, 50))
  # left on the data equals right on the time-reversed data
  rev_data <- transform(data, TAX_YEAR = -TAX_YEAR)
  for (wt in c("equal", "half", "decay"))
    expect_equal(
      panel_smooth(data, "x", window = 3, weights = wt, align = "left",
                   verbose = FALSE)$x,
      panel_smooth(rev_data, "x", window = 3, weights = wt, align = "right",
                   verbose = FALSE)$x)
})

test_that("trailing weights follow decay = 0.5^(t - year) and half = 0.5 focal", {
  data <- data.frame(EIN2 = "A", TAX_YEAR = 2018:2021, x = c(1, 2, 4, 8))
  dec <- panel_smooth(data, "x", window = 3, weights = "decay", align = "right",
                      verbose = FALSE)$x
  expect_equal(dec[3], (4 * 1 + 2 * 0.5 + 1 * 0.25) / 1.75)
  expect_equal(dec[2], (2 * 1 + 1 * 0.5) / 1.5)
  half <- panel_smooth(data, "x", window = 3, weights = "half", align = "right",
                       verbose = FALSE)$x
  expect_equal(half[4], 8 * 0.5 + 4 * 0.25 + 2 * 0.25)
  expect_equal(half[1], 1)   # only the focal slot is in range
  # a gap inside the window: present slots keep their weights, then renormalize
  g <- panel_smooth(data[-3, ], "x", window = 3, weights = "half",
                    align = "right", verbose = FALSE)$x
  expect_equal(g[3], (8 * 0.5 + 2 * 0.25) / 0.75)
  # even windows are allowed off-centre
  two <- panel_smooth(data, "x", window = 2, align = "right", verbose = FALSE)$x
  expect_equal(two, c(1, 1.5, 3, 6))
})

test_that("trailing windows drop NA/NaN and fill missing focal values", {
  data <- data.frame(EIN2 = rep(c("A", "B"), each = 4),
                     TAX_YEAR = rep(2018:2021, 2),
                     x = c(10, NA, NaN, 40, NA, NA, NA, NA))
  out <- panel_smooth(data, "x", window = 3, align = "right", verbose = FALSE)$x
  expect_equal(out[1:4], c(10, 10, 10, 40))
  expect_true(all(is.na(out[5:8])))
  # rows keep their original order and shape
  ord <- c(8, 3, 1, 6, 2, 7, 4, 5)
  s <- panel_smooth(data[ord, ], "x", window = 3, align = "right",
                    verbose = FALSE)
  expect_equal(dim(s), dim(data))
  expect_equal(s$x, out[ord])
})

test_that("align validates window and time", {
  data <- data.frame(EIN2 = "A", TAX_YEAR = 2020:2021, x = 1:2)
  expect_error(panel_smooth(data, "x", window = 0, align = "right"), "integer")
  expect_error(panel_smooth(data, "x", window = 2.5, align = "left"), "integer")
  expect_error(panel_smooth(data, "x", align = "trailing"), "should be one of")
  bad <- transform(data, TAX_YEAR = c("FY20", "FY21"))
  expect_error(panel_smooth(bad, "x", align = "right", verbose = FALSE), "numeric")
  chr <- transform(data, TAX_YEAR = c("2020", "2021"))
  expect_equal(panel_smooth(chr, "x", align = "right", verbose = FALSE)$x,
               c(1, 1.5))
})

test_that("align passes through the panel object method", {
  data <- data.frame(EIN2 = "A", TAX_YEAR = c(2015, 2016, 2019),
                     x = c(10, 20, 30))
  out <- panel_smooth(as_panel(data), "x", align = "right", verbose = FALSE)
  expect_equal(out$data$x, c(10, 15, 30))
})
