# ════════════════════════════════════════════════════════════════════════════
#  Hamlet Data Visualization 
#  Group 1 | Data Analytics with R
# ════════════════════════════════════════════════════════════════════════════

library(tidyverse)   
library(tidytext)    # tokenization (unnest_tokens), stop words, Bing sentiment lexicon
library(widyr)       # pairwise co-occurrence counts (pairwise_count)
library(patchwork)   # combines multiple ggplot objects into the poster layout
library(grid)        # low-level graphics primitives (unit()) used inside gridExtra layouts
library(gridExtra)   # renders the Lion King table as a tableGrob and stacks panels with arrangeGrob
library(png)         # reads the chord diagram PNG back into R as a raster object
library(cowplot)     # wraps the chord PNG raster into a ggplot-compatible panel (ggdraw + draw_image)
library(showtext)    # loads Google Fonts (EB Garamond, MedievalSharp, UnifrakturMaguntia) for use in ggplot and base graphics
library(SnowballC)   # Porter stemming (wordStem) — collapses word variants to their root form
library(scales)      # percent formatter for the heatmap legend
library(ggrepel)     # non-overlapping annotation labels on the sentiment chart (geom_label_repel)
library(circlize)    # draws the chord diagram — arc proportions, ribbon colours, sector labels

# ── Fonts ─────────────────────────────────────────────────────────────────────
font_add_google("EB Garamond",        "Garamond")
font_add_google("MedievalSharp",      "MedievalSharp")
font_add_google("UnifrakturMaguntia", "UnifrakturMaguntia")
showtext_auto()

# ── Data ──────────────────────────────────────────────────────────────────────
load("01_hamlet.RData")

# ── Color palette ─────────────────────────────────────────────────────────────
character_colors <- c(
  "Hamlet"         = "#7e1215",
  "King Claudius"  = "#1a2b4b",
  "Lord Polonius"  = "#a07a3c",
  "Horatio"        = "#1f5c53",
  "Laertes"        = "#d48b1d",
  "Ophelia"        = "#a8bcc6",
  "Queen Gertrude" = "#5e2129"
)

# ── Top 6 characters by line count ────────────────────────────────────────────
top_characters <- hamlet %>%
  filter(character != "[stage direction]") %>%
  count(character, sort = TRUE) %>%
  slice_max(n, n = 6)

main_characters <- top_characters$character

character_totals <- hamlet %>%
  filter(character %in% main_characters) %>%
  count(character, name = "total_lines") %>%
  arrange(desc(total_lines)) %>%
  mutate(character = factor(character, levels = rev(.$character)))

# ── Act boundaries ────────────────────────────────────────────────────────────
act_boundaries <- hamlet %>%
  group_by(act) %>%
  summarise(start_line = min(line_number, na.rm = TRUE),
            end_line   = max(line_number, na.rm = TRUE), .groups = "drop") %>%
  mutate(mid_line = (start_line + end_line) / 2)

# ── Theme ─────────────────────────────────────────────────────────────────────
hamlet_theme <- function() {
  theme_minimal(base_family = "Garamond", base_size = 16) +
    theme(
      plot.title        = element_text(size = 26, face = "bold",
                                       margin = margin(b = 15), color = "black"),
      plot.subtitle     = element_text(size = 16, hjust = 0.5,
                                       margin = margin(b = 20), color = "black"),
      axis.title        = element_text(size = 22, face = "bold", color = "black"),
      axis.text         = element_text(size = 20, color = "black"),
      panel.grid.major  = element_line(color = "gray90", linewidth = 0.3),
      panel.grid.minor  = element_blank(),
      strip.text        = element_text(size = 16, face = "bold", color = "black"),
      plot.background   = element_rect(fill = "#F5E6C8", color = NA),
      panel.background  = element_rect(fill = "#F5E6C8", color = NA),
      legend.background = element_rect(fill = "#F5E6C8", color = NA),
      legend.position   = "bottom",
      plot.margin       = margin(20, 20, 20, 20)
    )
}

