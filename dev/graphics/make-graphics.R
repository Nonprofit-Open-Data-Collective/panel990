# ==============================================================================
# make-graphics.R -- build the explanatory SVG figures in man/figures/.
#
# The imputed and smoothed values shown in the figures are computed with the
# package's own panel_impute() / panel_smooth() implementations (sourced from
# R/), so the numbers are real, not illustrative.
#
# Run from anywhere:  Rscript dev/graphics/make-graphics.R
# ==============================================================================

args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", grep("^--file=", args, value = TRUE)[1])
root <- normalizePath(file.path(dirname(script), "..", ".."))
fig_dir <- file.path(root, "man", "figures")
dir.create(fig_dir, showWarnings = FALSE, recursive = TRUE)

is_panel <- function(x) inherits(x, "panel")   # stub so sourced fns run standalone
source(file.path(root, "R", "panel-classify.R"))
source(file.path(root, "R", "panel-impute.R"))
source(file.path(root, "R", "panel-smooth.R"))

# ---- palette / typography ----------------------------------------------------
FONT   <- "Segoe UI, Helvetica, Arial, sans-serif"
MONO   <- "Consolas, Menlo, Courier New, monospace"
NAVY   <- "#1B2A5B"; GREY  <- "#8A93A6"; LIGHT  <- "#F2F3F5"; BORDER <- "#E3E5EA"
GREEN  <- "#5BAE2E"; BLUE  <- "#0E87BE"; AMBER  <- "#E9A800"; PURPLE <- "#6B6EC6"
RED    <- "#D64545"; ORANGE <- "#E8862E"; TEAL  <- "#00A99D"; DGREEN <- "#2E9E44"
TYPE_COLOR <- c(persistent = GREEN, entrant = BLUE, exit = AMBER, transient = PURPLE)

# ---- tiny svg builder --------------------------------------------------------
svg_new <- function(w, h) {
  s <- new.env(parent = emptyenv()); s$w <- w; s$h <- h; s$buf <- character(0); s
}
push <- function(s, txt) s$buf <- c(s$buf, txt)
svg_save <- function(s, file) {
  writeLines(c(sprintf(paste0(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" ',
    'viewBox="0 0 %d %d" font-family="%s">'), s$w, s$h, s$w, s$h, FONT),
    sprintf('<rect x="0" y="0" width="%d" height="%d" fill="white"/>', s$w, s$h),
    s$buf, "</svg>"), file)
  message("wrote ", file)
}
dash_attr <- function(dash) if (is.null(dash)) "" else
  sprintf(' stroke-dasharray="%s"', dash)

el_rect <- function(s, x, y, w, h, fill, stroke = NULL, sw = 1, rx = 0,
                    dash = NULL, opacity = NULL) {
  push(s, sprintf(
    '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s"%s%s%s/>',
    x, y, w, h, rx, fill,
    if (is.null(stroke)) "" else
      sprintf(' stroke="%s" stroke-width="%.1f"%s', stroke, sw, dash_attr(dash)),
    if (is.null(opacity)) "" else sprintf(' opacity="%.2f"', opacity), ""))
}
el_circle <- function(s, cx, cy, r, fill, stroke = NULL, sw = 1.5, dash = NULL) {
  push(s, sprintf('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"%s/>',
    cx, cy, r, fill,
    if (is.null(stroke)) "" else
      sprintf(' stroke="%s" stroke-width="%.1f"%s', stroke, sw, dash_attr(dash))))
}
el_line <- function(s, x1, y1, x2, y2, stroke, sw = 1, dash = NULL, cap = "butt") {
  push(s, sprintf(paste0('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" ',
    'stroke="%s" stroke-width="%.1f" stroke-linecap="%s"%s/>'),
    x1, y1, x2, y2, stroke, sw, cap, dash_attr(dash)))
}
el_polyline <- function(s, xs, ys, stroke, sw = 2.5, dash = NULL) {
  pts <- paste(sprintf("%.1f,%.1f", xs, ys), collapse = " ")
  push(s, sprintf(paste0('<polyline points="%s" fill="none" stroke="%s" ',
    'stroke-width="%.1f" stroke-linejoin="round" stroke-linecap="round"%s/>'),
    pts, stroke, sw, dash_attr(dash)))
}
el_polygon <- function(s, xs, ys, fill, stroke = NULL, sw = 1) {
  pts <- paste(sprintf("%.1f,%.1f", xs, ys), collapse = " ")
  push(s, sprintf('<polygon points="%s" fill="%s"%s/>', pts, fill,
    if (is.null(stroke)) "" else sprintf(' stroke="%s" stroke-width="%.1f"', stroke, sw)))
}
el_text <- function(s, x, y, label, size = 14, fill = NAVY, anchor = "middle",
                    weight = "normal", family = FONT, ls = NULL, style = NULL) {
  label <- gsub("&", "&amp;", as.character(label), fixed = TRUE)
  label <- gsub("<", "&lt;", label, fixed = TRUE)
  label <- gsub(">", "&gt;", label, fixed = TRUE)
  push(s, sprintf(paste0('<text x="%.1f" y="%.1f" font-size="%.1f" fill="%s" ',
    'text-anchor="%s" font-weight="%s" font-family="%s"%s%s>%s</text>'),
    x, y, size, fill, anchor, weight, family,
    if (is.null(ls)) "" else sprintf(' letter-spacing="%.1f"', ls),
    if (is.null(style)) "" else sprintf(' font-style="%s"', style), label))
}
el_check <- function(s, cx, cy, col = "white", sw = 3, scale = 1) {
  push(s, sprintf(paste0('<path d="M %.1f %.1f L %.1f %.1f L %.1f %.1f" fill="none" ',
    'stroke="%s" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round"/>'),
    cx - 5.5 * scale, cy + 0.5 * scale, cx - 1.5 * scale, cy + 4.5 * scale,
    cx + 6 * scale, cy - 5 * scale, col, sw))
}
fig_title <- function(s, title, subtitle, sub_mono = FALSE) {
  el_text(s, s$w / 2, 44, title, size = 26, weight = "bold")
  if (sub_mono)
    el_text(s, s$w / 2, 74, subtitle, size = 15, fill = GREY, family = MONO)
  else
    el_text(s, s$w / 2, 72, toupper(subtitle), size = 12, fill = GREY, ls = 3)
}
# Colored header banner with a small pennant point at bottom center.
pennant <- function(s, x, y, w, h, fill, label, tsize = 14, notch = 7) {
  el_polygon(s, c(x, x + w, x + w, x + w / 2, x),
                c(y, y, y + h, y + h + notch, y + h), fill)
  el_text(s, x + w / 2, y + h / 2 + tsize * 0.36, label, size = tsize,
          fill = "white", weight = "bold")
}
arrow_head <- function(s, x, y, angle, size = 9, col = NAVY) {
  a <- angle * pi / 180
  rot <- function(px, py) c(x + px * cos(a) - py * sin(a), y + px * sin(a) + py * cos(a))
  p1 <- rot(0, 0); p2 <- rot(-size * 1.6, -size * 0.8); p3 <- rot(-size * 1.6, size * 0.8)
  el_polygon(s, c(p1[1], p2[1], p3[1]), c(p1[2], p2[2], p3[2]), col)
}
# Base-R flavored trend frame: dashed grid + y labels; returns coordinate maps.
plot_frame <- function(s, px, py, pw, ph, years, ydom, yticks,
                       xlabels = TRUE, ylabels = TRUE, lab_size = 11.5,
                       xlab_every = 1) {
  n <- length(years)
  xf <- function(yr) px + pw * (match(yr, years) - 0.5) / n
  yf <- function(v) py + ph - ph * (v - ydom[1]) / (ydom[2] - ydom[1])
  for (t in yticks) {
    el_line(s, px, yf(t), px + pw, yf(t), "#CFCFCF", 1, dash = "5,5")
    if (ylabels) el_text(s, px - 8, yf(t) + 4, format(t, big.mark = ","),
                         size = lab_size, fill = GREY, anchor = "end")
  }
  el_line(s, px, py + ph, px + pw, py + ph, "#3A3A3A", 1.6)
  if (xlabels) for (i in seq(1, n, by = xlab_every))
    el_text(s, xf(years[i]), py + ph + 18, years[i], size = lab_size, fill = GREY)
  list(xf = xf, yf = yf)
}

# ==============================================================================
# Shared row spec for figures 1 and 2: the eight panel_type x panel_spell cases
# ==============================================================================
YEARS <- 2018:2024
CASES <- list(
  list(id = "A", type = "persistent", spell = "seamless",  obs = 2018:2024),
  list(id = "B", type = "persistent", spell = "segmented", obs = c(2018, 2019, 2021, 2022, 2024)),
  list(id = "C", type = "entrant",    spell = "seamless",  obs = 2020:2024),
  list(id = "D", type = "entrant",    spell = "segmented", obs = c(2020, 2021, 2023, 2024)),
  list(id = "E", type = "exit",       spell = "seamless",  obs = 2018:2021),
  list(id = "F", type = "exit",       spell = "segmented", obs = c(2018, 2020, 2021)),
  list(id = "G", type = "transient",  spell = "seamless",  obs = 2019:2022),
  list(id = "H", type = "transient",  spell = "segmented", obs = c(2019, 2021, 2022))
)
case_gaps <- function(cs) setdiff(seq(min(cs$obs), max(cs$obs)), cs$obs)

