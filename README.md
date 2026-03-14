# Hamlet Data Visualization — Group 1
### Data Analytics with R

> *"To be, or not to be — that is the question."*
> We asked a different one: **what does the data say?**

This project takes Shakespeare's longest play and turns it into a data-driven poster. The script loads `01_hamlet.RData`, runs four distinct analyses, and saves a single high-resolution PNG poster (`hamlet_analysis_visualization.png`). Everything lives in one file: `Hamlet_DataViz_team1.r`.

---

## Getting the Project (Clone)

If you are a collaborator or want to run this project on your machine, clone the repository first:

```bash
git clone https://github.com/jadzoghaib/R_Hamlet_DataVizClub.git
```

Then navigate into the project folder:

```bash
cd R_Hamlet_DataVizClub
```

Open `Hamlet_DataViz_team1.r` in RStudio and click **Source** (not Run App — this is no longer a Shiny application).

> **Before you start working**, always pull the latest changes from the repo:
> ```bash
> git pull
> ```

---

## Table of Contents

1. [Prerequisites & Installation](#1-prerequisites--installation)
2. [How to Run the Script](#2-how-to-run-the-script)
3. [Libraries Used](#3-libraries-used)
4. [The Data](#4-the-data)
5. [The Story We Are Telling](#5-the-story-we-are-telling)
6. [Visualization 1 — Who Speaks With Whom? (Chord Diagram)](#6-visualization-1--who-speaks-with-whom-chord-diagram)
7. [Visualization 2 — Scene Presence Heatmap](#7-visualization-2--scene-presence-heatmap)
8. [Visualization 3 — Sentiment Progression](#8-visualization-3--sentiment-progression)
9. [Visualization 4 — Distinctive Words](#9-visualization-4--distinctive-words)
10. [The Poster](#10-the-poster)
11. [Script Structure at a Glance](#11-script-structure-at-a-glance)

---

## 1. Prerequisites & Installation

### R version
You need **R 4.2 or higher**. Download from [https://cran.r-project.org](https://cran.r-project.org).

### RStudio (recommended)
Download from [https://posit.co/download/rstudio-desktop](https://posit.co/download/rstudio-desktop).

### Install all required packages
Open R or RStudio and run the following once:

```r
install.packages(c(
  "tidyverse",
  "tidytext",
  "widyr",
  "patchwork",
  "grid",
  "gridExtra",
  "png",
  "cowplot",
  "showtext",
  "SnowballC",
  "scales",
  "ggrepel",
  "circlize"
))
```

### Required data file
The script loads `01_hamlet.RData` from the working directory. Make sure this file sits in the **same folder** as `Hamlet_DataViz_team1.r` before running.

```
R_Hamlet_DataVizClub/
├── Hamlet_DataViz_team1.r              ← the script
├── 01_hamlet.RData                     ← the data (required)
├── hamlet_analysis_visualization.png   ← output (generated on run)
└── README.md
```

---

## 2. How to Run the Script

**Option A — RStudio button**
Open `Hamlet_DataViz_team1.r` in RStudio. Click **Source** at the top of the editor. The script will run top-to-bottom, print progress messages in the console, and write `hamlet_analysis_visualization.png` to the working directory.

**Option B — Console**
```r
source("Hamlet_DataViz_team1.r")
```

**Option C — Set working directory first**
```r
setwd("path/to/R_Hamlet_DataVizClub")
source("Hamlet_DataViz_team1.r")
```

The output file is `hamlet_analysis_visualization.png` (40 × 26 inches at 150 dpi).

> Note: The script uses Google Fonts loaded via `showtext`. The first run may be slower if fonts need to download from Google's servers.

---

## 3. Libraries Used

| Library | What it does in this project |
|---|---|
| `tidyverse` | The backbone of all data wrangling — `dplyr` for filtering/grouping/joining, `ggplot2` for all static plots, `stringr` for text operations, `purrr` for `pmap_dfr` |
| `tidytext` | Splits dialogue into individual tokens (`unnest_tokens`), removes stop words (`anti_join(stop_words)`), and joins the Bing sentiment lexicon |
| `widyr` | (Retained as a dependency) Counts pairwise co-occurrences |
| `patchwork` | Assembles all ggplot objects into the final poster layout using `/` and `\|` operators and `plot_layout()` |
| `grid` | Low-level graphics primitives — `unit()` for sizing in `gridExtra` layouts |
| `gridExtra` | Renders the Lion King comparison table as a styled `tableGrob` and stacks panels with `arrangeGrob` |
| `png` | Reads the chord diagram PNG back into R as a raster object so it can be embedded in the patchwork layout |
| `cowplot` | Wraps the chord PNG raster into a ggplot-compatible panel via `ggdraw` + `draw_image` |
| `showtext` | Loads Google Fonts — EB Garamond (body text), MedievalSharp (section headers), UnifrakturMaguntia (poster title) — and makes them available inside ggplot and base graphics |
| `SnowballC` | Stems words to their root form (`wordStem`) so that "drowned", "drowning", and "drown" all collapse to `drown` for the distinctive words analysis |
| `scales` | Provides `percent` formatter for the heatmap legend |
| `ggrepel` | Draws non-overlapping annotation labels on the sentiment chart (`geom_label_repel`) |
| `circlize` | Draws the chord diagram — handles arc proportions, ribbon colours, sector gaps, and circular text labels |

---

## 4. The Data

The dataset is loaded from `01_hamlet.RData`. It contains the full text of Hamlet with one row per spoken line:

| Column | Description |
|---|---|
| `character` | Who is speaking (e.g. `"Hamlet"`, `"King Claudius"`, `"[stage direction]"`) |
| `act` | The act as a string (e.g. `"Act I"`, `"Act III"`) |
| `scene` | The scene within the act (format varies: integers, Roman numerals, or full strings) |
| `line_number` | Sequential line number across the whole play (1 → ~3,800) |
| `dialogue` | The actual text spoken |

Stage directions are tagged as `[stage direction]` and are filtered out before every analysis. The play runs across **5 acts**, **20 scenes**, and roughly **3,800 lines** of dialogue.

---

## 5. The Story We Are Telling

Hamlet is Shakespeare's longest play and one of the most studied works in the English language. Our goal was to answer four simple questions using data:

1. **Who is in this play — and who dominates the stage?**
2. **When do the characters appear — and disappear?**
3. **How does the emotional tone shift across the five acts?**
4. **What words are uniquely tied to each character's voice?**

To make the play accessible to anyone who hasn't read it, we map the characters to *The Lion King* — which is directly based on Hamlet. Simba is Hamlet, Scar is Claudius, Mufasa is the Ghost, and so on. Same story, different savanna.

The four visualizations build on each other: first you meet the cast and see how they connect (chord diagram), then you see precisely when they appear (heatmap), then you feel the emotional journey (sentiment), and finally you hear how each character speaks (distinctive words).

---

## 6. Visualization 1 — Who Speaks With Whom? (Chord Diagram)

**The question:** Which characters share the stage, and how much of their dialogue happens in each other's presence?

---

### Full Pipeline

#### Step 1 — Data Ingestion
The raw `hamlet` data frame is filtered to rows where `character %in% main_characters` (the top 7 by line count). Stage directions are excluded at the `main_characters` selection stage since they never appear in the top 7.

#### Step 2 — Count Lines Per Character Per Scene
The filtered data is grouped by `act`, `scene`, and `character`, and rows are counted with `n()`. The result (`sl`) is one row per character-scene combination, with a column `lines` holding that character's spoken line count in that scene. Simultaneously, a `n_top7` column is added via `group_by(act, scene) %>% mutate(n_top7 = n())` — this records how many of the 7 main characters appear in each scene. This number drives the weighting in the next step.

#### Step 3 — Build the Asymmetric Chord Matrix
This is the core data structure for the chord diagram. It is a 7×7 matrix where `matrix[i][j]` represents how many lines character `i` spoke **in scenes where character `j` was also present**.

**Off-diagonal entries** — For every scene containing at least two main characters (`n_top7 >= 2`), the data is self-joined on `act` and `scene` to produce all ordered character pairs `(i, j)` within that scene. Each pair gets a weighted contribution:

```
contrib = lines_i / (n_top7 - 1)
```

The division by `(n_top7 - 1)` ensures that character `i`'s lines are split evenly across all co-present characters. Without this weight, a scene with all 7 characters would count each of Hamlet's lines six times across his six co-presence entries. With the weight, the total of all off-diagonal entries for a character equals the lines they actually spoke in multi-character scenes. These contributions are summed with `group_by(character, char_j) %>% summarise(total = sum(contrib))` and written into the matrix with a `for` loop.

**Diagonal entries** — Scenes where only one main character is present (`n_top7 == 1`) contribute to the diagonal. These are the character's "solo" lines. The sum of solo lines per character is computed and placed at `matrix[i][i]`. The diagonal renders as a self-loop ribbon on the outside of the arc — visually indicating lines spoken without any other main character on stage.

The entire matrix is rounded to integers with `round()`.

#### Step 4 — Colour Setup
Each character has a fixed hex colour from the `character_colors` palette. A 7×7 colour matrix is constructed where `col_mat[i][j]` is the source character `i`'s colour at 45% opacity (`adjustcolor(..., alpha.f = 0.45)`). Diagonal entries remain `NA` so that self-loop ribbons inherit the sector grid colour directly.

#### Step 5 — Render the Chord Diagram
The chord diagram is drawn using `circlize::chordDiagram()` inside the `draw_chord()` function. Key parameters:
- `start.degree = 90` — the first sector starts at the top of the circle.
- `gap.degree = 3` — a 3° gap separates each sector.
- `annotationTrack = "grid"` — only the coloured arc grid is drawn automatically; labels are added manually in the next step.
- `link.border` — a semi-transparent dark brown border on each ribbon for visual separation.
- `self.link = 1` — self-loops (diagonal entries) are rendered as tight ribbons on the outside of the sector.

#### Step 6 — Add Character Labels
A second track is drawn with `circos.trackPlotRegion()`. For each sector, `circos.text()` places the character name clockwise along the outside of the arc, coloured in that character's palette colour and bolded.

#### Step 7 — Capture as PNG and Re-embed
Because `circlize` uses base R graphics (not ggplot2), it cannot be combined directly with `patchwork`. The workaround:
1. A temporary PNG file is opened with `png(tmp_chord, width = 1200, height = 1200, res = 150)`.
2. `draw_chord()` renders into it and `dev.off()` closes the device.
3. `png::readPNG(tmp_chord)` reads the file back as a raster array.
4. `cowplot::ggdraw() + cowplot::draw_image(chord_img)` wraps the raster into a ggplot-compatible object that patchwork can place in the layout.

#### What to read from it
- **Arc length** for each sector = total lines spoken by that character across the whole play. Hamlet's arc is by far the largest.
- **Ribbon width at a sector** = how many of that character's lines occur in the other character's presence (weighted).
- **Ribbon colour** = the source character (who is speaking). A dark red ribbon flowing from Hamlet to Horatio means Hamlet spoke many lines while Horatio was on stage.
- **Self-loop ribbon** = lines spoken when no other main character was present.

---

## 7. Visualization 2 — Scene Presence Heatmap

**The question:** When exactly does each character appear — and when are they absent?

---

### Full Pipeline

#### Step 1 — Data Ingestion
The full `hamlet` data frame is loaded. Stage directions (`character == "[stage direction]"`) are excluded. All characters are retained at this stage (not yet filtered to the top 7) because the `scene_total_lines` denominator needs to count every spoken line in a scene, regardless of who speaks it.

#### Step 2 — Compute Scene-Level Line Totals
Before filtering to main characters, a scene-level total is computed using `group_by(act, scene) %>% mutate(scene_total_lines = n())`. This attaches to every row the total number of spoken lines in that scene across all characters. This is the denominator for the share calculation in Step 4.

#### Step 3 — Filter and Count Per Character
The data is then filtered to `character %in% main_characters`. It is grouped by `character`, `act`, `scene`, and `scene_total_lines` (which is already attached), and rows are counted to get `lines` — how many lines that character spoke in that scene.

#### Step 4 — Compute Line Share
```r
line_share = lines / scene_total_lines
```
This transforms raw line counts into a proportion: 0 means absent, 1 means the character spoke every line in the scene (never quite happens), 0.6 means they spoke 60% of the scene's dialogue. Using share rather than raw count normalizes across scenes of very different lengths.

#### Step 5 — Parse Scene Numbers Robustly
Scene labels in the dataset are inconsistent — some are stored as integers (`1`), some as Roman numerals (`IV`), some as full strings (`"Scene IV"`). A three-level fallback using `coalesce()` handles all cases:
1. `as.integer(s)` — works for numeric strings.
2. `as.integer(as.roman(s))` — works for plain Roman numeral strings like `"IV"`.
3. A regex `gsub("^.*\\s([IVXivx]+)$", "\\1", trimws(s))` extracts a trailing Roman numeral from a longer string (e.g. `"Scene IV"` → `"IV"`), then converts.

All suppressWarnings calls prevent console noise from failed coercions. The result `scene_num` is always an integer.

#### Step 6 — Build Scene Labels and Order
Scene labels are constructed as `paste0(act_labels[act], ".", scene_num)` — producing labels like `"I.1"`, `"III.4"`, `"V.2"`. A reference vector `scene_order` is built by pulling these labels sorted by `act_num` then `scene_num`, which gives the correct chronological left-to-right order on the X axis.

Act separator positions (`act_sep`) are computed by counting scenes per act, taking cumulative sums, and adding 0.5 to place vertical lines between tiles rather than on top of them.

#### Step 7 — Complete the Grid
`tidyr::complete(character, scene_label = scene_order)` fills in every character × scene combination that does not appear in the data (scenes where the character has zero lines). Missing `lines` and `line_share` values are filled with `0` — these render as the pale background colour on the heatmap.

#### Step 8 — Factor Ordering
`scene_label` is factored with levels = `scene_order` to enforce chronological X-axis order. `character` is factored with levels from `character_totals$character` (which is ordered descending by total lines) so Hamlet appears at the top.

#### Step 9 — Draw the Heatmap
`geom_tile()` draws one rectangle per character × scene cell. The fill scale maps `line_share` from pale parchment (`#e6dec9` at 0%) to deep crimson (`#7e1215` at 100%) using `scale_fill_gradient()`. Vertical gold-grey lines from `geom_vline()` mark act boundaries at the pre-computed `act_sep$xpos` positions.

#### What to read from it
- **Pale cells** — the character is absent from or barely present in that scene.
- **Deep crimson** — the character dominates that scene's dialogue.
- The most striking pattern: **Hamlet goes nearly silent in Act IV** (he has been sent to England by Claudius). The structural absence is immediately visible as a pale gap across his row.
- Characters who die mid-play (Polonius at III.4, Ophelia in Act IV) have their rows go permanently pale after that point.

---

## 8. Visualization 3 — Sentiment Progression

**The question:** Does the emotional tone of the play get darker over time — and do Hamlet and Claudius feel the same way?

---

### Full Pipeline

#### Step 1 — Data Ingestion Per Character
The pipeline runs identically and independently for Hamlet and King Claudius. For each, the `hamlet` data frame is filtered to rows where `character == [target]`.

#### Step 2 — Tokenization
`tidytext::unnest_tokens(word, dialogue)` splits each line of dialogue into individual word tokens. The function lowercases everything and strips punctuation automatically. Each row in the result is one word token, still carrying its source `line_number`, `act`, and `scene`.

#### Step 3 — Stop Word Removal
`anti_join(stop_words, by = "word")` removes tokens that appear in the `tidytext` stop word list — common function words like "the", "a", "of", "in", "that". These words carry no sentiment signal and would dilute the analysis. After this step, only content-bearing words remain.

#### Step 4 — Sentiment Scoring via Bing Lexicon
`inner_join(get_sentiments("bing"), by = "word")` matches the remaining tokens against the **Bing sentiment lexicon**, a dictionary of ~6,800 English words manually labelled as either `"positive"` or `"negative"`. Words not in the lexicon are dropped (only lexicon matches are retained). Each matched word then gets a numeric score:
```r
sentiment_value = ifelse(sentiment == "positive", 1, -1)
```

#### Step 5 — Aggregate Scores Per Line
The token-level data is grouped by `line_number`, `act`, and `scene`, and scores are summed with `sum(sentiment_value)`. The result `line_sentiment` is one row per spoken line that contained at least one sentiment word. A line containing "murder" (−1), "grief" (−1), and "noble" (+1) gets a `line_sentiment` of −1.

#### Step 6 — Cumulative Sum
The line-level scores are sorted by `line_number` and then `cumsum(line_sentiment)` produces a running total. This is `cumulative_sentiment` — it rises when a character's recent language is positive-skewing, and falls when it is negative-skewing. The absolute value at any point reflects the accumulated emotional weight from line 1 to that point.

#### Step 7 — Combine Characters
The Hamlet and Claudius data frames are combined with `bind_rows()`, with a `character` column added before binding to distinguish the two lines on the chart.

#### Step 8 — Locate Annotation Points
Six key dramatic events are annotated. Rather than placing annotations at fixed line numbers, each annotation is placed at the actual sentiment extremum within a defined window. A `event_windows` tibble defines each event's label, which character's line to look at, and a `[line_min, line_max]` search window. `pmap_dfr()` iterates over these rows and for each one:
1. Filters `cumulative_sentiment_all` to the specified character and line range.
2. Finds both the minimum and maximum cumulative sentiment within the window.
3. Picks whichever has the larger absolute value — i.e., the most emotionally extreme point in that stretch.

The result is a six-row data frame of actual data points on the lines, used for annotation placement.

#### Step 9 — Plot
The two cumulative lines are drawn with `geom_line()`, coloured by character. Annotation points are drawn as open circles with `geom_point()`. `ggrepel::geom_label_repel()` draws the event labels with automatic collision avoidance — labels are nudged upward and connected to their points by arrows. Act boundaries are drawn as dashed vertical lines with act names placed at the top of the panel. Character name labels are placed at the end of each line using `geom_label()`.

#### What to read from it
- Both characters trend **downward overall** — the play's language gets progressively darker from Act I to Act V.
- Hamlet's line is volatile — it drops sharply at key events and occasionally recovers.
- Claudius's line descends more steadily and at a shallower slope — his language is more controlled and measured, consistent with his character as a calculating, composed villain.
- The six annotated turning points correspond to the play's most pivotal dramatic moments.

---

## 9. Visualization 4 — Distinctive Words

**The question:** What words does each character use that are uniquely *theirs* — not just words they say often, but words they say *disproportionately more* than anyone else in the play?

---

### Full Pipeline

#### Step 1 — Data Ingestion
The `hamlet` data frame is filtered to exclude stage directions and to keep only rows where `character %in% main_characters` (the top 7 characters). This ensures the analysis covers only the characters with enough dialogue to produce statistically meaningful distinctive words.

#### Step 2 — Tokenization
`tidytext::unnest_tokens(word, dialogue)` splits all dialogue into individual word tokens, lowercased and stripped of punctuation. Every token still carries its source `character`.

#### Step 3 — Stop Word Removal
`anti_join(stop_words, by = "word")` removes common function words. This is the same step as in the sentiment pipeline. After this, only content words remain.

#### Step 4 — Stemming
`SnowballC::wordStem(word, language = "english")` reduces each token to its morphological root using the Porter stemming algorithm. Examples:
- `"drowned"`, `"drowning"`, `"drown"` → `"drown"`
- `"king"`, `"kings"` → `"king"`
- `"love"`, `"loved"`, `"loving"` → `"love"`

Stemming prevents the same concept from being split across word forms, which would artificially dilute each form's count and make distinctiveness ratios harder to detect.

#### Step 5 — Count Occurrences Per Character-Stem Pair
`count(word_stem, character)` produces a table of how many times each character uses each stemmed word. This is the raw frequency matrix.

#### Step 6 — Compute Character-Level Proportions
Within each character's vocabulary (grouped by `character`), the proportion of each stem is computed:
```r
prop_this_character = n / sum(n)
```
This is the fraction of that character's total word output that this particular stem represents.

#### Step 7 — Compute Play-Level Proportions
Across the entire combined vocabulary (ungrouped), the overall proportion of each stem is computed:
```r
prop_overall = n / sum(n)
```
This is the fraction of all words in the play (across all 7 characters) that this stem represents.

#### Step 8 — Compute the Distinctiveness Ratio
```r
relative = prop_this_character / prop_overall
```
A ratio of `3.0` means this character uses this stem **three times more frequently** than the play average. A ratio of `10.0` means ten times more. This metric controls for the fact that some words are simply common in Elizabethan English — what matters is whether *this character* uses them more than expected.

Words with fewer than 3 total occurrences (`filter(n > 2)`) are excluded as noise — a word said once or twice can produce an extreme ratio by chance.

#### Step 9 — Rank and Slice Per Character
For the poster, each character's stems are sorted descending by `relative` (with `n` as a tiebreaker) and the top 5 are selected with `slice(1:5)`. A `rank` column (1 through 5) is added within each character for X-axis positioning.

#### Step 10 — Plot
The words are displayed as a dot-plot grid: character on the Y axis (ordered by total lines, reversed so Hamlet is at top), rank on the X axis (1 = most distinctive). The text itself is plotted with `geom_text()` rather than points, so the word label *is* the data point. Colour encodes `log(relative)` on a gradient from navy (moderately distinctive) to deep crimson (extremely distinctive). The log scale prevents one extreme value from washing out all other colours.

#### What to read from it
- **Position** — rank 1 is the single most distinctive word for that character.
- **Colour** — deep crimson means the character uses this word at an extreme multiple of the play average; navy means the excess is real but more modest.
- The **same word can appear for two characters in different colours** because the colour encodes each character's individual ratio, not the word itself. Ghost's `thou` is deep crimson because he speaks almost exclusively in archaic second-person singular, making his ratio extremely high. Hamlet also uses `thou` but in a far more mixed vocabulary, so his ratio is lower and his colour is cooler.
- **First Clown** (the gravedigger) has words like `drown` and `water` at extreme ratios because he appears in only one scene and his vocabulary is tightly concentrated around the burial of Ophelia.

---

## 10. The Poster

Running the script generates a single PNG file (`hamlet_analysis_visualization.png`, 40 × 26 inches at 150 dpi) with the following layout:

```
┌──────────────────────────────────────────────────────────────────────┐
│  Intro text + Lion King table  │  Title banner                       │
│                                ├──────────────────┬──────────────────│
│                                │  01 Chord Diagram│  02 Heatmap      │
├────────────────────────────────┴──────────────────┴──────────────────┤
│  03 Sentiment Progression      │  04 Distinctive Words               │
├───────────────────────────────────────────────────────────────────────┤
│  Team member names (caption)                                         │
└───────────────────────────────────────────────────────────────────────┘
```

| Section | Content |
|---|---|
| Title | "A Visual Analysis of Hamlet by Shakespeare" in UnifrakturMaguntia blackletter |
| Intro text | Brief summary of the play and our four analytical questions |
| Lion King table | Character mapping to orient readers unfamiliar with Hamlet |
| 01 — Chord Diagram | Asymmetric chord diagram of lines spoken in shared scenes |
| 02 — Scene Presence | Heatmap of each character's share of dialogue per scene |
| 03 — Sentiment | Cumulative Bing sentiment progression for Hamlet and Claudius |
| 04 — Distinctive Words | Top 5 most distinctive word stems per character (dot-plot grid) |
| Caption | Team member names |

The poster background colour (`#F5E6C8`) is a warm parchment tone carried consistently across every panel.

---

## 11. Script Structure at a Glance

```
Hamlet_DataViz_team1.r
│
├── GLOBAL SETUP
│   ├── Libraries
│   ├── Fonts (Google Fonts via showtext)
│   ├── Data load (01_hamlet.RData)
│   ├── Color palette (7 characters, vintage hex codes)
│   ├── Top 7 characters + character_totals
│   ├── Act boundaries
│   ├── hamlet_theme() — shared ggplot2 theme
│   ├── chord_matrix_lines — asymmetric 7×7 lines-in-shared-scenes matrix
│   ├── draw_chord() — circlize chord diagram render function
│   ├── Heatmap data (line_share per character per scene, full grid)
│   ├── Sentiment data (cumulative Bing scores for Hamlet + Claudius)
│   ├── sentiment_annotations — extremum-anchored event labels
│   └── distinctive_words_base — stemmed proportions + distinctiveness ratios
│
├── make_header() — section header panel generator
│
└── POSTER ASSEMBLY BLOCK
    ├── title_panel
    ├── intro_plot + lk_table_grob → left_col
    ├── Chord PNG → tmp_chord → network_plot_p (via cowplot)
    ├── heatmap_plot_p
    ├── sentiment_plot_p
    ├── distinctive_plot_p
    ├── Section headers (sec1–sec4) via make_header()
    ├── Patchwork layout: top_section / bottom_section / caption_panel
    └── ggsave → hamlet_analysis_visualization.png
```

---

*Group 1 — Data Analytics with R*
*Andrés Ramírez Arroyo · Ferdinand Rasmussen · Federica Selvini · Max Voss · Jad Zoghaib*