# ── Symmetric chord matrix: lines spoken in shared scenes ─────────────────────
# isSymmetric(chord_matrix_lines) is TRUE by construction → circlize draws
# exactly ONE ribbon per pair → exactly 6 ribbons per character arc.
# Arc length  = total lines spoken (off-diagonal ribbons + diagonal remainder).
# Diagonal    = lines spoken in scenes with no other top-7 character present
#               (arc space is reserved but no ribbon is drawn there).
chord_matrix_lines <- local({
  nm <- main_characters
  n  <- length(nm)

  # Lines spoken per character per (act, scene)
  scene_lines <- hamlet %>%
    filter(character %in% main_characters) %>%
    count(act, scene, character, name = "lines")

  # Number of main characters present per scene
  scene_lines <- scene_lines %>%
    left_join(
      scene_lines %>% count(act, scene, name = "n_top7"),
      by = c("act", "scene")
    )

  shared_scenes <- scene_lines %>% filter(n_top7 >= 2)

  # Step 1 — directed raw matrix
  # raw[i,j] = total lines character i spoke in scenes where character j appears.
  # Multi-counts i's lines when ≥3 main characters share a scene; corrected below.
  pair_raw <- shared_scenes %>%
    inner_join(
      shared_scenes %>% select(act, scene, char_j = character),
      by = c("act", "scene")
    ) %>%
    filter(character != char_j) %>%
    group_by(character, char_j) %>%
    summarise(raw = sum(lines), .groups = "drop")

  raw_mat <- matrix(0.0, n, n, dimnames = list(nm, nm))
  for (k in seq_len(nrow(pair_raw)))
    raw_mat[pair_raw$character[k], pair_raw$char_j[k]] <- pair_raw$raw[k]

  # Step 2 — normalize rows
  # Rescale each row so its off-diagonal sum equals the character's actual
  # shared-scene line count (removes the multi-counting from step 1).
  # Use a named vector lookup to avoid any factor / string-matching pitfalls.
  actual_shared <- shared_scenes %>%
    group_by(character) %>%
    summarise(s = sum(lines), .groups = "drop") %>%
    { setNames(.$s, .$character) }

  norm_mat <- raw_mat
  for (char in nm) {
    row_sum <- sum(raw_mat[char, ])
    s       <- actual_shared[char]          # named-vector lookup; NA if absent
    if (!is.na(s) && row_sum > 0)
      norm_mat[char, ] <- raw_mat[char, ] * s / row_sum
  }

  # Step 3 — symmetrize (use average as shared ribbon base width)
  sym_mat <- norm_mat
  for (i in seq_len(n - 1)) {
    for (j in (i + 1):n) {
      v <- (norm_mat[i, j] + norm_mat[j, i]) / 2
      sym_mat[i, j] <- v
      sym_mat[j, i] <- v
    }
  }

  # Step 4 — diagonal = 0
  # Arc = lines spoken in shared scenes only.  No empty space reserved.
  for (char in nm)
    sym_mat[char, char] <- 0

  sym_mat <- round(sym_mat)

  # Mirror lower triangle from upper so floating-point rounding never introduces
  # asymmetry — chordDiagram() draws ONE ribbon per pair only if isSymmetric = TRUE.
  sym_mat[lower.tri(sym_mat)] <- t(sym_mat)[lower.tri(sym_mat)]

  stopifnot(isSymmetric(sym_mat))
  sym_mat
})