# ==============================================================================
# Figure 1: the eight membership patterns
# ==============================================================================
fig_panel_types <- function() {
  s <- svg_new(1060, 748)
  fig_title(s, "Panel Membership Patterns",
            "panel_type  ×  panel_spell  —  as classified by panel_describe()")

  x0 <- 34; col_id <- 62; col_type <- 132; col_spell <- 120; col_yr <- 96
  hx <- c(x0, x0 + col_id, x0 + col_id + col_type)
  yx0 <- x0 + col_id + col_type + col_spell
  hy <- 102; hh <- 38; ry0 <- hy + hh + 14; rh <- 58

  pennant(s, hx[1], hy, col_id - 4, hh, "#9AA3B2", "EIN2", 13)
  pennant(s, hx[2], hy, col_type - 4, hh, "#9AA3B2", "panel_type", 13)
  pennant(s, hx[3], hy, col_spell - 4, hh, "#9AA3B2", "panel_spell", 13)
  for (i in seq_along(YEARS))
    pennant(s, yx0 + (i - 1) * col_yr, hy, col_yr - 4, hh, NAVY, YEARS[i])

  for (r in seq_along(CASES)) {
    cs <- CASES[[r]]; y <- ry0 + (r - 1) * rh; cy <- y + rh / 2
    col <- TYPE_COLOR[[cs$type]]
    el_rect(s, hx[1], y, col_id - 4, rh - 6, LIGHT, rx = 6)
    el_text(s, hx[1] + (col_id - 4) / 2, cy + 3, cs$id, size = 17, weight = "bold")
    el_rect(s, hx[2] + 6, y + (rh - 34) / 2 - 3, col_type - 16, 34, col, rx = 17)
    el_text(s, hx[2] + col_type / 2 - 2, cy + 2, cs$type, size = 14,
            fill = "white", weight = "bold")
    el_text(s, hx[3] + (col_spell - 4) / 2, cy + 2, cs$spell, size = 14,
            fill = if (cs$spell == "segmented") RED else NAVY,
            style = if (cs$spell == "segmented") "italic" else NULL)
    gaps <- case_gaps(cs)
    for (i in seq_along(YEARS)) {
      cx <- yx0 + (i - 1) * col_yr + (col_yr - 4) / 2
      el_rect(s, yx0 + (i - 1) * col_yr, y, col_yr - 4, rh - 6, "white",
              stroke = BORDER, rx = 6)
      if (YEARS[i] %in% cs$obs) {
        el_circle(s, cx, cy - 1, 13.5, col)
        el_check(s, cx, cy - 1)
      } else if (YEARS[i] %in% gaps) {
        el_circle(s, cx, cy - 1, 13.5, "white", stroke = RED, sw = 2, dash = "4,3.5")
      }
    }
    if (r %% 2 == 0 && r < 8)
      el_line(s, x0, y + rh - 3 + 2.5, yx0 + 7 * col_yr - 4, y + rh - 3 + 2.5,
              "#C4C9D4", 1.4)
  }

  ly <- ry0 + 8 * rh + 22
  el_circle(s, x0 + 12, ly, 10, GREEN); el_check(s, x0 + 12, ly, scale = 0.75, sw = 2.4)
  el_text(s, x0 + 30, ly + 4, "990 filed (year observed)", size = 13,
          fill = GREY, anchor = "start")
  el_circle(s, x0 + 262, ly, 10, "white", stroke = RED, sw = 2, dash = "4,3.5")
  el_text(s, x0 + 280, ly + 4, "interior gap → spell is segmented",
          size = 13, fill = GREY, anchor = "start")
  el_rect(s, x0 + 556, ly - 10, 20, 20, "white", stroke = BORDER, rx = 4)
  el_text(s, x0 + 584, ly + 4, "outside the org's spell (entry / exit boundary)",
          size = 13, fill = GREY, anchor = "start")
  svg_save(s, file.path(fig_dir, "panel-types.svg"))
}

# ==============================================================================
# Figure 2: panel_filter() decision tree
# ==============================================================================
fig_panel_filter <- function() {
  s <- svg_new(1120, 856)
  fig_title(s, "Selecting Organizations with panel_filter()",
            "keep only the membership patterns your design calls for")

  dot_w <- 52; id_w <- 46; tag_w <- 104
  mini_table <- function(x0, y0, rows, rowh, dot_r, show_tag, show_years,
                         frame_col = "#C4C9D4") {
    w <- id_w + 7 * dot_w + if (show_tag) tag_w else 0
    if (show_years) for (i in seq_along(YEARS))
      el_text(s, x0 + id_w + (i - 0.5) * dot_w, y0 - 8, YEARS[i],
              size = 11, fill = GREY)
    for (r in seq_along(rows)) {
      cs <- rows[[r]]; y <- y0 + (r - 1) * rowh; cy <- y + rowh / 2
      col <- TYPE_COLOR[[cs$type]]
      el_rect(s, x0, y + 1, id_w - 6, rowh - 4, LIGHT, rx = 5)
      el_text(s, x0 + (id_w - 6) / 2, cy + 4, cs$id, size = 13, weight = "bold")
      gaps <- case_gaps(cs)
      for (i in seq_along(YEARS)) {
        cx <- x0 + id_w + (i - 0.5) * dot_w
        if (YEARS[i] %in% cs$obs) el_circle(s, cx, cy, dot_r, col)
        else if (YEARS[i] %in% gaps)
          el_circle(s, cx, cy, dot_r, "white", stroke = RED, sw = 1.6, dash = "3,2.6")
        else el_circle(s, cx, cy, 2, "#D8DBE2")
      }
      if (show_tag)
        el_text(s, x0 + id_w + 7 * dot_w + 8, cy + 4, cs$type, size = 12,
                fill = col, anchor = "start", weight = "bold")
    }
    el_rect(s, x0 - 8, y0 - 6, w + 12, length(rows) * rowh + 12, "none",
            stroke = frame_col, sw = 1.4, rx = 8)
    invisible(w)
  }

  top_x <- (1120 - (id_w + 7 * dot_w + tag_w)) / 2
  mini_table(top_x, 132, CASES, 33, 8.5, show_tag = TRUE, show_years = TRUE)
  el_text(s, 1120 / 2, 118 - 16, "mixed panel — all membership types",
          size = 13, fill = GREY, weight = "bold")

  top_cx <- 1120 / 2; top_by <- 132 + 8 * 33 + 10
  kids <- list(
    list(x = 116, code = 'panel_filter(panel_type = "persistent")',
         rows = CASES[1:2], col = GREEN, label = "persistent only"),
    list(x = 640, code = 'panel_filter(panel_type = "entrant")',
         rows = CASES[3:4], col = BLUE, label = "entrants only")
  )
  kid_y <- 636
  for (k in kids) {
    kx_c <- k$x + (id_w + 7 * dot_w) / 2
    push(s, sprintf(paste0('<path d="M %.1f %.1f C %.1f %.1f, %.1f %.1f, %.1f %.1f" ',
      'fill="none" stroke="%s" stroke-width="2.4"/>'),
      top_cx, top_by + 4, top_cx, top_by + 70, kx_c, kid_y - 130, kx_c, kid_y - 46, NAVY))
    arrow_head(s, kx_c, kid_y - 42, 90)
    chip_w <- 7.4 * nchar(k$code) + 26
    el_rect(s, kx_c - chip_w / 2, kid_y - 116, chip_w, 30, LIGHT,
            stroke = BORDER, rx = 15)
    el_text(s, kx_c, kid_y - 96, k$code, size = 13, family = MONO)
    el_rect(s, k$x - 8, kid_y - 30, id_w + 7 * dot_w + 12, 22, k$col, rx = 6)
    el_text(s, kx_c, kid_y - 15, k$label, size = 12.5, fill = "white", weight = "bold")
    mini_table(k$x, kid_y, k$rows, 38, 9.5, show_tag = FALSE, show_years = FALSE,
               frame_col = k$col)
  }
  el_text(s, 1120 / 2, kid_y + 2 * 38 + 46,
          'combine criteria to balance the panel:  panel_filter(panel_type = "persistent", spell = "seamless")',
          size = 13, fill = GREY, family = MONO)
  svg_save(s, file.path(fig_dir, "panel-filter.svg"))
}

