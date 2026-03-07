# ════════════════════════════════════════════════════════════════════════════
#  Hamlet Data Visualization — Shiny App
#  Group 1 | Data Analytics with R
# ════════════════════════════════════════════════════════════════════════════

library(shiny)
library(tidyverse)
library(tidytext)
library(widyr)
library(patchwork)
library(grid)
library(gridExtra)
library(png)
library(cowplot)
library(showtext)
library(tidygraph)
library(ggraph)
library(igraph)
library(SnowballC)

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
  "Queen Gertrude" = "#5e2129",
  "Rosencrantz"    = "#7a7065",
  "Ghost"          = "#10302b"
)

# ── Top 8 characters by line count ────────────────────────────────────────────
top_characters <- hamlet %>%
  filter(character != "[stage direction]") %>%
  count(character, sort = TRUE) %>%
  slice_max(n, n = 8)

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
      plot.title    = element_text(size = 26, face = "bold", margin = margin(b = 15), color = "black"),
      plot.subtitle = element_text(size = 16, hjust = 0.5, margin = margin(b = 20), color = "black"),
      axis.title    = element_text(size = 22, face = "bold", color = "black"),
      axis.text     = element_text(size = 20, color = "black"),
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

# ── Network data ──────────────────────────────────────────────────────────────
character_scenes <- hamlet %>%
  filter(character != "[stage direction]") %>%
  distinct(character, act, scene) %>%
  unite(scene_id, act, scene, remove = FALSE)

transitions_sym <- character_scenes %>%
  pairwise_count(character, scene_id, sort = TRUE, upper = FALSE) %>%
  rename(from = item1, to = item2)

char_word_totals <- hamlet %>%
  filter(character != "[stage direction]") %>%
  mutate(words = str_count(dialogue, "\\S+")) %>%
  group_by(character) %>%
  summarise(words = sum(words, na.rm = TRUE), .groups = "drop")

# ── Sentiment data ────────────────────────────────────────────────────────────
hamlet_sentiment_by_line <- hamlet %>%
  filter(character == "Hamlet") %>%
  unnest_tokens(word, dialogue) %>%
  mutate(word = tolower(word)) %>%
  anti_join(stop_words, by = "word") %>%
  inner_join(get_sentiments("bing"), by = "word") %>%
  mutate(sentiment_value = ifelse(sentiment == "positive", 1, -1)) %>%
  group_by(line_number, act, scene) %>%
  summarize(line_sentiment = sum(sentiment_value),
            positive_words = sum(sentiment == "positive"),
            negative_words = sum(sentiment == "negative"),
            .groups = "drop")

cumulative_hamlet <- hamlet_sentiment_by_line %>%
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

key_events <- hamlet %>%
  mutate(scene_int = suppressWarnings(as.integer(as.character(scene)))) %>%
  group_by(act, scene_int) %>%
  summarise(mid_line = mean(line_number, na.rm = TRUE), .groups = "drop") %>%
  filter((act == "Act III" & scene_int == 4) |
         (act == "Act IV"  & scene_int == 7) |
         (act == "Act V"   & scene_int == 2)) %>%
  mutate(event_label = case_when(
    act == "Act III" ~ "Polonius killed",
    act == "Act IV"  ~ "Ophelia drowns",
    TRUE             ~ "Final bloodbath"
  ))

# ── Heatmap data ──────────────────────────────────────────────────────────────
act_labels <- c("Act I" = "I", "Act II" = "II", "Act III" = "III",
                "Act IV" = "IV", "Act V" = "V")