# ── Chord diagram (circlize, static) ──────────────────────────────────────────
draw_chord <- function() {
  op <- par(no.readonly = TRUE)
  on.exit(par(op))

  chars <- rownames(chord_matrix_lines)
  cols  <- character_colors[chars]

  n          <- length(chars)
  arc_sizes  <- rowSums(chord_matrix_lines)   # = shared lines per character

  par(bg = "#F5E6C8", mar = c(3, 3, 5, 3), family = "Garamond")
  circos.clear()
  circos.par(
    start.degree            = 90,
    gap.degree              = 3,
    track.margin            = c(0.005, 0.005),
    cell.padding            = c(0, 0, 0, 0),
    canvas.xlim             = c(-1.25, 1.25),
    canvas.ylim             = c(-1.25, 1.25),
    points.overflow.warning = FALSE
  )

  # Set sector sizes explicitly so arc = shared lines
  circos.initialize(
    factors = factor(chars, levels = chars),
    xlim    = cbind(rep(0, n), arc_sizes[chars])
  )

  # Track 1 (outermost) — character labels, sits outside the colored arc
  circos.track(
    ylim         = c(0, 1),
    bg.border    = NA,
    bg.col       = NA,
    track.height = 0.14,
    panel.fun    = function(x, y) {
      nm   <- get.cell.meta.data("sector.index")
      xlim <- get.cell.meta.data("xlim")
      circos.text(
        mean(xlim), 0.5, nm,
        facing     = "clockwise",
        niceFacing = TRUE,
        adj        = c(0, 0.5),
        col        = cols[nm],
        cex        = 0.95,
        font       = 2
      )
    }
  )

  # Track 2 — colored arc (immediately inside the label ring, right above ribbons)
  circos.track(
    ylim         = c(0, 1),
    bg.col       = cols[chars],
    bg.border    = adjustcolor("#2C1810", alpha.f = 0.30),
    track.height = 0.05
  )

  # Draw ribbons — exactly one circos.link() call per unique pair.
  # With n=6 characters this loop runs exactly 15 times → 5 ribbons per character.
  arc_pos <- setNames(rep(0.0, n), chars)
  for (i in seq_len(n)) {
    for (j in seq_len(i - 1)) {
      fi <- chars[i];  fj <- chars[j]
      w  <- max(chord_matrix_lines[fi, fj], 1)
      x1s <- arc_pos[fi];  x1e <- x1s + w
      x2s <- arc_pos[fj];  x2e <- x2s + w
      circos.link(
        fi, c(x1s, x1e),
        fj, c(x2s, x2e),
        col    = adjustcolor(cols[fi], alpha.f = 0.45),
        border = NA
      )
      arc_pos[fi] <- x1e
      arc_pos[fj] <- x2e
    }
  }

  title(
    main      = "Who Speaks With Whom",
    col.main  = "#2C1810",
    cex.main  = 1.6,
    font.main = 2,
    line      = 2
  )
  mtext(
    "Arc length = lines spoken in scenes with other main characters",
    side = 3, line = 0.5,
    col  = "#3E2723", cex = 0.9, font = 3
  )

  circos.clear()
}



# ── Heatmap data ──────────────────────────────────────────────────────────────
act_labels <- c("Act I" = "I", "Act II" = "II", "Act III" = "III",
                "Act IV" = "IV", "Act V" = "V")

scene_presence <- hamlet %>%
  filter(character != "[stage direction]") %>%
  group_by(act, scene) %>%
  mutate(scene_total_lines = n()) %>%
  ungroup() %>%
  filter(character %in% main_characters) %>%
  group_by(character, act, scene, scene_total_lines) %>%
  summarise(lines = n(), .groups = "drop") %>%
  mutate(line_share = lines / scene_total_lines) %>%
  mutate(
    act_num   = match(act, names(act_labels)),
    scene_num = {
      
      s <- as.character(scene)
      coalesce(
        suppressWarnings(as.integer(s)),
        suppressWarnings(as.integer(as.roman(s))),
        suppressWarnings(as.integer(as.roman(
          gsub("^.*\\s([IVXivx]+)$", "\\1", trimws(s))
        )))
      )
    },
    scene_label = paste0(act_labels[act], ".", scene_num)
  )

scene_order <- scene_presence %>%
  distinct(act_num, scene_num, scene_label) %>%
  arrange(act_num, scene_num) %>%
  pull(scene_label)

act_sep <- scene_presence %>%
  distinct(act_num, scene_label) %>%
  group_by(act_num) %>%
  summarise(n_scenes = n(), .groups = "drop") %>%
  arrange(act_num) %>%
  mutate(xpos = cumsum(n_scenes) + 0.5) %>%
  filter(act_num < 5)

scene_heatmap_data <- scene_presence %>%
  complete(character, scene_label = scene_order, fill = list(lines = 0, line_share = 0)) %>%
  mutate(
    scene_label = factor(scene_label, levels = scene_order),
    character   = factor(character, levels = levels(character_totals$character))
  )