# ==============================================================================
# Figure 3: panel_impute() -- table view and trend view
# ==============================================================================
fig_panel_impute <- function() {
  years <- 2018:2023
  raw <- data.frame(
    EIN2 = rep(LETTERS[1:5], each = 6), TAX_YEAR = rep(years, 5),
    REV = c(120, 135,  NA, 160, 170, 185,
            300,  NA, 320,  NA, 355, 370,
             80,  95,  90,  NA, 105, 110,
            210, 220,  NA,  NA, 260, 275,
            500, 480, 495,  NA, 520, 510))
  obs <- raw[!is.na(raw$REV), ]                       # gap years absent, not NA
  done <- panel_impute(obs, method = "interpolate", vars = "REV")

  s <- svg_new(1180, 640)
  fig_title(s, "Filling Interior Gaps with panel_impute()",
            'panel_impute(method = "interpolate")   •   inserted rows are flagged imputed_row = TRUE',
            sub_mono = TRUE)

  x0 <- 40; id_w <- 56; yr_w <- 78; hy <- 112; hh <- 34; ry0 <- hy + hh + 13; rh <- 62
  pennant(s, x0, hy, id_w - 4, hh, "#9AA3B2", "EIN2", 12.5)
  for (i in seq_along(years))
    pennant(s, x0 + id_w + (i - 1) * yr_w, hy, yr_w - 4, hh, NAVY, years[i], 12.5)
  for (r in 1:5) {
    org <- LETTERS[r]; y <- ry0 + (r - 1) * rh; cy <- y + rh / 2
    el_rect(s, x0, y, id_w - 4, rh - 6, LIGHT, rx = 6)
    el_text(s, x0 + (id_w - 4) / 2, cy + 2, org, size = 16, weight = "bold")
    vals <- raw$REV[raw$EIN2 == org]
    for (i in seq_along(years)) {
      cx0 <- x0 + id_w + (i - 1) * yr_w
      if (is.na(vals[i])) {
        el_rect(s, cx0, y, yr_w - 4, rh - 6, "#FDF0EE", stroke = RED, sw = 1.4,
                rx = 6, dash = "5,4")
        el_text(s, cx0 + (yr_w - 4) / 2, cy + 3, "—", size = 16, fill = RED)
      } else {
        el_rect(s, cx0, y, yr_w - 4, rh - 6, "white", stroke = BORDER, rx = 6)
        el_text(s, cx0 + (yr_w - 4) / 2, cy + 3, format(vals[i]), size = 15.5)
      }
    }
  }
  tbl_w <- id_w + 6 * yr_w - 4
  el_text(s, x0 + tbl_w / 2, ry0 + 5 * rh + 22,
          "raw panel — total revenue ($K), segmented spells", size = 13, fill = GREY)

  ax <- x0 + tbl_w + 16
  el_line(s, ax + 6, 330, ax + 58, 330, NAVY, 2.6)
  arrow_head(s, ax + 62, 330, 0)
  el_text(s, ax + 33, 312, "impute", size = 12.5, fill = GREY, style = "italic")

  px <- 700; pw <- 424; prow_h <- rh
  for (r in 1:5) {
    org <- LETTERS[r]; y <- ry0 + (r - 1) * prow_h
    d <- done[done$EIN2 == org, ]; d <- d[order(d$TAX_YEAR), ]
    ydom <- range(d$REV) + c(-1, 1) * max(6, diff(range(d$REV)) * 0.28)
    xf <- function(yr) px + pw * (match(yr, years) - 0.5) / 6
    yf <- function(v) y + (rh - 10) - (rh - 14) * (v - ydom[1]) / (ydom[2] - ydom[1])
    el_rect(s, px - 46, y, 40, rh - 6, LIGHT, rx = 6)
    el_text(s, px - 26, y + rh / 2 + 2, org, size = 15, weight = "bold")
    el_line(s, px, y + rh - 8, px + pw, y + rh - 8, "#D8DBE2", 1)
    el_polyline(s, sapply(d$TAX_YEAR, xf), sapply(d$REV, yf), "#2B2B2B", 2.4)
    for (j in seq_len(nrow(d))) {
      cx <- xf(d$TAX_YEAR[j]); cyv <- yf(d$REV[j])
      if (d$imputed_row[j]) {
        el_circle(s, cx, cyv, 6, "white", stroke = ORANGE, sw = 3)
        el_text(s, cx, cyv - 11, format(round(d$REV[j])), size = 12,
                fill = ORANGE, weight = "bold")
      } else el_circle(s, cx, cyv, 5, "#2B2B2B")
    }
  }
  for (i in seq_along(years))
    el_text(s, px + pw * (i - 0.5) / 6, ry0 + 5 * rh + 6, years[i],
            size = 11.5, fill = GREY)
  ly <- ry0 + 5 * rh + 40; lx <- px - 40
  el_circle(s, lx, ly, 5, "#2B2B2B")
  el_text(s, lx + 12, ly + 4, "observed", size = 12.5, fill = GREY, anchor = "start")
  el_circle(s, lx + 116, ly, 6, "white", stroke = ORANGE, sw = 3)
  el_text(s, lx + 128, ly + 4, "imputed (interpolated between bracketing years)",
          size = 12.5, fill = GREY, anchor = "start")
  svg_save(s, file.path(fig_dir, "panel-impute.svg"))
}

# ==============================================================================
# Figure 4: panel_smooth() -- window and weights arguments
# ==============================================================================
fig_panel_smooth <- function() {
  years <- 2010:2023
  set.seed(990)
  rev <- round(160 + 13 * (seq_along(years) - 1) + rnorm(length(years), 0, 42))
  df <- data.frame(EIN2 = "A", TAX_YEAR = years, REV = as.numeric(rev))
  sm <- function(w, wt) panel_smooth(df, "REV", window = w, weights = wt,
                                     verbose = FALSE)$REV
  panels <- list(
    list(title = "raw series  (after panel_complete())", col = "#2B2B2B",
         vals = df$REV, raw_under = FALSE),
    list(title = 'panel_smooth(window = 3, weights = "equal")', col = TEAL,
         vals = sm(3, "equal"), raw_under = TRUE),
    list(title = 'panel_smooth(window = 5, weights = "equal")', col = BLUE,
         vals = sm(5, "equal"), raw_under = TRUE),
    list(title = 'panel_smooth(window = 3, weights = "decay")', col = PURPLE,
         vals = sm(3, "decay"), raw_under = TRUE))

  s <- svg_new(1120, 792)
  fig_title(s, "Smoothing Panel Series with panel_smooth()",
            "wider windows smooth more; decay weights keep more of each year's own value")
  ydom <- range(df$REV) + c(-1, 1) * diff(range(df$REV)) * 0.08
  yticks <- pretty(df$REV, 4)
  yticks <- yticks[yticks >= ydom[1] & yticks <= ydom[2]]
  pos <- list(c(70, 122), c(620, 122), c(70, 452), c(620, 452))
  for (i in seq_along(panels)) {
    p <- panels[[i]]; px <- pos[[i]][1]; py <- pos[[i]][2]
    el_text(s, px + 215, py + 8, p$title, size = 14, family = MONO,
            fill = p$col, weight = "bold")
    f <- plot_frame(s, px + 12, py + 26, 430, 220, years, ydom, yticks,
                    xlab_every = 2)
    if (p$raw_under) {
      el_polyline(s, sapply(years, f$xf), sapply(df$REV, f$yf), "#C7CBD4", 1.8)
      for (yr in years) el_circle(s, f$xf(yr), f$yf(df$REV[match(yr, years)]),
                                  2.6, "#C7CBD4")
    }
    el_polyline(s, sapply(years, f$xf), sapply(p$vals, f$yf), p$col, 3)
    for (j in seq_along(years)) el_circle(s, f$xf(years[j]), f$yf(p$vals[j]),
                                          5.2, p$col)
  }
  ly <- 762
  el_line(s, 330, ly, 366, ly, "#C7CBD4", 2.5); el_circle(s, 348, ly, 2.6, "#C7CBD4")
  el_text(s, 374, ly + 4, "raw values", size = 13, fill = GREY, anchor = "start")
  el_line(s, 500, ly, 536, ly, TEAL, 3); el_circle(s, 518, ly, 4.6, TEAL)
  el_text(s, 544, ly + 4, "smoothed values (weighted rolling average within each EIN2)",
          size = 13, fill = GREY, anchor = "start")
  svg_save(s, file.path(fig_dir, "panel-smooth.svg"))
}