scene_presence <- hamlet %>%
  filter(character %in% main_characters) %>%
  group_by(character, act, scene) %>%
  summarise(lines = n(), .groups = "drop") %>%
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
  complete(character, scene_label = scene_order, fill = list(lines = 0)) %>%
  mutate(
    scene_label = factor(scene_label, levels = scene_order),
    character   = factor(character, levels = levels(character_totals$character))
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

# ── Poster helper ─────────────────────────────────────────────────────────────
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

# ════════════════════════════════════════════════════════════════════════════
#  UI
# ════════════════════════════════════════════════════════════════════════════

ui <- navbarPage(
  title = "Hamlet \u2014 Data Analysis",

  header = tags$head(tags$style(HTML("
    body        { background-color: #F5E6C8; font-family: serif; }
    .navbar     { background-color: #2C1810 !important; border-color: #a07a3c; }
    .navbar-brand, .navbar-nav > li > a { color: #F5E6C8 !important; font-size: 15px; }
    .navbar-nav > li > a:hover          { background-color: #a07a3c !important; }
    .navbar-nav > .active > a           { background-color: #7e1215 !important; color: #F5E6C8 !important; }
    .well        { background-color: #ede0c4; border-color: #a07a3c; }
    h4           { color: #2C1810; font-family: serif; }
    p            { color: #3E2723; }
    hr           { border-color: #a07a3c; }
    .btn-dl      { background-color: #7e1215; border-color: #5a110a; color: #F5E6C8;
                   font-size: 16px; padding: 12px 30px; border-radius: 4px; }
    .btn-dl:hover { background-color: #5a110a; color: #F5E6C8; }
  "))),

  # ── Tab 1: Network ──────────────────────────────────────────────────────────
  tabPanel("Network",
    sidebarLayout(
      sidebarPanel(width = 3,
        h4("Controls"),
        sliderInput("min_scenes",
                    "Minimum shared scenes (edge filter):",
                    min = 1, max = 15, value = 1, step = 1),
        hr(),
        p("Nodes are sized by total words spoken."),
        p("Edge thickness = number of scenes two characters share."),
        p("Drag the slider to remove weak connections and reveal the core network.")
      ),
      mainPanel(width = 9,
        plotOutput("network_plot", height = "680px")
      )
    )
  ),

  # ── Tab 2: Scene Heatmap ────────────────────────────────────────────────────
  tabPanel("Scene Heatmap",
    sidebarLayout(
      sidebarPanel(width = 3,
        h4("Controls"),
        checkboxGroupInput("heatmap_chars", "Show characters:",
                           choices  = NULL,
                           selected = NULL),
        hr(),
        p("Colour intensity = lines spoken in that scene."),
        p("Pale = character is absent. Vertical lines = act boundaries.")
      ),
      mainPanel(width = 9,
        plotOutput("heatmap_plot", height = "520px")
      )
    )
  ),

  # ── Tab 3: Sentiment ────────────────────────────────────────────────────────
  tabPanel("Sentiment",
    sidebarLayout(
      sidebarPanel(width = 3,
        h4("Controls"),
        checkboxGroupInput("sent_chars", "Show characters:",
                           choices  = c("Hamlet", "King Claudius"),
                           selected = c("Hamlet", "King Claudius")),
        hr(),
        p("Cumulative sentiment scored via the Bing lexicon."),
        p("+1 per positive word, -1 per negative word, summed over the play.")
      ),
      mainPanel(width = 9,
        plotOutput("sentiment_plot", height = "520px")
      )
    )
  ),

  # ── Tab 4: Distinctive Words ────────────────────────────────────────────────
  tabPanel("Distinctive Words",
    sidebarLayout(
      sidebarPanel(width = 3,
        h4("Controls"),
        sliderInput("n_words", "Words shown per character:",
                    min = 3, max = 7, value = 5, step = 1),
        hr(),
        p("Distinctiveness = how much more a character uses a word vs. the play average."),
        p("Crimson = highly distinctive. Navy = moderately distinctive.")
      ),
      mainPanel(width = 9,
        plotOutput("distinctive_plot", height = "560px")
      )
    )
  ),

  # ── Tab 5: Export PDF ───────────────────────────────────────────────────────
  tabPanel("Export PDF",
    fluidRow(
      column(12, align = "center",
        br(), br(),
        tags$h3("Download the Full Poster",
                style = "font-family: serif; color: #2C1810; font-size: 28px;"),
        br(),
        p("Generates the complete vertical narrative poster (22 \u00d7 67 inches) as a PDF.",
          style = "font-size: 15px;"),
        p("Includes all four visualizations with section headers and the Lion King reference table.",
          style = "font-size: 15px;"),
        br(),
        downloadButton("download_pdf", "Download PDF Poster", class = "btn-dl")
      )
    )
  )
)

# ════════════════════════════════════════════════════════════════════════════
#  Server
# ════════════════════════════════════════════════════════════════════════════

server <- function(input, output, session) {

  updateCheckboxGroupInput(session, "heatmap_chars",
                           choices  = as.character(levels(character_totals$character)),
                           selected = as.character(levels(character_totals$character)))

  # ── Network ──────────────────────────────────────────────────────────────────
  output$network_plot <- renderPlot({
    edges <- transitions_sym %>% filter(n >= input$min_scenes)
    req(nrow(edges) > 0)

    net <- as_tbl_graph(edges) %>%
      activate(nodes) %>%
      left_join(char_word_totals, by = c("name" = "character")) %>%
      mutate(node_color = ifelse(name %in% names(character_colors),
                                 character_colors[name], "#9c8e7a"))

    ig2          <- igraph::as.igraph(net)
    n_chars2     <- igraph::vcount(ig2)
    net_density2 <- round(igraph::edge_density(ig2) * 100, 1)

    set.seed(42)
    lay <- create_layout(net, layout = "igraph", algorithm = "fr")

    ggraph(lay) +
      geom_edge_arc(aes(edge_width = n), edge_colour = "#7a7065",
                    alpha = 0.5, strength = 0.1, show.legend = FALSE) +
      geom_node_point(aes(size = words, fill = node_color),
                      shape = 21, colour = "#e6dec9", stroke = 1.2, alpha = 0.95) +
      scale_fill_identity() +
      geom_node_label(aes(label = name), colour = "#2C1810",
                      fill = alpha("grey92", 0.5), label.size = 0.15,
                      family = "Garamond", fontface = "bold", size = 5.0,
                      label.padding = unit(0.20, "lines")) +
      scale_edge_width(range = c(0.4, 8), guide = "none") +
      scale_size_area(max_size = 45, labels = scales::comma,
                      name = "Total words spoken:") +
      guides(size = guide_legend(
        override.aes = list(fill = "#c8c8c8", colour = "#9c8e7a"))) +
      labs(
        title    = "Who Interacts With Whom?",
        subtitle = paste0("Node size = total words spoken  |  Line thickness = scenes shared",
                          "  |  Min scenes filter: ", input$min_scenes),
        caption  = paste0("Characters: ", n_chars2,
                          "     Network density: ", net_density2, "%")
      ) +
      theme(
        panel.background  = element_rect(fill = "#F5E6C8", color = NA),
        plot.background   = element_rect(fill = "#F5E6C8", color = NA),
        legend.background = element_rect(fill = "#F5E6C8", color = NA),
        legend.key        = element_rect(fill = "#F5E6C8", color = NA),
        plot.title    = element_text(size = 24, face = "bold",
                                     family = "MedievalSharp", color = "#2C1810"),
        plot.subtitle = element_text(size = 12, family = "Garamond", color = "#5D3A1A"),
        plot.caption  = element_text(family = "Garamond", size = 11,
                                     color = "#2C1810", hjust = 0.5),
        legend.text   = element_text(family = "Garamond", size = 12),
        legend.title  = element_text(family = "Garamond", size = 12, face = "bold"),
        legend.position = "bottom",
        plot.margin   = margin(20, 20, 20, 20)
      )
  })

  # ── Heatmap ───────────────────────────────────────────────────────────────────
  output$heatmap_plot <- renderPlot({
    req(input$heatmap_chars)

    char_levels <- levels(character_totals$character)
    selected    <- char_levels[char_levels %in% input$heatmap_chars]

    data <- scene_heatmap_data %>%
      filter(character %in% selected) %>%
      mutate(character = factor(character, levels = selected))

    ggplot(data, aes(x = scene_label, y = character, fill = lines)) +
      geom_tile(color = "#F5E6C8", linewidth = 0.4) +
      geom_vline(data = act_sep, aes(xintercept = xpos),
                 color = "#9c8e7a", linewidth = 1.0, inherit.aes = FALSE) +
      scale_fill_gradient(low = "#e6dec9", high = "#7e1215",
                          name = "Lines spoken", na.value = "#e6dec9") +
      scale_x_discrete(expand = c(0, 0)) +
      scale_y_discrete(expand = c(0, 0)) +
      labs(title    = "Scene Presence of Primary Characters",
           subtitle = "Colour intensity = lines spoken  |  Pale = absent  |  Vertical lines = act boundaries",
           x = "Scene (Act.Number)", y = "Character") +
      hamlet_theme() +
      theme(
        axis.text.x     = element_text(angle = 45, hjust = 1, size = 11, family = "Garamond"),
        axis.text.y     = element_text(size = 13, family = "Garamond"),
        axis.title      = element_text(size = 16, face = "bold", family = "Garamond"),
        panel.grid      = element_blank(),
        legend.position = "right",
        plot.title      = element_text(hjust = 0.5, family = "Garamond", size = 22)
      )
  })

  # ── Sentiment ─────────────────────────────────────────────────────────────────
  output$sentiment_plot <- renderPlot({
    req(input$sent_chars)

    sentiment_char_colors <- c("Hamlet" = "#7e1215", "King Claudius" = "#1a2b4b")
    data   <- cumulative_sentiment_all %>% filter(character %in% input$sent_chars)
    labels <- data %>% group_by(character) %>% slice_max(line_number, n = 1) %>% ungroup()

    ggplot(data, aes(x = line_number, y = cumulative_sentiment, color = character)) +
      geom_line(linewidth = 1.3) +
      geom_vline(data = key_events, aes(xintercept = mid_line),
                 color = "#5a110a", linetype = "dotted", linewidth = 0.9,
                 inherit.aes = FALSE) +
      geom_text(data = key_events, aes(x = mid_line, label = event_label),
                y = -5, angle = 90, hjust = 1, vjust = -0.4, size = 3.5,
                family = "Garamond", fontface = "italic", color = "#5a110a",
                inherit.aes = FALSE) +
      geom_label(data = labels, aes(label = character, fill = character),
                 color = "#e6dec9", fontface = "bold", family = "Garamond",
                 size = 4.5, hjust = 1, show.legend = FALSE) +
      geom_vline(data = act_boundaries, aes(xintercept = start_line),
                 color = "#9c8e7a", linetype = "dashed", linewidth = 0.8) +
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
  })

  # ── Distinctive words ─────────────────────────────────────────────────────────
  output$distinctive_plot <- renderPlot({
    n  <- input$n_words
    dw <- distinctive_words_base %>%
      group_by(character) %>%
      arrange(desc(relative), desc(n)) %>%
      slice(1:n) %>%
      ungroup() %>%
      mutate(character = factor(character, levels = rev(main_characters))) %>%
      group_by(character) %>%
      mutate(rank = row_number()) %>%
      ungroup()

    ggplot(dw, aes(x = rank, y = character, label = word_stem,
                   colour = log(relative))) +
      geom_text(size = 6.5, family = "Garamond", fontface = "bold") +
      geom_vline(xintercept = 0.5, colour = "#9c8e7a", linewidth = 0.4) +
      scale_colour_gradient(low = "#1a2b4b", high = "#7e1215",
                            name = "Distinctiveness\n(log scale)") +
      scale_x_continuous(limits = c(0.5, n + 0.5), breaks = 1:n) +
      labs(title    = "Most Distinctive Word Stems per Character",
           subtitle = "Colour intensity = how much more the character uses this word than the play average",
           x = "", y = "") +
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
  })

  # ── PDF download ──────────────────────────────────────────────────────────────
  output$download_pdf <- downloadHandler(
    filename = "hamlet_analysis_visualization.pdf",
    content  = function(file) {
      withProgress(message = "Building poster...", value = 0, {

        incProgress(0.05, detail = "Title & intro panels...")

        title_panel <- ggplot() +
          annotate("text", x = 0.5, y = 0.5,
                   label = "A Visual Analysis of Hamlet by Shakespeare",
                   hjust = 0.5, vjust = 0.5, size = 20,
                   family = "UnifrakturMaguntia", color = "#2C1810") +
          xlim(0, 1) + ylim(0, 1) + theme_void() +
          theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
                plot.margin     = margin(30, 30, 10, 30))

        intro_panel <- ggplot() +
          annotate("text", x = 0.5, y = 0.5,
                   label = paste0(
                     "Shakespeare's longest play, Hamlet is a revenge tragedy following a Danish prince who\n",
                     "discovers his father was murdered by his uncle \u2014 now king and husband to his mother.\n\n",
                     "To tell this story through data, we explore four questions: who dominates the stage,\n",
                     "when each character appears, how the mood shifts across the play, and what words\n",
                     "define each character\u2019s voice.\n\n",
                     "Never read Hamlet? Think of it as The Lion King \u2014 but darker.\n",
                     "The table below maps each character to their Disney counterpart."
                   ),
                   hjust = 0.5, vjust = 0.5, size = 7, family = "Garamond",
                   color = "#3E2723", lineheight = 1.8) +
          xlim(0, 1) + ylim(0, 1) + theme_void() +
          theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
                plot.margin     = margin(5, 30, 5, 30))

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

        lk_panel <- wrap_elements(
          full = tableGrob(lk_data, rows = NULL, theme = lk_ttheme)
        ) +
          theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
                plot.margin     = margin(5, 20, 20, 20))

        caption_panel <- ggplot() +
          annotate("text", x = 0.5, y = 0.5,
                   label = paste0("Andr\u00e9s Ram\u00edrez Arroyo  \u2022  Ferdinand Rasmussen",
                                  "  \u2022  Federica Selvini  \u2022  Max Voss  \u2022  Jad Zoghaib"),
                   hjust = 0.5, size = 5.5, family = "Garamond", color = "#3E2723") +
          xlim(0, 1) + ylim(0, 1) + theme_void() +
          theme(plot.background = element_rect(fill = "#F5E6C8", color = NA),
                plot.margin     = margin(10, 30, 20, 30))

        incProgress(0.15, detail = "Network graph...")

        net_graph <- as_tbl_graph(transitions_sym) %>%
          activate(nodes) %>%
          left_join(char_word_totals, by = c("name" = "character")) %>%
          mutate(node_color = ifelse(name %in% names(character_colors),
                                     character_colors[name], "#9c8e7a"))
        ig_p      <- igraph::as.igraph(net_graph)
        n_chars_p <- igraph::vcount(ig_p)
        density_p <- round(igraph::edge_density(ig_p) * 100, 1)

        set.seed(42)
        net_layout <- create_layout(net_graph, layout = "igraph", algorithm = "fr")

        network_plot_p <- ggraph(net_layout) +
          geom_edge_arc(aes(edge_width = n), edge_colour = "#7a7065",
                        alpha = 0.5, strength = 0.1, show.legend = FALSE) +
          geom_node_point(aes(size = words, fill = node_color),
                          shape = 21, colour = "#e6dec9", stroke = 1.2, alpha = 0.95) +
          scale_fill_identity() +
          geom_node_label(aes(label = name), colour = "#2C1810",
                          fill = alpha("grey92", 0.5), label.size = 0.15,
                          family = "Garamond", fontface = "bold", size = 5.0,
                          label.padding = unit(0.20, "lines")) +
          scale_edge_width(range = c(0.4, 8), guide = "none") +
          scale_size_area(max_size = 45, labels = scales::comma,
                          name = "Total words spoken:") +
          guides(size = guide_legend(
            override.aes = list(fill = "#c8c8c8", colour = "#9c8e7a"))) +
          labs(
            title    = "Who Interacts With Whom?",
            subtitle = "Node size = total words spoken  |  Line thickness = number of shared scenes",
            caption  = paste0("Number of characters: ", n_chars_p,
                              "          Network density: ", density_p, "%\n",
                              "Two characters are connected if they appear in the same scene.")
          ) +
          theme(
            panel.background  = element_rect(fill = "#F5E6C8", color = NA),
            plot.background   = element_rect(fill = "#F5E6C8", color = NA),
            legend.background = element_rect(fill = "#F5E6C8", color = NA),
            legend.key        = element_rect(fill = "#F5E6C8", color = NA),
            plot.title    = element_text(size = 28, face = "bold",
                                         family = "MedievalSharp", color = "#2C1810",
                                         margin = margin(b = 6)),
            plot.subtitle = element_text(size = 13, family = "Garamond",
                                         color = "#5D3A1A", margin = margin(b = 12)),
            plot.caption  = element_text(family = "Garamond", size = 13,
                                         color = "#2C1810", hjust = 0.5,
                                         lineheight = 1.6, margin = margin(t = 10)),
            legend.text   = element_text(family = "Garamond", size = 14),
            legend.title  = element_text(family = "Garamond", size = 14, face = "bold"),
            legend.position = "bottom",
            plot.margin   = margin(20, 20, 20, 20)
          )

        incProgress(0.2, detail = "Heatmap...")

        heatmap_plot_p <- ggplot(scene_heatmap_data,
                                 aes(x = scene_label, y = character, fill = lines)) +
          geom_tile(color = "#F5E6C8", linewidth = 0.4) +
          geom_vline(data = act_sep, aes(xintercept = xpos),
                     color = "#9c8e7a", linewidth = 1.0, inherit.aes = FALSE) +
          scale_fill_gradient(low = "#e6dec9", high = "#7e1215",
                              name = "Lines spoken", na.value = "#e6dec9") +
          scale_x_discrete(expand = c(0, 0)) +
          scale_y_discrete(expand = c(0, 0)) +
          labs(title    = "Scene Presence of Primary Characters",
               subtitle = "Colour intensity = lines spoken  |  Pale = absent  |  Vertical lines = act boundaries",
               x = "Scene (Act.Number)", y = "Character") +
          hamlet_theme() +
          theme(
            axis.text.x     = element_text(angle = 45, hjust = 1, size = 11,
                                           family = "Garamond"),
            axis.text.y     = element_text(size = 13, family = "Garamond"),
            axis.title      = element_text(size = 16, face = "bold", family = "Garamond"),
            panel.grid      = element_blank(),
            legend.position = "right",
            plot.title      = element_text(hjust = 0.5, family = "Garamond", size = 22)
          )

        incProgress(0.2, detail = "Sentiment plot...")

        sentiment_char_colors <- c("Hamlet" = "#7e1215", "King Claudius" = "#1a2b4b")
        char_labels_p <- cumulative_sentiment_all %>%
          group_by(character) %>% slice_max(line_number, n = 1) %>% ungroup()

        sentiment_plot_p <- cumulative_sentiment_all %>%
          ggplot(aes(x = line_number, y = cumulative_sentiment, color = character)) +
          geom_line(linewidth = 1.3) +
          geom_vline(data = key_events, aes(xintercept = mid_line),
                     color = "#5a110a", linetype = "dotted", linewidth = 0.9,
                     inherit.aes = FALSE) +
          geom_text(data = key_events, aes(x = mid_line, label = event_label),
                    y = -5, angle = 90, hjust = 1, vjust = -0.4, size = 3.5,
                    family = "Garamond", fontface = "italic", color = "#5a110a",
                    inherit.aes = FALSE) +
          geom_label(data = char_labels_p, aes(label = character, fill = character),
                     color = "#e6dec9", fontface = "bold", family = "Garamond",
                     size = 4.5, hjust = 1, show.legend = FALSE) +
          geom_vline(data = act_boundaries, aes(xintercept = start_line),
                     color = "#9c8e7a", linetype = "dashed", linewidth = 0.8) +
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

        incProgress(0.2, detail = "Distinctive words...")

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
            title    = "Most Distinctive Word Stems for the Top 8 Characters in Hamlet",
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

        incProgress(0.1, detail = "Assembling poster...")

        h1 <- make_header("01", "Who is in this play \u2014 and who dominates the stage?")
        h2 <- make_header("02", "When do the characters appear?")
        h3 <- make_header("03", "How does the mood evolve?")
        h4 <- make_header("04", "What defines each character\u2019s voice?")

        poster <-
          title_panel /
          intro_panel /
          lk_panel /
          h1 / network_plot_p /
          h2 / heatmap_plot_p /
          h3 / sentiment_plot_p /
          h4 / distinctive_plot_p /
          caption_panel +
          plot_layout(heights = c(
            2.5,        # title
            9.0,        # intro text
            5.0,        # Lion King table
            1.2, 16,    # 01 + network
            1.2,  7,    # 02 + heatmap
            1.2,  9,    # 03 + sentiment
            1.2,  7,    # 04 + distinctive words
            1.2         # caption
          )) &
          theme(plot.background = element_rect(fill = "#F5E6C8", color = NA))

        incProgress(0.1, detail = "Saving PDF...")
        ggsave(file, poster, width = 22, height = 67,
               limitsize = FALSE, bg = "#F5E6C8")
      })
    }
  )
}

shinyApp(ui = ui, server = server)