# ── Sentiment data ─────────────────────────────────────────────────────────────
cumulative_hamlet <- hamlet %>%
  filter(character == "Hamlet") %>%
  unnest_tokens(word, dialogue) %>%
  mutate(word = tolower(word)) %>%
  anti_join(stop_words, by = "word") %>%
  inner_join(get_sentiments("bing"), by = "word") %>%
  mutate(sentiment_value = ifelse(sentiment == "positive", 1, -1)) %>%
  group_by(line_number, act, scene) %>%
  summarize(line_sentiment = sum(sentiment_value), .groups = "drop") %>%
  arrange(line_number) %>%
  mutate(cumulative_sentiment = cumsum(line_sentiment), character = "Hamlet")

cumulative_claudius <- hamlet %>%
  filter(character == "King Claudius") %>%
  unnest_tokens(word, dialogue) %>%
  mutate(word = tolower(word)) %>%
  anti_join(stop_words, by = "word") %>%
  inner_join(get_sentiments("bing"), by = "word") %>%
  mutate(sentiment_value = ifelse(sentiment == "positive", 1, -1)) %>%
  group_by(line_number, act, scene) %>%
  summarize(line_sentiment = sum(sentiment_value), .groups = "drop") %>%
  arrange(line_number) %>%
  mutate(cumulative_sentiment = cumsum(line_sentiment), character = "King Claudius")

cumulative_sentiment_all <- bind_rows(cumulative_hamlet, cumulative_claudius)

# ── Sentiment annotations at actual peaks / troughs ───────────────────────────
# Each row defines a character + line window; the code finds the real extremum
# within that window so the annotation lands on the actual turning point.
event_windows <- tibble(
  event_label     = c("Ghost reveals\nthe murder",
                      "Play-within-\na-play",
                      "Hamlet kills\nPolonius",
                      "Claudius prays\nfor forgiveness",
                      "Ophelia drowns",
                      "Final duel"),
  character_focus = c("Hamlet",        "King Claudius",  "Hamlet",
                      "King Claudius",  "Hamlet",         "Hamlet"),
  line_min        = c(200,  1300, 1750, 1900, 2700, 3600),
  line_max        = c(500,  1700, 2100, 2400, 3100, 4000)
)

sentiment_annotations <- pmap_dfr(event_windows,
                                  function(event_label, character_focus, line_min, line_max) {
                                    sub <- cumulative_sentiment_all %>%
                                      filter(character == character_focus,
                                             line_number >= line_min, line_number <= line_max)
                                    if (nrow(sub) == 0) return(tibble())
                                    lo <- sub %>% slice_min(cumulative_sentiment, n = 1, with_ties = FALSE)
                                    hi <- sub %>% slice_max(cumulative_sentiment, n = 1, with_ties = FALSE)
                                    pt <- if (abs(lo$cumulative_sentiment) >= abs(hi$cumulative_sentiment)) lo else hi
                                    pt %>% mutate(event_label = event_label)
                                  }
)

# ── Distinctive words data ────────────────────────────────────────────────────
distinctive_words_base <- hamlet %>%
  filter(character != "[stage direction]", character %in% main_characters) %>%
  unnest_tokens(word, dialogue) %>%
  anti_join(stop_words, by = "word") %>%
  mutate(word_stem = wordStem(word, language = "english")) %>%
  count(word_stem, character) %>%
  group_by(character) %>%
  mutate(prop_this_character = n / sum(n)) %>%
  ungroup() %>%
  mutate(prop_overall = n / sum(n),
         relative     = prop_this_character / prop_overall) %>%
  filter(n > 2)

# ── Poster header helper ───────────────────────────────────────────────────────
make_header <- function(number, question) {
  ggplot() +
    annotate("text", x = 0.03, y = 0.72,
             label = paste0(number, "  \u00b7  ", question),
             hjust = 0, vjust = 0.5, size = 11,
             family = "MedievalSharp", color = "#2C1810", fontface = "bold") +
    annotate("segment", x = 0.02, xend = 0.98, y = 0.15, yend = 0.15,
             color = "#a07a3c", linewidth = 1.0) +
    xlim(0, 1) + ylim(0, 1) +
    theme_void() +
    theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
          plot.margin     = margin(20, 30, 5, 30))
}