# ==============================================================================
# Figure 5: smoothing breaks accounting identities; reconcile() restores them
# ==============================================================================
fig_reconcile <- function() {
  years <- 2016:2023
  contr  <- c(90, 105,  98, 112, 120, 108, 125, 132)
  earned <- c(62,  70,  66,  73,  80,  74,  88,  92)   # 2019 filled by impute
  err    <- c( 0,  40,   0,  22,   0, -45,   0,  12)   # filing discrepancies
  total  <- contr + earned + err
  df <- data.frame(EIN2 = "A", TAX_YEAR = rep(years, 3))
  long <- data.frame(EIN2 = "A", TAX_YEAR = years,
                     CONTR = contr, EARNED = earned, TOTAL = total)
  smd <- panel_smooth(long, c("CONTR", "EARNED", "TOTAL"), window = 3,
                      weights = "equal", verbose = FALSE)
  res <- smd$CONTR + smd$EARNED - smd$TOTAL           # identity residual
  # reconcile(): minimal weighted-least-squares change so CONTR + EARNED = TOTAL
  rec <- smd
  rec$CONTR  <- smd$CONTR  - res / 3
  rec$EARNED <- smd$EARNED - res / 3
  rec$TOTAL  <- smd$TOTAL  + res / 3
  res2 <- rec$CONTR + rec$EARNED - rec$TOTAL

  s <- svg_new(1180, 700)
  fig_title(s, "Smoothing Breaks Accounting Identities — reconcile() Restores Them",
            "each variable is smoothed independently, so contributions + earned no longer equals total revenue")

  all_v <- c(smd$CONTR, smd$EARNED, smd$TOTAL, rec$TOTAL,
             smd$CONTR + smd$EARNED)
  ydom <- c(min(all_v) - 18, max(all_v) + 18)
  yticks <- pretty(all_v, 4); yticks <- yticks[yticks >= ydom[1] & yticks <= ydom[2]]

  draw_side <- function(px, d, resid, sum_col, badge, badge_col, code) {
    el_text(s, px + 230, 112, code, size = 15, family = MONO, weight = "bold")
    bw <- 7.2 * nchar(badge) + 26
    el_rect(s, px + 230 - bw / 2, 122, bw, 24, badge_col, rx = 12)
    el_text(s, px + 230, 138.5, badge, size = 12.5, fill = "white", weight = "bold")
    f <- plot_frame(s, px + 30, 162, 430, 240, years, ydom, yticks)
    sum_v <- d$CONTR + d$EARNED
    if (max(abs(resid)) > 0.01) for (j in seq_along(years)) {
      el_line(s, f$xf(years[j]), f$yf(sum_v[j]), f$xf(years[j]), f$yf(d$TOTAL[j]),
              RED, 2)
    }
    el_polyline(s, sapply(years, f$xf), sapply(d$EARNED, f$yf), GREEN, 2.6)
    el_polyline(s, sapply(years, f$xf), sapply(d$CONTR, f$yf), BLUE, 2.6)
    el_polyline(s, sapply(years, f$xf), sapply(d$TOTAL, f$yf), NAVY, 3.2)
    el_polyline(s, sapply(years, f$xf), sapply(sum_v, f$yf), sum_col, 2.4,
                dash = "7,5")
    for (j in seq_along(years)) {
      el_circle(s, f$xf(years[j]), f$yf(d$EARNED[j]), 4.4, GREEN)
      el_circle(s, f$xf(years[j]), f$yf(d$CONTR[j]), 4.4, BLUE)
      el_circle(s, f$xf(years[j]), f$yf(d$TOTAL[j]), 5, NAVY)
    }
    ry <- 452
    for (j in seq_along(years)) {
      v <- resid[j]
      lab <- if (abs(v) < 0.01) "0" else sprintf("%+.1f", v)
      el_rect(s, f$xf(years[j]) - 24, ry + 4, 48, 26,
              if (abs(v) < 0.01) "#EAF6EC" else "#FDF0EE", rx = 6)
      el_text(s, f$xf(years[j]), ry + 22, lab, size = 12.5,
              fill = if (abs(v) < 0.01) DGREEN else RED, weight = "bold")
    }
    el_text(s, px + 245, ry + 50,
            "identity residual   (contributions + earned − total)",
            size = 11.5, fill = GREY)
  }
  draw_side(60, smd, res, RED, "identity broken", RED,
            'after panel_smooth()')
  draw_side(660, rec, res2, DGREEN, "identity restored", DGREEN,
            'after reconcile()')

  el_line(s, 560, 280, 620, 280, NAVY, 2.6); arrow_head(s, 624, 280, 0)
  el_text(s, 592, 262, "reconcile()", size = 12.5, fill = GREY, family = MONO)

  ly <- 552
  leg <- list(list(BLUE, "contributions", NULL),
              list(GREEN, "earned revenue", NULL),
              list(NAVY, "total revenue (as filed)", NULL),
              list(RED, "contributions + earned (sum of parts)", "7,5"))
  lxs <- c(120, 320, 540, 810)
  for (i in seq_along(leg)) {
    g <- leg[[i]]; lx <- lxs[i]
    el_line(s, lx, ly, lx + 34, ly, g[[1]], if (is.null(g[[3]])) 3 else 2.4,
            dash = g[[3]])
    if (is.null(g[[3]])) el_circle(s, lx + 17, ly, 4.4, g[[1]])
    el_text(s, lx + 42, ly + 4, g[[2]], size = 13, fill = GREY, anchor = "start")
  }
  el_text(s, 1180 / 2, ly + 34,
          "reconcile() makes the smallest weighted adjustment to each variable so every accounting identity holds exactly",
          size = 13, fill = GREY, style = "italic")
  svg_save(s, file.path(fig_dir, "panel-reconcile.svg"))
}

# ==============================================================================
# Figure 6: merge_tables() -- five core tables joined into one wide row per
# filing, within a single year
# ==============================================================================
fig_merge_tables <- function() {
  src <- list(
    list(code = "P00", part = "HEADER",   col = NAVY,   field = "ORG_NAME_L1",
         vals = c("Acme Arts", "Bay Clinic", "Casa Verde")),
    list(code = "P01", part = "SUMMARY",  col = TEAL,   field = "REV_TOT_CY",
         vals = c("152", "305", "88")),
    list(code = "P08", part = "REVENUE",  col = GREEN,  field = "REV_CONTR",
         vals = c("90", "120", "30")),
    list(code = "P09", part = "EXPENSES", col = AMBER,  field = "EXP_TOT",
         vals = c("140", "290", "75")),
    list(code = "P10", part = "BALANCE",  col = PURPLE, field = "ASSET_EOY",
         vals = c("610", "940", NA)))          # C has no balance-sheet part
  orgs <- c("A", "B", "C")

  s <- svg_new(1180, 560)
  fig_title(s, "Merging the Five Core Tables Within One Year",
            "merge_tables(): full outer join on the filing keys  •  one wide row per filing",
            sub_mono = TRUE)
  el_rect(s, 40, 92, 150, 26, LIGHT, stroke = BORDER, rx = 13)
  el_text(s, 115, 110, "TAX_YEAR = 2019", size = 12.5, family = MONO)

  id_w <- 64; group_w <- 208; gx <- function(i) 40 + id_w + (i - 1) * group_w
  key_w <- 52; fld_w <- 150; ty <- 132; cny <- 172; ry <- 194; rh <- 28

  for (i in seq_along(src)) {
    t <- src[[i]]; sx <- gx(i) + 3
    pennant(s, sx, ty, key_w + fld_w, 28, t$col,
            paste0(t$code, " · ", t$part), 12, notch = 6)
    el_rect(s, sx, cny, key_w, 20, "#DADDE4")
    el_text(s, sx + key_w / 2, cny + 14, "EIN2", size = 10.5, weight = "bold")
    el_rect(s, sx + key_w, cny, fld_w, 20, "#EDEFF3")
    el_text(s, sx + key_w + fld_w / 2, cny + 14, t$field, size = 10.5,
            family = MONO)
    n <- sum(!is.na(t$vals))
    for (r in seq_len(n)) {
      y <- ry + (r - 1) * rh
      el_rect(s, sx, y, key_w, rh, LIGHT, stroke = "white")
      el_text(s, sx + key_w / 2, y + rh / 2 + 4, orgs[r], size = 13,
              weight = "bold")
      el_rect(s, sx + key_w, y, fld_w, rh, "white", stroke = BORDER)
      el_text(s, sx + key_w + fld_w / 2, y + rh / 2 + 4, t$vals[r], size = 12.5)
    }
    cx <- sx + (key_w + fld_w) / 2; by <- ry + n * rh
    el_line(s, cx, by + 6, cx, 318, "#9AA3B2", 2)
    arrow_head(s, cx, 322, 90, size = 8, col = "#9AA3B2")
  }

  my <- 332; mry <- my + 28 + 12; mrh <- 30
  pennant(s, 40, my, id_w - 4, 28, "#9AA3B2", "EIN2", 12, notch = 6)
  for (i in seq_along(src))
    pennant(s, gx(i) + 3, my, group_w - 6, 28, src[[i]]$col, src[[i]]$field,
            12, notch = 6)
  for (r in 1:3) {
    y <- mry + (r - 1) * mrh
    el_rect(s, 40, y, id_w - 4, mrh - 4, LIGHT, rx = 5)
    el_text(s, 40 + (id_w - 4) / 2, y + mrh / 2 + 3, orgs[r], size = 14,
            weight = "bold")
    for (i in seq_along(src)) {
      v <- src[[i]]$vals[r]
      if (is.na(v)) {
        el_rect(s, gx(i) + 3, y, group_w - 6, mrh - 4, "#F7F8FA",
                stroke = BORDER, rx = 5)
        el_text(s, gx(i) + group_w / 2, y + mrh / 2 + 3, "NA", size = 12.5,
                fill = "#B6BCC9", style = "italic")
      } else {
        el_rect(s, gx(i) + 3, y, group_w - 6, mrh - 4, "white",
                stroke = BORDER, rx = 5)
        el_text(s, gx(i) + group_w / 2, y + mrh / 2 + 3, v, size = 13)
      }
    }
  }
  el_text(s, 1180 / 2, mry + 3 * mrh + 26,
          "the join is a full outer join — C filed no balance-sheet part, so its row is kept with the P10 fields set to NA",
          size = 12.5, fill = GREY)
  el_text(s, 1180 / 2, mry + 3 * mrh + 48,
          "every table carries the same filing keys:  EIN2 (org)  ×  TAX_YEAR (year)  ×  OBJECTID (filed return)",
          size = 12, fill = GREY, family = MONO)
  svg_save(s, file.path(fig_dir, "merge-tables.svg"))
}

