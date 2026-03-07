# Hamlet Data Visualization — Group 1
### Data Analytics with R

> *"To be, or not to be — that is the question."*
> We asked a different one: **what does the data say?**

This project takes Shakespeare's longest play and turns it into an interactive data story. The app runs in R Shiny, lets you explore four visualizations, and exports a print-ready PDF poster. Everything lives in one file: `Hamlet_DataViz_team1.r`.

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

Open `Hamlet_DataViz_team1.r` in RStudio and click **Run App**.

> **Before you start working**, always pull the latest changes from the repo:
> ```bash
> git pull
> ```

---

## Table of Contents

1. [Prerequisites & Installation](#1-prerequisites--installation)
2. [How to Run the App](#2-how-to-run-the-app)
3. [Libraries Used](#3-libraries-used)
4. [The Data](#4-the-data)
5. [The Story We Are Telling](#5-the-story-we-are-telling)
6. [Visualization 1 — Who Interacts With Whom? (Network Graph)](#6-visualization-1--who-interacts-with-whom-network-graph)
7. [Visualization 2 — Scene Presence Heatmap](#7-visualization-2--scene-presence-heatmap)
8. [Visualization 3 — Sentiment Progression](#8-visualization-3--sentiment-progression)
9. [Visualization 4 — Distinctive Words](#9-visualization-4--distinctive-words)
10. [The PDF Poster](#10-the-pdf-poster)
11. [App Structure at a Glance](#11-app-structure-at-a-glance)

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
  "shiny",
  "tidyverse",
  "tidytext",
  "widyr",
  "patchwork",
  "grid",
  "gridExtra",
  "png",
  "cowplot",
  "showtext",
  "tidygraph",
  "ggraph",
  "igraph",
  "SnowballC"
))
```

### Required data file
The app loads `01_hamlet.RData` from the working directory. Make sure this file sits in the **same folder** as `Hamlet_DataViz_team1.r` before running.

```
R_Hamlet_DataVizClub/
├── Hamlet_DataViz_team1.r   ← the app
├── 01_hamlet.RData          ← the data (required)
└── README.md
```

---

## 2. How to Run the App

**Option A — RStudio button**
Open `Hamlet_DataViz_team1.r` in RStudio. Click the **Run App** button that appears at the top of the editor.

**Option B — Console**
```r
shiny::runApp("Hamlet_DataViz_team1.r")
```

**Option C — Set working directory first**
```r
setwd("path/to/R_Hamlet_DataVizClub")
shiny::runApp("Hamlet_DataViz_team1.r")
```

The app will open in your browser. Navigate between tabs using the top navigation bar.

---

## 3. Libraries Used

| Library | What it does in this project |
|---|---|
| `shiny` | Builds the interactive web app — handles the UI layout, reactive inputs (sliders, checkboxes), and the download button |
| `tidyverse` | The backbone of all data wrangling — `dplyr` for filtering/grouping, `ggplot2` for plotting, `stringr` for word counting |
| `tidytext` | Splits dialogue into individual words (`unnest_tokens`), removes filler words (`anti_join(stop_words)`), and joins the Bing sentiment lexicon |
| `widyr` | Counts pairwise co-occurrences — used to find how many scenes each pair of characters share (`pairwise_count`) |
| `patchwork` | Stacks and arranges multiple ggplot objects into the final poster layout using `/` and `+` operators |
| `grid` | Low-level graphics primitives — `unit()` is used for label padding in the network graph |
| `gridExtra` | Renders the Lion King comparison table as a styled grid object (`tableGrob`) for embedding in the poster |
| `png` | Reads PNG image files back into R as raster objects (used if image assets are embedded) |
| `cowplot` | Provides `ggdraw` and `draw_grob` for combining ggplot and non-ggplot elements |
| `showtext` | Loads Google Fonts — EB Garamond (body), MedievalSharp (headers), UnifrakturMaguntia (poster title) — and makes them available inside ggplot |
| `tidygraph` | Represents the character network as a tidy tibble-based graph that works with dplyr operations |
| `ggraph` | Draws the network graph on top of ggplot2 — handles node positions, edge arcs, and labels |
| `igraph` | Provides the underlying graph algorithms: Fruchterman-Reingold layout (`fr`), vertex count, and edge density |
| `SnowballC` | Stems words to their root form (`wordStem`) — so "drowned", "drowning", "drown" all become `drown` for the distinctive words analysis |

---

## 4. The Data

The dataset is loaded from `01_hamlet.RData`. It contains the full text of Hamlet with one row per spoken line:

| Column | Description |
|---|---|
| `character` | Who is speaking (e.g. `"Hamlet"`, `"King Claudius"`, `"[stage direction]"`) |
| `act` | The act (e.g. `"Act I"`, `"Act III"`) |
| `scene` | The scene within the act |
| `line_number` | Sequential line number across the whole play (1 → ~3,800) |
| `dialogue` | The actual text spoken |

Stage directions are tagged as `[stage direction]` and are filtered out before every analysis. The play runs across **5 acts**, **20 scenes**, and roughly **3,800 lines** of dialogue.

---

## 5. The Story We Are Telling

Hamlet is Shakespeare's longest play and one of the most studied works in the English language. But reading it line by line can be overwhelming. Our goal was to answer four simple questions using data:

1. **Who is even in this play, and who dominates the stage?**
2. **When do the characters appear — and disappear?**
3. **How does the emotional tone shift across the five acts?**
4. **What words are uniquely tied to each character's voice?**

To make the play accessible to anyone who hasn't read it, we map the characters to *The Lion King* — which is directly based on Hamlet. Simba is Hamlet, Scar is Claudius, Mufasa is the Ghost, and so on. Same story, different savanna.

The four visualizations are designed to build on each other: first you meet the cast (network), then you see when they appear (heatmap), then you feel the emotional journey (sentiment), and finally you hear how each character speaks (distinctive words).

---

## 6. Visualization 1 — Who Interacts With Whom? (Network Graph)

**The question:** Which characters share the stage, and how often?

### How we built it

**Step 1 — Raw data in, one row per character per scene**
We started with the full `hamlet` dataset and removed stage directions. Then we called `distinct(character, act, scene)` — this collapses each character down to one row per scene they appear in, stripping out the individual lines. We then combined act and scene into a single ID like `"Act I_Scene 1"` using `unite()`.

**Step 2 — Count shared scenes for every pair**
We fed that scene-presence table into `pairwise_count(character, scene_id)` from the `widyr` package. This function looks at every possible pair of characters and counts how many scene IDs they both appear in. The result is a table of edges: `from`, `to`, `n` (scenes shared).

**Step 3 — Count total words per character**
In parallel, we counted how many words each character speaks across the whole play using `str_count(dialogue, "\\S+")` — a regex that counts space-separated tokens.

**Step 4 — Build the graph**
We passed the edge table into `as_tbl_graph()` (tidygraph), then joined the word counts onto the nodes. Each node got a colour from our vintage palette.

**Step 5 — Layout and render**
We used `create_layout(..., algorithm = "fr")` — the Fruchterman-Reingold algorithm — which places frequently-connected characters physically closer together. `set.seed(42)` locks the layout so it looks the same every time. The graph was rendered with `ggraph`.

### What to read from it
- **Node size** = total words spoken. Hamlet's circle is enormous.
- **Edge thickness** = scenes shared. A thick line means two characters are frequently on stage together.
- **The slider** in the app filters out edges below a minimum number of shared scenes — drag it right to strip away peripheral relationships and see the core social network.

---

## 7. Visualization 2 — Scene Presence Heatmap

**The question:** When exactly does each character appear — and when are they absent?

### How we built it

**Step 1 — Count lines per character per scene**
We grouped the data by `character`, `act`, and `scene`, then counted rows (`n()`). Each row in the result tells us how many lines a given character spoke in a given scene.

**Step 2 — Parse scene numbers robustly**
Scene labels in the dataset are inconsistent — some are integers (`1`, `2`), some are Roman numerals (`IV`), some are full strings (`"Scene IV"`). We wrote a three-level fallback using `coalesce()`:
1. Try `as.integer(s)` directly
2. Try `as.integer(as.roman(s))`
3. Try extracting a trailing Roman numeral with a regex, then converting

This guarantees every scene gets a proper integer for sorting.

**Step 3 — Create the full grid**
We called `complete(character, scene_label)` to fill in every character × scene combination, even ones where the character didn't speak. Those get `lines = 0`, which renders as the pale background colour.

**Step 4 — Order everything correctly**
Scenes are ordered chronologically (Act I.1, I.2, ... V.2). Characters are ordered by total lines spoken, with Hamlet at the top.

**Step 5 — Draw the heatmap**
`geom_tile()` draws one rectangle per cell. `scale_fill_gradient()` maps line count to colour — from pale parchment (zero lines) to deep crimson (dominant scene). Vertical gold lines mark act boundaries.

### What to read from it
- **Pale cells** = the character is absent from that scene.
- **Dark crimson** = the character dominates that scene.
- The most striking pattern: **Hamlet goes nearly silent in Act IV** (he's been sent to England). The heatmap makes this structural absence immediately visible.
- The **checkboxes** in the app let you isolate any subset of characters to compare their patterns side by side.

---

## 8. Visualization 3 — Sentiment Progression

**The question:** Does the emotional tone of the play get darker over time — and do Hamlet and Claudius feel the same way?

### How we built it

**Step 1 — Tokenize and filter each character's dialogue**
We filtered the dataset to one character at a time (first Hamlet, then King Claudius). Each line of dialogue was split into individual words with `unnest_tokens()`, converted to lowercase, and stripped of stop words (`anti_join(stop_words)`).

**Step 2 — Score every word**
We joined the remaining words against the **Bing sentiment lexicon** (`get_sentiments("bing")`), which labels ~6,800 English words as either "positive" or "negative". Each positive word got a score of `+1`, each negative word `-1`.

**Step 3 — Sum scores per line**
We grouped by `line_number` and summed the sentiment values. A line with three negative words and one positive gets a score of `-2`. Lines with no sentiment words get dropped at this stage.

**Step 4 — Cumulative sum**
We sorted by `line_number` and called `cumsum()` on the line scores. This produces a running total — a line that goes up means the character's language is getting more positive in that stretch, down means more negative.

**Step 5 — Combine and plot**
We did the same calculation for both characters and combined them with `bind_rows()`. The chart plots both running totals as lines, coloured by character. Three key dramatic events are annotated with dotted vertical lines: Polonius's death, Ophelia's drowning, and the final bloodbath.

### What to read from it
- Both characters trend **downward overall** — the play gets darker as it progresses.
- Hamlet's line drops sharply around the key events.
- Claudius's language stays relatively measured — he is a calculating villain, not an emotional one.
- The **checkboxes** in the app let you toggle each character's line on or off.

---

## 9. Visualization 4 — Distinctive Words

**The question:** What words does each character use that are uniquely *theirs* — not just words they say a lot, but words they say *disproportionately more* than anyone else?

### How we built it

**Step 1 — Tokenize all 8 characters' dialogue**
We filtered to the top 8 characters (by total lines spoken — same set used in every other visualization), then split their dialogue into words and removed stop words.

**Step 2 — Stem every word**
We used `wordStem()` from `SnowballC` to reduce words to their root. "Drowned", "drowning", and "drown" all become `drown`. This prevents the same concept from being split across multiple word forms.

**Step 3 — Count and calculate proportions**
For each character–stem pair, we counted occurrences. We then calculated:
- `prop_this_character` = what fraction of *this character's* words is this stem?
- `prop_overall` = what fraction of *all words in the play* is this stem?

**Step 4 — Compute the distinctiveness ratio**
```
relative = prop_this_character / prop_overall
```
A ratio of `3.0` means this character uses that word **three times more** than the play average. Words said fewer than 3 times total were excluded as noise.

**Step 5 — Take the top N per character and plot**
We sliced the top N stems per character (default 5, adjustable via the slider). The words are arranged in a dot-plot grid — character on the Y axis, rank on the X axis. Colour encodes the log of the ratio: deep crimson = extremely distinctive, navy = moderately distinctive.

### What to read from it
- The **same word can appear for two characters but in different colours** because the colour is the character's *individual ratio*, not the word itself. Ghost's `thou` is much darker than Hamlet's `thou` because Ghost speaks almost exclusively in archaic language, making his ratio far higher.
- **First Clown** (gravedigger) has words like `drown` and `water` in deep crimson — he only appears in one scene, so his concentrated vocabulary produces extreme ratios.
- **The slider** adjusts how many words per character are shown (3 to 7).

---

## 10. The PDF Poster

The **Export PDF** tab generates a single vertical scrollable poster (22 × 67 inches) containing:

| Section | Content |
|---|---|
| Title | "A Visual Analysis of Hamlet by Shakespeare" in UnifrakturMaguntia blackletter |
| Intro text | Brief summary of the play and the analysis approach |
| Lion King table | Character mapping to help unfamiliar readers orient themselves |
| 01 — Network | Full network graph with caption |
| 02 — Heatmap | Full scene presence heatmap |
| 03 — Sentiment | Full sentiment progression chart |
| 04 — Distinctive Words | Full distinctive words grid |
| Caption | Team member names |

Click **Download PDF Poster** and wait — a progress bar tracks each build step. The file is saved as `hamlet_analysis_visualization.pdf`.

> Note: The poster uses Google Fonts loaded via `showtext`. First run may be slower if fonts need to download.

---

## 11. App Structure at a Glance

```
Hamlet_DataViz_team1.r
│
├── GLOBAL SETUP (lines 1–214)
│   ├── Libraries
│   ├── Fonts (Google Fonts via showtext)
│   ├── Data load (01_hamlet.RData)
│   ├── Color palette (9 characters, vintage hex codes)
│   ├── Top 8 characters + character_totals
│   ├── Act boundaries
│   ├── hamlet_theme() — shared ggplot2 theme
│   ├── Network data  (pairwise scene co-occurrences + word totals)
│   ├── Sentiment data (cumulative Bing scores for Hamlet + Claudius)
│   ├── Heatmap data  (lines per character per scene, full grid)
│   └── Distinctive words data (TF-IDF ratios, pre-computed base table)
│
├── UI (lines 216–327)
│   ├── navbarPage with vintage CSS
│   ├── Tab 1: Network       — slider (min shared scenes)
│   ├── Tab 2: Scene Heatmap — checkboxes (character filter)
│   ├── Tab 3: Sentiment     — checkboxes (Hamlet / Claudius)
│   ├── Tab 4: Distinctive   — slider (words per character)
│   └── Tab 5: Export PDF    — download button
│
└── SERVER (lines 329–803)
    ├── Heatmap checkbox initialisation
    ├── output$network_plot     — reactive, filters edges by input$min_scenes
    ├── output$heatmap_plot     — reactive, filters characters by input$heatmap_chars
    ├── output$sentiment_plot   — reactive, filters characters by input$sent_chars
    ├── output$distinctive_plot — reactive, slices top N by input$n_words
    └── output$download_pdf     — downloadHandler, builds full poster + ggsave
```

---

*Group 1 — Data Analytics with R*
*Andrés Ramírez Arroyo · Ferdinand Rasmussen · Federica Selvini · Max Voss · Jad Zoghaib*