# ── Generate poster directly ──────────────────────────────────────────────────
{
  out_file <- "hamlet_analysis_visualization.png"
  
  sentiment_char_colors <- c("Hamlet" = "#7e1215", "King Claudius" = "#1a2b4b")
  
  title_panel <- ggplot() +
    annotate("text", x = 0.5, y = 0.5,
             label = "A Visual Analysis of Hamlet by Shakespeare",
             hjust = 0.5, vjust = 0.5, size = 20,
             family = "UnifrakturMaguntia", color = "#2C1810") +
    xlim(0, 1) + ylim(0, 1) + theme_void() +
    theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
          plot.margin     = margin(30, 30, 10, 30))
  
  lk_data <- data.frame(
    `Hamlet`    = c("Hamlet", "King Claudius", "Ghost (King Hamlet)",
                    "Queen Gertrude", "Ophelia", "Horatio",
                    "Lord Polonius", "Laertes"),
    `Lion King` = c("Simba", "Scar", "Mufasa", "Sarabi",
                    "Nala", "Timon & Pumbaa", "Zazu", "Rafiki"),
    `Role`      = c("The prince haunted by his father\u2019s murder",
                    "The villainous uncle who seized the throne",
                    "The murdered king who returns as a ghost",
                    "The queen caught between past and present",
                    "The love interest undone by grief",
                    "The loyal friend who keeps the hero grounded",
                    "The meddling adviser obsessed with control",
                    "Confronts the protagonist and pushes him toward action"),
    check.names = FALSE
  )
  
  lk_ttheme <- ttheme_minimal(
    base_family = "Garamond", base_size = 13,
    core    = list(
      fg_params = list(col = "#2C1810", fontfamily = "Garamond",
                       fontsize = 13, x = 0.06, hjust = 0),
      bg_params = list(fill = c("#F5E6C8", "#ede0c4"),
                       col = "#a07a3c", lwd = 0.6)
    ),
    colhead = list(
      fg_params = list(col = "#2C1810", fontfamily = "Garamond",
                       fontsize = 14, fontface = "bold",
                       x = 0.06, hjust = 0),
      bg_params = list(fill = "#d4b896", col = "#a07a3c", lwd = 0.8)
    )
  )
  
  intro_plot <- ggplot() +
    annotate("text",
             x = 0.5, y = 0.03,
             label = paste0(
               "Shakespeare\u2019s longest play, Hamlet is a revenge tragedy\n",
               "following a Danish prince who discovers his father was\n",
               "murdered by his uncle \u2014 now king and husband to his mother.\n",
               "\n",
               "To tell this story through data, we explore four questions:\n",
               "who dominates the stage, when each character appears, how\n",
               "the mood shifts across the play, and what words define\n",
               "each character\u2019s voice.\n",
               "\n",
               "Never read Hamlet? Think of it as The Lion King \u2014 but darker.\n",
               "The table below maps each character to their Disney counterpart."
             ),
             hjust = 0.5, vjust = 0,
             size = 6.5, family = "Garamond",
             color = "#3E2723", lineheight = 1.6
    ) +
    xlim(0, 1) + ylim(0, 1) + theme_void() +
    theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
          plot.margin     = margin(5, 5, 2, 5))
  
  lk_table_grob <- tableGrob(lk_data, rows = NULL, theme = lk_ttheme)
  
  left_col <- wrap_elements(
    full = gridExtra::arrangeGrob(
      intro_plot,
      lk_table_grob,
      ncol    = 1,
      heights = grid::unit(c(2.50, 1.45), "null")
    )
  ) +
    theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
          plot.margin     = margin(15, 10, 15, 15))
  
  caption_panel <- ggplot() +
    annotate("text", x = 0.5, y = 0.5,
             label = paste0("Andr\u00e9s Ram\u00edrez Arroyo  \u2022  Ferdinand Rasmussen",
                            "  \u2022  Federica Selvini  \u2022  Max Voss  \u2022  Jad Zoghaib"),
             hjust = 0.5, size = 5.5, family = "Garamond", color = "#3E2723") +
    xlim(0, 1) + ylim(0, 1) + theme_void() +
    theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
          plot.margin     = margin(10, 30, 20, 30))
  
  message("Rendering chord diagram...")
  tmp_chord <- tempfile(fileext = ".png")
  showtext_opts(dpi = 150)
  png(tmp_chord, width = 1200, height = 1200, res = 150, bg = "#F5E6C8")
  draw_chord()
  dev.off()
  chord_img      <- png::readPNG(tmp_chord)
  network_plot_p <- cowplot::ggdraw() +
    cowplot::draw_image(chord_img) +
    theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
          plot.margin     = margin(20, 20, 20, 20))
  
  message("Rendering heatmap...")
  heatmap_plot_p <- ggplot(scene_heatmap_data,
                           aes(x = scene_label, y = character, fill = line_share)) +
    geom_tile(color = "#F5E6C8", linewidth = 0.4) +
    geom_vline(data = act_sep, aes(xintercept = xpos),
               color = "#9c8e7a", linewidth = 1.0, inherit.aes = FALSE) +
    scale_fill_gradient(low = "#e6dec9", high = "#7e1215",
                        name = "Share of scene\nlines spoken",
                        limits = c(0, 1), labels = percent,
                        na.value = "#e6dec9") +
    scale_x_discrete(expand = c(0, 0)) +
    scale_y_discrete(expand = c(0, 0)) +
    labs(title    = "Scene Presence of Primary Characters",
         subtitle = "Colour intensity = share of scene lines spoken  |  Pale = absent  |  Vertical lines = act boundaries",
         x = "Act . Scene", y = "Character") +
    hamlet_theme() +
    theme(
      axis.text.x     = element_text(angle = 45, hjust = 1, size = 11, family = "Garamond"),
      axis.text.y     = element_text(size = 13, family = "Garamond"),
      axis.title      = element_text(size = 16, face = "bold", family = "Garamond"),
      panel.grid      = element_blank(),
      legend.position = "right",
      plot.title      = element_text(hjust = 0.5, family = "Garamond", size = 22)
    )
  
  message("Rendering sentiment plot...")
  char_labels_p <- cumulative_sentiment_all %>%
    group_by(character) %>% slice_max(line_number, n = 1) %>% ungroup()
  
  sentiment_plot_p <- cumulative_sentiment_all %>%
    ggplot(aes(x = line_number, y = cumulative_sentiment, color = character)) +
    geom_line(linewidth = 1.3) +
    geom_point(data = sentiment_annotations,
               aes(x = line_number, y = cumulative_sentiment),
               color = "#5a110a", fill = "#F5E6C8",
               shape = 21, size = 3, stroke = 1.2, inherit.aes = FALSE) +
    ggrepel::geom_label_repel(
      data          = sentiment_annotations,
      aes(x = line_number, y = cumulative_sentiment, label = event_label),
      nudge_y       = 22, direction = "x",
      segment.color = "#5a110a", segment.size = 0.45,
      arrow         = arrow(length = unit(0.008, "npc"), type = "closed"),
      label.r       = unit(0.45, "lines"), label.size = 0.35,
      fill          = "#F5E6C8", color = "#5a110a",
      family        = "Garamond", fontface = "italic", size = 3.2,
      max.overlaps  = Inf, inherit.aes = FALSE) +
    geom_label(data = char_labels_p, aes(label = character, fill = character),
               color = "#e6dec9", fontface = "bold", family = "Garamond",
               size = 4.5, hjust = 1, nudge_y = 6, show.legend = FALSE) +
    geom_vline(data = act_boundaries, aes(xintercept = start_line),
               color = "#9c8e7a", linetype = "dashed", linewidth = 0.8,
               inherit.aes = FALSE) +
    geom_text(data = act_boundaries, aes(x = mid_line, label = act),
              y = Inf, vjust = 1, family = "Garamond", size = 5,
              fontface = "bold", color = "black", inherit.aes = FALSE) +
    scale_color_manual(values = sentiment_char_colors, guide = "none") +
    scale_fill_manual(values  = sentiment_char_colors, guide = "none") +
    scale_x_continuous(breaks = seq(0, 4000, 500), limits = c(0, 4000),
                       expand = c(0.01, 0.01)) +
    labs(title = "Hamlet versus King Claudius Sentiment Progression",
         x = "Line Number", y = "Cumulative Sentiment") +
    hamlet_theme() +
    theme(
      legend.position = "none",
      axis.text       = element_text(family = "Garamond"),
      axis.title.x    = element_text(margin = margin(t = 10), size = 22,
                                     face = "bold", family = "Garamond"),
      plot.title      = element_text(hjust = 0.5, family = "Garamond")
    )
  
  message("Rendering distinctive words...")
  dw_p <- distinctive_words_base %>%
    group_by(character) %>%
    arrange(desc(relative), desc(n)) %>%
    slice(1:5) %>%
    ungroup() %>%
    mutate(character = factor(character, levels = rev(main_characters))) %>%
    group_by(character) %>%
    mutate(rank = row_number()) %>%
    ungroup()
  
  distinctive_plot_p <- ggplot(
    dw_p,
    aes(x = rank, y = character, label = word_stem, colour = log(relative))
  ) +
    geom_text(size = 6.5, family = "Garamond", fontface = "bold") +
    geom_vline(xintercept = 0.5, colour = "#9c8e7a", linewidth = 0.4) +
    scale_colour_gradient(low = "#1a2b4b", high = "#7e1215",
                          name = "Distinctiveness\n(log scale)") +
    scale_x_continuous(limits = c(0.5, 5.5), breaks = 1:5) +
    labs(
      title    = "Most Distinctive Word Stems for the Top 7 Characters in Hamlet",
      subtitle = "Colour intensity = how much more the character uses this word than the play average",
      x = "", y = ""
    ) +
    theme_minimal(base_family = "Garamond") +
    theme(
      axis.text.x        = element_blank(),
      axis.ticks.x       = element_blank(),
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      panel.grid.major.y = element_line(colour = "grey88", linewidth = 0.3),
      plot.background    = element_rect(fill = "#F5E6C8", color = NA),
      panel.background   = element_rect(fill = "#F5E6C8", color = NA),
      legend.background  = element_rect(fill = "#F5E6C8", color = NA),
      legend.key         = element_rect(fill = "#F5E6C8", color = NA),
      plot.title    = element_text(size = 18, face = "bold",
                                   family = "MedievalSharp", hjust = 0.5),
      plot.subtitle = element_text(size = 11, family = "Garamond",
                                   hjust = 0.5, colour = "grey30"),
      axis.text.y   = element_text(size = 15, family = "Garamond",
                                   hjust = 1, colour = "black"),
      legend.title  = element_text(size = 10, family = "Garamond", face = "bold"),
      legend.text   = element_text(size = 9,  family = "Garamond"),
      legend.position = "right",
      plot.margin   = margin(15, 15, 15, 15)
    )
  
  message("Assembling poster...")
  sec1 <- make_header("01", "Who is in this play \u2014 and who dominates the stage?")
  sec2 <- make_header("02", "When do the characters appear?")
  sec3 <- make_header("03", "How does the mood evolve?")
  sec4 <- make_header("04", "What defines each character\u2019s voice?")
  
  viz1 <- (sec1 / network_plot_p)     + plot_layout(heights = c(0.07, 0.93))
  viz2 <- (sec2 / heatmap_plot_p)     + plot_layout(heights = c(0.07, 0.93))
  viz3 <- (sec3 / sentiment_plot_p)   + plot_layout(heights = c(0.07, 0.93))
  viz4 <- (sec4 / distinctive_plot_p) + plot_layout(heights = c(0.07, 0.93))
  
  top_right    <- title_panel / (viz1 | viz2) + plot_layout(heights = c(0.08, 0.92))
  top_section  <- (left_col | top_right)      + plot_layout(widths  = c(1, 3.5))
  bottom_section <- viz3 | viz4
  
  poster <- (top_section / bottom_section / caption_panel) +
    plot_layout(heights = c(2.3, 1.7, 0.1)) &
    theme(plot.background = element_rect(fill = "#F5E6C8", color = NA))
  
  message("Saving ", out_file, " ...")
  showtext_opts(dpi = 150)
  ggsave(out_file, poster, device = "png", dpi = 150, width = 40, height = 26,
         limitsize = FALSE, bg = "#F5E6C8")
  message("Done!")
}