# ==============================================================================
# Figure 7: stacking the merged years into one long panel
# ==============================================================================
fig_stack_years <- function() {
  yrs <- 2019:2022
  yr_col <- c(`2019` = GREEN, `2020` = BLUE, `2021` = AMBER, `2022` = PURPLE)
  vals <- list(   # org -> year -> c(REV, EXP, ASSET)
    A = list(`2019` = c(152, 140, 610), `2020` = c(160, 147, 625),
             `2021` = c(171, 150, 640), `2022` = c(180, 162, 655)),
    B = list(`2019` = c(305, 290, 940), `2020` = c(312, 301, 955),
             `2021` = c(298, 288, 930), `2022` = c(315, 300, 970)))
  cw <- c(44, 72, 78, 78, 78); cn <- c("EIN2", "TAX_YEAR", "REV", "EXP", "ASSET")
  tw <- sum(cw)
  col_x <- function(x0, j) x0 + c(0, cumsum(cw))[j]

  s <- svg_new(1180, 700)
  fig_title(s, "Stacking Merged Years into a Long Panel",
            "the per-year tables share one harmonized layout, so rows append into one file  •  one row per EIN2 × TAX_YEAR")

  draw_row <- function(x0, y, org, yr, rh = 30) {
    el_rect(s, col_x(x0, 1), y, cw[1], rh, LIGHT, stroke = "white")
    el_text(s, col_x(x0, 1) + cw[1] / 2, y + rh / 2 + 4, org, size = 13,
            weight = "bold")
    el_rect(s, col_x(x0, 2), y, cw[2], rh, "white", stroke = BORDER)
    el_rect(s, col_x(x0, 2) + 7, y + 5, cw[2] - 14, rh - 10, yr_col[[yr]], rx = 10)
    el_text(s, col_x(x0, 2) + cw[2] / 2, y + rh / 2 + 4, yr, size = 12,
            fill = "white", weight = "bold")
    v <- vals[[org]][[yr]]
    for (j in 3:5) {
      el_rect(s, col_x(x0, j), y, cw[j], rh, "white", stroke = BORDER)
      el_text(s, col_x(x0, j) + cw[j] / 2, y + rh / 2 + 4, v[j - 2], size = 12.5)
    }
  }
  draw_colnames <- function(x0, y) for (j in seq_along(cn)) {
    el_rect(s, col_x(x0, j), y, cw[j], 18, "#EDEFF3")
    el_text(s, col_x(x0, j) + cw[j] / 2, y + 13, cn[j], size = 9.5, family = MONO)
  }

  lx <- 70
  for (i in seq_along(yrs)) {
    yr <- as.character(yrs[i]); y0 <- 128 + (i - 1) * 130
    el_rect(s, lx, y0, tw, 22, yr_col[[yr]], rx = 6)
    el_text(s, lx + tw / 2, y0 + 15.5, paste0("merged table — ", yr),
            size = 12, fill = "white", weight = "bold")
    draw_colnames(lx, y0 + 22)
    for (r in 1:2) draw_row(lx, y0 + 40 + (r - 1) * 30, c("A", "B")[r], yr)
  }

  rx0 <- 700; ry0 <- 225
  el_rect(s, rx0, ry0, tw, 22, NAVY, rx = 6)
  el_text(s, rx0 + tw / 2, ry0 + 15.5,
          "long panel — one row per EIN2 × TAX_YEAR", size = 12,
          fill = "white", weight = "bold")
  draw_colnames(rx0, ry0 + 22)
  for (i in seq_along(yrs)) {
    yr <- as.character(yrs[i])
    for (r in 1:2)
      draw_row(rx0, ry0 + 40 + ((i - 1) * 2 + r - 1) * 30, c("A", "B")[r], yr)
    if (i < 4) el_line(s, rx0, ry0 + 40 + i * 60, rx0 + tw, ry0 + 40 + i * 60,
                       "#C4C9D4", 1.6)
  }

  for (i in seq_along(yrs)) {
    yr <- as.character(yrs[i])
    sy <- 128 + (i - 1) * 130 + 60; ey <- ry0 + 40 + (i - 1) * 60 + 30
    push(s, sprintf(paste0('<path d="M %.1f %.1f C %.1f %.1f, %.1f %.1f, %.1f %.1f" ',
      'fill="none" stroke="%s" stroke-width="2.4"/>'),
      lx + tw + 8, sy, lx + tw + 130, sy, rx0 - 140, ey, rx0 - 12, ey, yr_col[[yr]]))
    arrow_head(s, rx0 - 8, ey, 0, size = 8, col = yr_col[[yr]])
  }
  el_text(s, 1180 / 2, 666,
          "panelize(tables = c(\"P00\",\"P01\",\"P08\",\"P09\",\"P10\"), years = 2019:2022)  merges within each year, then stacks the years",
          size = 12.5, fill = GREY, family = MONO)
  svg_save(s, file.path(fig_dir, "stack-years.svg"))
}

# ==============================================================================
# Figure 8: bmf = TRUE -- BMF organization traits appended to the 990 panel
# ==============================================================================
fig_bmf_merge <- function() {
  panel_rows <- list(
    list("A", 2019, 152, 610), list("A", 2020, 160, 625),
    list("B", 2019, 305, 940), list("B", 2020, 312, 955),
    list("C", 2019,  88, 210), list("C", 2020,  95, 220))
  bmf <- list(A = c("A20", "NY"), B = c("E22", "CA"))   # no row for C
  BMF_TINT <- "#EAF7F6"

  s <- svg_new(1180, 720)
  fig_title(s, "Attaching Organization Traits with the BMF",
            "panelize(bmf = TRUE)  •  left join on EIN2 — one BMF row per org, broadcast to every filing year",
            sub_mono = TRUE)

  p_cw <- c(46, 74, 84, 84); p_cn <- c("EIN2", "TAX_YEAR", "REV", "ASSET")
  b_cw <- c(46, 84, 70); b_cn <- c("EIN2", "NTEE", "STATE")
  cell <- function(x, y, w, h, txt, fill = "white", tfill = NAVY, bold = FALSE,
                   italic = FALSE, size = 12.5) {
    el_rect(s, x, y, w, h, fill, stroke = if (fill == LIGHT) "white" else BORDER)
    el_text(s, x + w / 2, y + h / 2 + 4, txt, size = size, fill = tfill,
            weight = if (bold) "bold" else "normal",
            style = if (italic) "italic" else NULL)
  }
  colnames_row <- function(x0, y, cws, cns) for (j in seq_along(cns)) {
    x <- x0 + c(0, cumsum(cws))[j]
    el_rect(s, x, y, cws[j], 18, "#EDEFF3")
    el_text(s, x + cws[j] / 2, y + 13, cns[j], size = 9.5, family = MONO)
  }

  px0 <- 70; py0 <- 126; rh <- 28
  el_rect(s, px0, py0, sum(p_cw), 22, NAVY, rx = 6)
  el_text(s, px0 + sum(p_cw) / 2, py0 + 15.5, "990 panel — org-years",
          size = 12, fill = "white", weight = "bold")
  colnames_row(px0, py0 + 22, p_cw, p_cn)
  for (r in seq_along(panel_rows)) {
    d <- panel_rows[[r]]; y <- py0 + 40 + (r - 1) * rh
    xs <- px0 + c(0, cumsum(p_cw))
    cell(xs[1], y, p_cw[1], rh, d[[1]], fill = LIGHT, bold = TRUE)
    for (j in 2:4) cell(xs[j], y, p_cw[j], rh, format(d[[j]]))
  }
  p_bot <- py0 + 40 + 6 * rh

  bx0 <- 780; by0 <- 126
  el_rect(s, bx0, by0, sum(b_cw), 22, TEAL, rx = 6)
  el_text(s, bx0 + sum(b_cw) / 2, by0 + 15.5, "BMF — one row per org",
          size = 12, fill = "white", weight = "bold")
  colnames_row(bx0, by0 + 22, b_cw, b_cn)
  for (r in seq_along(bmf)) {
    org <- names(bmf)[r]; y <- by0 + 40 + (r - 1) * rh
    xs <- bx0 + c(0, cumsum(b_cw))
    cell(xs[1], y, b_cw[1], rh, org, fill = LIGHT, bold = TRUE)
    cell(xs[2], y, b_cw[2], rh, bmf[[org]][1], fill = BMF_TINT)
    cell(xs[3], y, b_cw[3], rh, bmf[[org]][2], fill = BMF_TINT)
  }
  b_bot <- by0 + 40 + 2 * rh
  el_text(s, bx0 + sum(b_cw) / 2, b_bot + 18, "(no BMF row for org C)",
          size = 11.5, fill = GREY, style = "italic")

  m_cw <- c(p_cw, b_cw[2:3]); m_w <- sum(m_cw)
  mx0 <- (1180 - m_w) / 2; my0 <- 428
  split_x <- mx0 + sum(p_cw)
  el_rect(s, mx0, my0, sum(p_cw), 22, NAVY, rx = 6)
  el_text(s, mx0 + sum(p_cw) / 2, my0 + 15.5, "990 fields", size = 12,
          fill = "white", weight = "bold")
  el_rect(s, split_x + 2, my0, sum(b_cw[2:3]) - 2, 22, TEAL, rx = 6)
  el_text(s, split_x + sum(b_cw[2:3]) / 2, my0 + 15.5,
          "BMF traits →", size = 12, fill = "white", weight = "bold")
  colnames_row(mx0, my0 + 22, m_cw, c(p_cn, b_cn[2:3]))
  for (r in seq_along(panel_rows)) {
    d <- panel_rows[[r]]; y <- my0 + 40 + (r - 1) * rh
    xs <- mx0 + c(0, cumsum(m_cw))
    cell(xs[1], y, m_cw[1], rh, d[[1]], fill = LIGHT, bold = TRUE)
    for (j in 2:4) cell(xs[j], y, m_cw[j], rh, format(d[[j]]))
    tr <- bmf[[d[[1]]]]
    if (is.null(tr)) {
      cell(xs[5], y, m_cw[5], rh, "NA", fill = "#F7F8FA", tfill = "#B6BCC9",
           italic = TRUE)
      cell(xs[6], y, m_cw[6], rh, "NA", fill = "#F7F8FA", tfill = "#B6BCC9",
           italic = TRUE)
    } else {
      cell(xs[5], y, m_cw[5], rh, tr[1], fill = BMF_TINT)
      cell(xs[6], y, m_cw[6], rh, tr[2], fill = BMF_TINT)
    }
  }
  m_bot <- my0 + 40 + 6 * rh
  el_line(s, split_x + 1, my0 + 22, split_x + 1, m_bot, TEAL, 2.4)

  push(s, sprintf(paste0('<path d="M %.1f %.1f C %.1f %.1f, %.1f %.1f, %.1f %.1f" ',
    'fill="none" stroke="%s" stroke-width="2.4"/>'),
    px0 + sum(p_cw) / 2, p_bot + 8, px0 + sum(p_cw) / 2, p_bot + 60,
    mx0 + 120, my0 - 62, mx0 + 120, my0 - 10, NAVY))
  arrow_head(s, mx0 + 120, my0 - 6, 90, col = NAVY)
  push(s, sprintf(paste0('<path d="M %.1f %.1f C %.1f %.1f, %.1f %.1f, %.1f %.1f" ',
    'fill="none" stroke="%s" stroke-width="2.4"/>'),
    bx0 + sum(b_cw) / 2, b_bot + 30, bx0 + sum(b_cw) / 2, b_bot + 100,
    split_x + 80, my0 - 62, split_x + 80, my0 - 10, TEAL))
  arrow_head(s, split_x + 80, my0 - 6, 90, col = TEAL)
  chip <- "left join on EIN2"
  chip_w <- 7.4 * nchar(chip) + 26
  el_rect(s, bx0 + sum(b_cw) / 2 - chip_w / 2 + 40, b_bot + 62, chip_w, 26,
          LIGHT, stroke = BORDER, rx = 13)
  el_text(s, bx0 + sum(b_cw) / 2 + 40, b_bot + 80, chip, size = 12.5,
          family = MONO)

  el_text(s, 1180 / 2, m_bot + 34,
          "BMF traits are time-invariant — one value per organization, repeated for every year it appears.",
          size = 12.5, fill = GREY)
  el_text(s, 1180 / 2, m_bot + 54,
          "Filings without a BMF match (org C) are kept, with the BMF columns set to NA.",
          size = 12.5, fill = GREY)
  svg_save(s, file.path(fig_dir, "bmf-merge.svg"))
}

# ==============================================================================
# Figure 9: panel_balance() -- searching for the largest balanced rectangle
# ==============================================================================
fig_panel_balance <- function() {
  ord <- c("A", "C", "D", "E", "F", "G", "B", "H")   # kept orgs first
  cases <- CASES[match(ord, vapply(CASES, `[[`, "", "id"))]
  win <- c(2020, 2021); n_kept <- 6

  s <- svg_new(1120, 530)
  fig_title(s, "Searching for a Balanced Panel",
            'panel_balance(strategy = "max_rectangle") — the year window maximizing complete orgs × years coverage',
            sub_mono = TRUE)

  x0 <- 70; y0 <- 152; id_w <- 46; dot_w <- 52; rowh <- 34
  el_text(s, x0 + (id_w + 7 * dot_w) / 2, y0 - 30,
          "mixed panel — 8 orgs × 7 years", size = 13, fill = GREY,
          weight = "bold")
  for (i in seq_along(YEARS))
    el_text(s, x0 + id_w + (i - 0.5) * dot_w, y0 - 8, YEARS[i], size = 11,
            fill = GREY)
  wx <- x0 + id_w + (match(win[1], YEARS) - 1) * dot_w
  ww <- 2 * dot_w
  el_rect(s, wx, y0 - 2, ww, 8 * rowh + 4, "#EAF6EC")
  for (r in seq_along(cases)) {
    cs <- cases[[r]]; y <- y0 + (r - 1) * rowh; cy <- y + rowh / 2
    col <- TYPE_COLOR[[cs$type]]
    el_rect(s, x0, y + 1, id_w - 6, rowh - 4, LIGHT, rx = 5)
    el_text(s, x0 + (id_w - 6) / 2, cy + 4, cs$id, size = 13, weight = "bold")
    gaps <- case_gaps(cs)
    for (i in seq_along(YEARS)) {
      cx <- x0 + id_w + (i - 0.5) * dot_w
      if (YEARS[i] %in% cs$obs) el_circle(s, cx, cy, 8.5, col)
      else if (YEARS[i] %in% gaps)
        el_circle(s, cx, cy, 8.5, "white", stroke = RED, sw = 1.6, dash = "3,2.6")
      else el_circle(s, cx, cy, 2, "#D8DBE2")
    }
    if (r > n_kept)
      el_text(s, x0 + id_w + 7 * dot_w + 12, cy + 4,
              paste0("✗ missing ", win[1]), size = 11, fill = RED,
              anchor = "start")
  }
  el_rect(s, wx, y0 - 2, ww, n_kept * rowh + 2, "none", stroke = DGREEN,
          sw = 3, rx = 8)

  ax0 <- x0 + id_w + 7 * dot_w + 110; ax1 <- 838; ay <- y0 + 4 * rowh
  el_line(s, ax0, ay, ax1 - 6, ay, NAVY, 2.6)
  arrow_head(s, ax1, ay, 0)
  el_text(s, (ax0 + ax1) / 2, ay - 12, "trim to the block", size = 12,
          fill = GREY, style = "italic")

  rx0 <- 858; rdw <- 62; rw <- id_w + 2 * rdw
  ry_bar <- y0 + rowh - 6
  el_rect(s, rx0, ry_bar, rw, 22, DGREEN, rx = 6)
  el_text(s, rx0 + rw / 2, ry_bar + 15.5, "balanced block", size = 12,
          fill = "white", weight = "bold")
  for (i in 1:2)
    el_text(s, rx0 + id_w + (i - 0.5) * rdw, ry_bar + 40, win[i], size = 11,
            fill = GREY)
  ry0 <- ry_bar + 48
  for (r in seq_len(n_kept)) {
    cs <- cases[[r]]; y <- ry0 + (r - 1) * rowh; cy <- y + rowh / 2
    col <- TYPE_COLOR[[cs$type]]
    el_rect(s, rx0, y + 1, id_w - 6, rowh - 4, LIGHT, rx = 5)
    el_text(s, rx0 + (id_w - 6) / 2, cy + 4, cs$id, size = 13, weight = "bold")
    for (i in 1:2) el_circle(s, rx0 + id_w + (i - 0.5) * rdw, cy, 8.5, col)
  }
  el_rect(s, rx0 - 8, ry0 - 4, rw + 16, n_kept * rowh + 8, "none",
          stroke = DGREEN, sw = 1.6, rx = 8)
  el_text(s, rx0 + rw / 2, ry0 + n_kept * rowh + 24,
          "6 orgs × 2 years = 12 org-years", size = 12, fill = GREY)

  el_text(s, x0 + (id_w + 7 * dot_w) / 2 + 40, y0 + 8 * rowh + 24,
          "every kept org is observed in every kept year — orgs missing a year inside the window are dropped",
          size = 12, fill = GREY)
  el_text(s, 1120 / 2, y0 + 8 * rowh + 56,
          'to balance by pattern instead:  panel_filter(panel_type = "persistent", spell = "seamless")  keeps orgs spanning the full window (A only)',
          size = 12, fill = GREY, family = MONO)
  svg_save(s, file.path(fig_dir, "panel-balance.svg"))
}

# ==============================================================================
# Shared row spec for figures 10 and 11: a tall frame and the four rules that
# thin it (from the sampling-framework vignette)
# ==============================================================================
SFW_COLS <- c("EIN2", "TAX_YEAR", "geo_state_abbr", "subsection_code",
              "F9_01_REV_TOT_CY")
SFW_ROWS <- list(   # ein, year, state, 501c, revenue
  list("11-101", 2019, "GA", "3", "482,120"),
  list("11-102", 2020, "GA", "3", "1,250,900"),
  list("22-201", 2020, "FL", "3", "310,450"),
  list("22-202", 2019, "AL", "3", "88,700"),
  list("22-203", 2021, "NC", "3", "5,102,000"),
  list("11-103", 2021, "GA", "3", "64,300"),
  list("33-301", 2020, "GA", "4", "720,150"),
  list("33-302", 2019, "GA", "6", "15,800"),
  list("33-303", 2021, "GA", "19", "232,400"),
  list("11-104", 2019, "GA", "3", "976,000"),
  list("44-401", 2017, "GA", "3", "405,600"),
  list("44-402", 2018, "GA", "3", "359,100"),
  list("44-403", 2023, "GA", "3", "512,750"),
  list("55-501", 2020, "GA", "3", "0"),
  list("55-502", 2021, "GA", "3", "-12,500"),
  list("11-105", 2020, "GA", "3", "3,870,220"))
SFW_RULES <- list(   # name, rule text, rows dropped (indices), color
  list(name = "state",            text = 'geo_state_abbr in "GA"',
       rows = 3:5,   col = BLUE),
  list(name = "501c3",            text = 'subsection_code in "3"',
       rows = 7:9,   col = GREEN),
  list(name = "years",            text = "TAX_YEAR in 2019:2021",
       rows = 11:13, col = AMBER),
  list(name = "revenue positive", text = "F9_01_REV_TOT_CY > 0",
       rows = 14:15, col = PURPLE))
SFW_KEPT <- setdiff(seq_along(SFW_ROWS),
                    unlist(lapply(SFW_RULES, `[[`, "rows")))

# ==============================================================================
# Figure 10: a sample frame is a set of rules -- rule strips over a tall frame
# ==============================================================================
fig_sfw_rules <- function() {
  s <- svg_new(1160, 760)
  fig_title(s, "A Sample Frame Is a Set of Rules",
            'add_rule(sfw, name, "filter", column, op, values)  —  structured: a column, an operator, and values',
            sub_mono = TRUE)

  x0 <- 50; cw <- c(92, 88, 120, 128, 140); tw <- sum(cw)
  col_x <- function(j) x0 + c(0, cumsum(cw))[j]
  hy <- 104; hh <- 32; ry0 <- hy + hh + 12; rh <- 32
  pennant(s, col_x(1), hy, cw[1] - 4, hh, "#9AA3B2", "EIN2", 11.5, notch = 6)
  for (j in 2:5)
    pennant(s, col_x(j), hy, cw[j] - 4, hh, NAVY, SFW_COLS[j], 11.5, notch = 6)

  for (r in seq_along(SFW_ROWS)) {
    d <- SFW_ROWS[[r]]; y <- ry0 + (r - 1) * rh
    el_rect(s, col_x(1), y + 1, cw[1] - 4, rh - 3, LIGHT, rx = 4)
    el_text(s, col_x(1) + (cw[1] - 4) / 2, y + rh / 2 + 4, d[[1]], size = 11.5,
            weight = "bold")
    for (j in 2:5) {
      el_rect(s, col_x(j), y + 1, cw[j] - 4, rh - 3, "white", stroke = BORDER)
      el_text(s, col_x(j) + (cw[j] - 4) / 2, y + rh / 2 + 4, d[[j]], size = 12)
    }
    if (r %in% SFW_KEPT)
      el_check(s, x0 + tw + 12, y + rh / 2, col = DGREEN, sw = 2.2, scale = 0.7)
  }

  for (rule in SFW_RULES) {
    y1 <- ry0 + (min(rule$rows) - 1) * rh; y2 <- ry0 + max(rule$rows) * rh
    el_rect(s, x0 - 8, y1, 1160 - 40 - (x0 - 8), y2 - y1, rule$col,
            rx = 8, opacity = 0.10)
    el_rect(s, x0 - 8, y1, 1160 - 40 - (x0 - 8), y2 - y1, "none",
            stroke = rule$col, sw = 1.8, rx = 8)
    mid <- (y1 + y2) / 2
    lx <- x0 + tw + 44
    chip_w <- 7 * nchar(rule$name) + 22
    el_rect(s, lx, mid - 12, chip_w, 24, rule$col, rx = 12)
    el_text(s, lx + chip_w / 2, mid + 4, rule$name, size = 11.5, fill = "white",
            weight = "bold")
    el_text(s, lx + chip_w + 14, mid + 4.5,
            paste0("filter:  ", rule$text), size = 13, family = MONO,
            fill = NAVY, anchor = "start")
    el_text(s, 1160 - 52, mid + 4.5,
            paste0("−", length(rule$rows), " rows"), size = 12.5,
            fill = RED, weight = "bold", anchor = "end")
  }

  by <- ry0 + length(SFW_ROWS) * rh + 30
  el_check(s, x0 + 10, by - 4, col = DGREEN, sw = 2.2, scale = 0.7)
  el_text(s, x0 + 26, by,
          paste0("rows in no strip satisfy every rule — ",
                 length(SFW_KEPT), " of ", length(SFW_ROWS), " survive.",
                 "   Most rules are filters: each names exactly the rows it removes."),
          size = 13, fill = GREY, anchor = "start")
  svg_save(s, file.path(fig_dir, "sfw-rules.svg"))
}

# ==============================================================================
# Figure 11: apply_sfw() -- the manifest is a record of what dropped out
# ==============================================================================
fig_sfw_manifest <- function() {
  s <- svg_new(1160, 620)
  fig_title(s, "The Manifest Records What Dropped Out",
            'apply_sfw(df, sfw)  →  attr(out, "sfw_steps")  —  one row per rule: rows in, rows removed, rows out',
            sub_mono = TRUE)

  x0 <- 60; rw <- 150; ry0 <- 132; rh <- 24
  rule_of <- rep(NA_integer_, length(SFW_ROWS))
  for (i in seq_along(SFW_RULES)) rule_of[SFW_RULES[[i]]$rows] <- i
  el_text(s, x0 + rw / 2, ry0 - 14, "the frame, rule strips applied",
          size = 12, fill = GREY)
  for (r in seq_along(SFW_ROWS)) {
    y <- ry0 + (r - 1) * rh
    if (is.na(rule_of[r])) {
      el_rect(s, x0, y + 1, rw, rh - 3, "#EAF6EC", stroke = "#CBE7D0", rx = 4)
      el_text(s, x0 + rw / 2, y + rh / 2 + 4, SFW_ROWS[[r]][[1]], size = 11,
              fill = NAVY, weight = "bold")
      el_check(s, x0 + rw - 14, y + rh / 2, col = DGREEN, sw = 2, scale = 0.55)
    } else {
      col <- SFW_RULES[[rule_of[r]]]$col
      el_rect(s, x0, y + 1, rw, rh - 3, col, rx = 4, opacity = 0.22)
      el_rect(s, x0, y + 1, rw, rh - 3, "none", stroke = col, sw = 1.2, rx = 4)
      el_text(s, x0 + rw / 2, y + rh / 2 + 4, SFW_ROWS[[r]][[1]], size = 11,
              fill = "#7A828F")
      el_line(s, x0 + rw - 20, y + rh / 2 - 5, x0 + rw - 10, y + rh / 2 + 5,
              RED, 1.8, cap = "round")
      el_line(s, x0 + rw - 10, y + rh / 2 - 5, x0 + rw - 20, y + rh / 2 + 5,
              RED, 1.8, cap = "round")
    }
  }

  ax0 <- x0 + rw + 18; ax1 <- ax0 + 72
  ay <- ry0 + 8 * rh
  el_line(s, ax0, ay, ax1 - 6, ay, NAVY, 2.6)
  arrow_head(s, ax1, ay, 0)
  el_text(s, (ax0 + ax1) / 2, ay - 12, "apply_sfw()", size = 12, fill = GREY,
          family = MONO)

  lx0 <- ax1 + 22; ly0 <- 148; lrh <- 58
  cwl <- c(26, 250, 74, 96, 78, 220)   # key, criteria, in, removed, out, funnel
  cxl <- function(j) lx0 + c(0, cumsum(cwl))[j]
  heads <- c("", "criteria", "rows in", "removed", "rows out", "")
  for (j in 2:5)
    el_text(s, cxl(j) + cwl[j] / 2, ly0 - 10, heads[j], size = 11.5,
            fill = GREY, weight = "bold")
  n0 <- length(SFW_ROWS); n_in <- n0
  bar_max <- 200
  for (i in seq_along(SFW_RULES)) {
    rule <- SFW_RULES[[i]]; y <- ly0 + (i - 1) * lrh
    n_rm <- length(rule$rows); n_out <- n_in - n_rm
    el_rect(s, lx0 - 10, y, sum(cwl) + 20, lrh - 10, "white",
            stroke = BORDER, rx = 8)
    el_rect(s, cxl(1), y + (lrh - 10) / 2 - 8, 16, 16, rule$col, rx = 4)
    el_text(s, cxl(2) + 8, y + (lrh - 10) / 2 - 3, paste0("filter · ", rule$name),
            size = 11, fill = rule$col, anchor = "start", weight = "bold")
    el_text(s, cxl(2) + 8, y + (lrh - 10) / 2 + 14, rule$text, size = 12,
            family = MONO, anchor = "start")
    el_text(s, cxl(3) + cwl[3] / 2, y + (lrh - 10) / 2 + 6, n_in, size = 15)
    el_rect(s, cxl(4) + 10, y + (lrh - 10) / 2 - 12, cwl[4] - 20, 24,
            "#FDF0EE", rx = 12)
    el_text(s, cxl(4) + cwl[4] / 2, y + (lrh - 10) / 2 + 6,
            paste0("−", n_rm), size = 14, fill = RED, weight = "bold")
    el_text(s, cxl(5) + cwl[5] / 2, y + (lrh - 10) / 2 + 6, n_out, size = 15,
            weight = "bold")
    bx <- cxl(6) + 6; bh <- 16; byy <- y + (lrh - 10) / 2 - bh / 2
    w_out <- bar_max * n_out / n0; w_rm <- bar_max * n_rm / n0
    el_rect(s, bx, byy, w_out, bh, "#B9C0CC", rx = 3)
    el_rect(s, bx + w_out, byy, w_rm, bh, RED, rx = 3, opacity = 0.75)
    n_in <- n_out
  }
  fy <- ly0 + 4 * lrh + 6
  el_rect(s, lx0 - 10, fy, sum(cwl) + 20, 40, "#EAF6EC", stroke = DGREEN,
          sw = 1.6, rx = 8)
  el_text(s, lx0 + 12, fy + 25,
          paste0("kept: ", length(SFW_KEPT), " rows — every removal is attributed to a named rule"),
          size = 13.5, fill = DGREEN, weight = "bold", anchor = "start")
  bx <- cxl(6) + 6
  el_rect(s, bx, fy + 12, bar_max * length(SFW_KEPT) / n0, 16, DGREEN, rx = 3)

  el_text(s, 1160 / 2, fy + 78,
          "the manifest travels with the data — rerunning the frame reproduces the panel, and reviewers can audit every drop",
          size = 12.5, fill = GREY, style = "italic")
  svg_save(s, file.path(fig_dir, "sfw-manifest.svg"))
}

# ==============================================================================
# Figure 12: prefilter before you merge -- filters are cheap, merges are not
# ==============================================================================
fig_sfw_prefilter <- function() {
  s <- svg_new(1160, 800)
  fig_title(s, "Prefilter Before You Merge",
            "filters are cheap — one pass over a column.  merges are expensive — rows × columns held in RAM.")

  stack_rows <- function(x, y, w, h, n, keep_at = integer(0)) {
    gap <- h / n
    for (i in seq_len(n)) {
      yy <- y + (i - 0.5) * gap
      el_line(s, x + 8, yy, x + w - 8, yy,
              if (i %in% keep_at) DGREEN else "#DCE0E7",
              if (i %in% keep_at) 3 else 2)
    }
  }
  big_table <- function(x, title, col, badge, badge_col, note, keep_at) {
    el_rect(s, x, 118, 330, 26, col, rx = 7)
    el_text(s, x + 165, 136, title, size = 13, fill = "white", weight = "bold")
    el_rect(s, x, 144, 330, 200, "white", stroke = "#C4C9D4", sw = 1.4, rx = 4)
    stack_rows(x, 150, 330, 188, 30, keep_at)
    bw <- 7.4 * nchar(badge) + 26
    el_rect(s, x + 330 - bw - 8, 152, bw, 24, badge_col, rx = 12)
    el_text(s, x + 330 - bw / 2 - 8, 168.5, badge, size = 12, fill = "white",
            weight = "bold")
    el_text(s, x + 165, 362, note, size = 11.5, fill = GREY)
  }
  big_table(120, "990 efile tables — P00 · P01 · P08", NAVY,
            "~500K filings / year", "#9AA3B2",
            "every organization that filed, every year", c(5, 6, 19, 20))
  big_table(710, "BMF — organization master", TEAL,
            "millions of rows", RED,
            "one row per org ever registered — most are not in your study",
            c(9, 10, 23))

  fy <- 392; fh <- 118
  el_rect(s, 90, fy, 980, fh, "#EAF6EC", stroke = DGREEN, sw = 2, rx = 12)
  el_text(s, 120, fy + 28, "PREFILTER — cheap", size = 15, fill = DGREEN,
          weight = "bold", anchor = "start")
  el_text(s, 120, fy + 52,
          'ga_c3 <- bmf$EIN2[bmf$geo_state_abbr == "GA" & bmf$subsection_code == "3"]',
          size = 13, family = MONO, anchor = "start")
  el_text(s, 120, fy + 74,
          'sfw   <- add_rule(sfw, "GA 501c3 cohort", "subset", subset = ga_c3)',
          size = 13, family = MONO, anchor = "start")
  el_text(s, 120, fy + 99,
          "the subset rule is pushed down to read time — only cohort rows are ever read into memory",
          size = 12, fill = GREY, anchor = "start", style = "italic")

  for (cx in c(285, 875)) {
    el_line(s, cx, 372, cx, fy - 6, NAVY, 2.4)
    arrow_head(s, cx, fy - 2, 90)
    el_line(s, cx, fy + fh + 4, cx, fy + fh + 38, DGREEN, 2.4)
    arrow_head(s, cx, fy + fh + 42, 90, col = DGREEN)
  }

  sy <- fy + fh + 50
  slim_table <- function(x, title, note) {
    el_rect(s, x, sy, 330, 22, DGREEN, rx = 6)
    el_text(s, x + 165, sy + 15.5, title, size = 12, fill = "white",
            weight = "bold")
    el_rect(s, x, sy + 22, 330, 54, "white", stroke = DGREEN, sw = 1.4, rx = 4)
    stack_rows(x, sy + 26, 330, 46, 7, seq_len(7))
    el_text(s, x + 165, sy + 94, note, size = 11.5, fill = GREY)
  }
  slim_table(120, "cohort filings", "~8K rows / year")
  slim_table(710, "cohort BMF traits", "one row per cohort org")

  jx <- 580; jy <- sy + 44
  el_polygon(s, c(jx - 26, jx - 2, jx - 26), c(jy - 18, jy, jy + 18), NAVY)
  el_polygon(s, c(jx + 26, jx + 2, jx + 26), c(jy - 18, jy, jy + 18), NAVY)
  el_text(s, jx, jy + 40, "ready to merge", size = 12.5, fill = NAVY,
          weight = "bold")
  el_text(s, jx, jy + 58, "small × small", size = 11.5, fill = GREY)

  wy <- sy + 132
  el_rect(s, 190, wy, 780, 54, "#FDF0EE", stroke = RED, sw = 1.6, rx = 10)
  el_text(s, 580, wy + 22,
          "⚠  without prefiltering: full panel ⋈ full BMF — millions of rows × hundreds of columns",
          size = 13, fill = RED, weight = "bold")
  el_text(s, 580, wy + 42,
          "a merge that size can exhaust RAM on most machines; prefiltering keeps assembly cheap",
          size = 12, fill = RED)
  svg_save(s, file.path(fig_dir, "sfw-prefilter.svg"))
}

fig_panel_types()
fig_panel_filter()
fig_panel_impute()
fig_panel_smooth()
fig_reconcile()
fig_merge_tables()
fig_stack_years()
fig_bmf_merge()
fig_panel_balance()
fig_sfw_rules()
fig_sfw_manifest()
fig_sfw_prefilter()

# Vignettes embed the same figures from vignettes/figures/ (kept in sync here
# so R CMD build ships them with the package).
vfig <- file.path(root, "vignettes", "figures")
dir.create(vfig, showWarnings = FALSE, recursive = TRUE)
invisible(file.copy(list.files(fig_dir, pattern = "[.]svg$", full.names = TRUE),
                    vfig, overwrite = TRUE))
message("synced figures to ", vfig)
