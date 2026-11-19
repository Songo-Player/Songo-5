#!/usr/bin/env python3
"""Builds a static theme info and download page for GitHub Pages.

Reads every packaged theme in themes_packaged/ (the theme_packer.gd output:
theme.json, theme.pck, theme.tres, preview.png), plus the themes built into
Songo from ../internal_themes/ when theme_dev sits inside a Songo-5 checkout,
and writes a site to docs/. Built-in themes get a card but no downloads; it
says they're included in Songo instead.

    docs/index.html          one card per theme: preview, details, a download
                             button, and install steps; styled after
                             the Songo Classic theme
    docs/themes.json         the same details as data, with download links
    docs/themes/<Dir>.zip    the packaged theme folder, ready to unzip into
                             songo_themes/ or external_themes/
    docs/themes/<Dir>-source.zip
                             the theme's editable folder from themes_raw/,
                             for themes that have one there
    docs/themes/<Dir>.png    its preview image (builtin-<Dir>.png for a
                             built-in theme)
    docs/.nojekyll           so GitHub Pages serves the files as they are

docs/themes/ is rebuilt from scratch on every run. The zips are written with
fixed timestamps, so running this again without changing a theme leaves them
byte for byte the same and they don't show up as changes in git.

To publish: commit docs/ and, in the repo's Settings > Pages, deploy from a
branch with the folder set to /docs. Rerun this after packing themes.

Usage (Python 3.8+, standard library only):
    python3 build_theme_site.py
    python3 build_theme_site.py --out site --title "Songo Themes"
    python3 build_theme_site.py --help
"""

import argparse
import collections
import datetime
import html
import json
import shutil
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent

DEFAULT_TITLE = "Songo#5 Themes"
DEFAULT_INTRO = (
    "Themes for Songo #5, the music player for handhelds and desktops. "
    "Each one restyles the whole app: menus, lists, the now playing screen and more."
)
DEFAULT_REPO_URL = "https://github.com/Songo-Player/Songo-5"

# The files a packaged theme folder ships with. Anything else in the folder
# (e.g. Godot's preview.png.import) goes in the zip too, as packaged.
REQUIRED_FILES = ("theme.json", "theme.pck")

AI_USAGE_MAX = 5

# Zip entries get this timestamp so rebuilt zips are identical.
ZIP_DATE = (1980, 1, 1, 0, 0, 0)


# ---- Reading themes ----------------------------------------------------------

def strip_trailing_commas(text: str) -> str:
    """Drops commas before a closing } or ], which Godot's JSON parser accepts
    and Python's doesn't. Commas inside strings are left alone."""
    out = []
    in_string = False
    escaped = False
    i = 0
    while i < len(text):
        ch = text[i]
        if in_string:
            out.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
        elif ch == '"':
            in_string = True
            out.append(ch)
        elif ch == ",":
            j = i + 1
            while j < len(text) and text[j] in " \t\r\n":
                j += 1
            if j >= len(text) or text[j] not in "}]":
                out.append(ch)
        else:
            out.append(ch)
        i += 1
    return "".join(out)


def load_theme_json(path: Path) -> dict:
    text = path.read_text(encoding="utf-8-sig")
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        return json.loads(strip_trailing_commas(text))


def human_size(num_bytes: int) -> str:
    size = float(num_bytes)
    for unit in ("B", "KB", "MB", "GB"):
        if size < 1024 or unit == "GB":
            return f"{size:.0f} {unit}" if unit == "B" else f"{size:.1f} {unit}"
        size /= 1024
    return f"{num_bytes} B"


def as_list(value) -> list:
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return [str(v) for v in value if str(v).strip()]
    return [str(value)] if str(value).strip() else []


def read_theme(theme_dir: Path, required: tuple) -> "dict | None":
    """A theme folder's details from its theme.json, or None (with a note
    why) if it's missing a required file or the json can't be read."""
    missing = [name for name in required if not (theme_dir / name).is_file()]
    if missing:
        print(f"  skipping {theme_dir.name}: no {', '.join(missing)}", file=sys.stderr)
        return None
    try:
        meta = load_theme_json(theme_dir / "theme.json")
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        print(f"  skipping {theme_dir.name}: can't read theme.json ({error})", file=sys.stderr)
        return None

    ai_usage = meta.get("ai_usage")
    if not (isinstance(ai_usage, int) and not isinstance(ai_usage, bool) and 0 <= ai_usage <= AI_USAGE_MAX):
        ai_usage = None

    return {
        "dir": theme_dir,
        # The folder name is what the app installs and loads the theme by.
        "id": theme_dir.name,
        "name": str(meta.get("name") or theme_dir.name),
        "version": str(meta.get("version") or ""),
        "author": str(meta.get("author") or ""),
        "co_authors": as_list(meta.get("co_authors")),
        "ai_usage": ai_usage,
        "description": str(meta.get("description") or ""),
        "tags": as_list(meta.get("tags")),
        "has_preview": (theme_dir / "preview.png").is_file(),
    }


def collect_themes(packaged_dir: Path, raw_dir: Path) -> list:
    themes = []
    for theme_dir in sorted(p for p in packaged_dir.iterdir() if p.is_dir()):
        theme = read_theme(theme_dir, REQUIRED_FILES)
        if theme is None:
            continue
        theme["builtin"] = False
        # Names its preview and its card on the page.
        theme["slug"] = theme["id"]
        # The theme's editable folder, which the packer builds the package
        # from. Not every packaged theme has one here.
        source = raw_dir / theme_dir.name
        theme["source_dir"] = source if source.is_dir() else None
        themes.append(theme)
    return themes


def collect_builtin_themes(internal_dir: Path) -> list:
    """The themes shipped inside Songo itself. They're listed for show; there's
    nothing to download."""
    themes = []
    for theme_dir in sorted(p for p in internal_dir.iterdir() if p.is_dir()):
        theme = read_theme(theme_dir, ("theme.json",))
        if theme is None:
            continue
        theme["builtin"] = True
        theme["slug"] = f"builtin-{theme['id']}"
        theme["source_dir"] = None
        themes.append(theme)
    return themes


# ---- Writing the site ---------------------------------------------------------

def write_zip(folder: Path, root_name: str, zip_path: Path) -> int:
    """Zips `folder` as <root_name>/..., the layout it's used in once unzipped:
    a packaged theme goes into a themes folder as it is, and a source folder
    into themes_raw/. Returns the zip's size."""
    files = sorted(p for p in folder.rglob("*") if p.is_file())
    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in files:
            name = f"{root_name}/{path.relative_to(folder).as_posix()}"
            info = zipfile.ZipInfo(name, ZIP_DATE)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            archive.writestr(info, path.read_bytes(), compresslevel=9)
    return zip_path.stat().st_size


def esc(value) -> str:
    return html.escape(str(value), quote=True)


ICON_USER = ('<svg class="icon" viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="7.5" r="4.5"/>'
             '<path d="M3 21c0-4.4 4-7.5 9-7.5s9 3.1 9 7.5z"/></svg>')


def credited(theme: dict) -> list:
    """Everyone credited on a theme, author first, each name once."""
    names = []
    for name in [theme["author"]] + theme["co_authors"]:
        name = name.strip()
        if name and name not in names:
            names.append(name)
    return names


def render_card(theme: dict) -> str:
    by = theme["author"] or "Unknown"
    if theme["co_authors"]:
        by += " with " + ", ".join(theme["co_authors"])
    version = f'<span class="version">v{esc(theme["version"])}</span>' if theme["version"] else ""

    preview = (f'<img src="themes/{esc(theme["slug"])}.png" alt="{esc(theme["name"])} theme preview" '
               f'width="640" height="480" loading="lazy">'
               if theme["has_preview"] else '<div class="no-preview">No preview</div>')

    tags = "".join(f'<li>{esc(tag)}</li>' for tag in theme["tags"])
    tags_html = f'<ul class="tags" aria-label="Tags">{tags}</ul>' if tags else ""

    if theme["ai_usage"] is None:
        ai_html = '<p class="meta ai">AI usage not stated</p>'
    else:
        level = theme["ai_usage"]
        ai_html = (f'<p class="meta ai" title="How much AI was used to make this theme">'
                   f'AI usage {level} out of {AI_USAGE_MAX}</p>')

    description = f'<p class="desc">{esc(theme["description"])}</p>' if theme["description"] else ""

    if theme["builtin"]:
        # Ships with the app: nothing to download.
        downloads = '<p class="included">Included in Songo</p>'
    else:
        # A small label, then buttons side by side, as on Songo's settings pages.
        buttons = (f'<a class="download" href="themes/{esc(theme["id"])}.zip" download '
                   f'title="The packaged theme, ready to install">'
                   f'Theme <span class="size">{esc(theme["zip_size_text"])}</span></a>')
        if theme["source_dir"]:
            buttons += (f'<a class="download" href="themes/{esc(theme["id"])}-source.zip" download '
                        f'title="The theme\'s editable source folder">'
                        f'Source <span class="size">{esc(theme["source_size_text"])}</span></a>')
        downloads = (f'<section class="downloads" aria-label="Download {esc(theme["name"])}">'
                     f'<h3>Download</h3><div class="buttons">{buttons}</div></section>')
    # Read by the page's filters: tags (lower case, split on "|" so a tag can
    # have spaces) and the AI usage level, empty when it isn't stated.
    tag_attr = esc("|".join(t.lower() for t in theme["tags"]))
    ai_attr = "" if theme["ai_usage"] is None else str(theme["ai_usage"])
    authors_attr = esc("|".join(credited(theme)))

    return f"""
    <article class="card" id="{esc(theme["slug"])}" data-tags="{tag_attr}" data-ai="{ai_attr}" data-authors="{authors_attr}">
      <div class="shot">{preview}</div>
      <div class="body">
        <header>
          <h2>{esc(theme["name"])}</h2>{version}
        </header>
        <p class="meta">{ICON_USER}{esc(by)}</p>
        {ai_html}
        {description}
        {tags_html}
        {downloads}
      </div>
    </article>"""


FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com">'
         '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
         '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Courier+Prime:wght@700'
         '&family=Noto+Sans:wght@400;500;700&display=swap">')

# Songo Classic: a purple ground, near-black bars along the top and bottom,
# dark rounded panels, pill-shaped chips and a light ring on what's focused.
PAGE_CSS = """
:root {
  --ground: #562b90; --bar: #231c2d; --panel: rgb(35 28 45 / 0.92); --pill: #341a57;
  --text: #ffffff; --dim: #cfcbd6; --ring: #dcdcdc; --line: rgb(255 255 255 / 0.12);
  --mono: "Courier Prime", "Courier New", ui-monospace, monospace;
  --sans: "Noto Sans", system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
  color-scheme: dark;
}
* { box-sizing: border-box; }
html { background: var(--ground); }
body {
  margin: 0; min-height: 100vh; display: flex; flex-direction: column;
  background: var(--ground); color: var(--text); font: 16px/1.5 var(--sans);
}
.topbar, .bottombar {
  background: var(--bar); display: flex; align-items: center; justify-content: space-between;
  gap: 12px; padding: 10px max(16px, calc((100% - 1120px) / 2 + 20px));
}
.topbar { position: sticky; top: 0; z-index: 3; padding-top: calc(10px + env(safe-area-inset-top, 0px)); }
.brand { margin: 0; font-size: inherit; min-width: 0; }
.wordmark { font: 700 1.6rem/1 var(--mono); letter-spacing: 0.01em; color: var(--text); text-decoration: none; }
.topbar .count {
  background: var(--pill); border-radius: 999px; padding: 4px 14px; font-size: 0.9rem;
  white-space: nowrap; font-variant-numeric: tabular-nums;
}
.wrap { width: 100%; max-width: 1120px; margin: 0 auto; padding: 28px 20px 48px; flex: 1; }
[hidden] { display: none !important; }
/* Filters: a dark panel under the summary holding a tag search, the author
   and AI usage pickers (styled like the boxes on Songo's settings pages),
   the tags as pills, and a status line. It sticks under the top bar while
   the themes scroll past, a small gap below it; stuck, the tags fold to one row and the panel
   never grows past the screen. The page's script sets --topbar-h and
   --sticky-h to the bar's and the panel's heights. */
.filters {
  --sticky-gap: 8px;
  position: sticky; top: calc(var(--topbar-h, 50px) + var(--sticky-gap)); z-index: 2;
  background: rgb(35 28 45 / 0.97); border: 2px solid #ffffff; border-radius: 10px; padding: 14px 16px;
  margin: 0 0 22px;
  display: grid; gap: 12px;
}
.filters.stuck {
  box-shadow: 0 10px 24px rgb(0 0 0 / 0.35);
  max-height: calc(100vh - var(--topbar-h, 50px) - 2 * var(--sticky-gap)); overflow-y: auto; overscroll-behavior: contain;
}
.filters-sentinel { height: 1px; margin-bottom: -1px; }
.card { scroll-margin-top: calc(var(--sticky-h, 60px) + 24px); }
.filter-row { display: flex; flex-wrap: wrap; align-items: center; gap: 10px 16px; }
.field { display: flex; align-items: center; gap: 8px; color: var(--dim); font-size: 0.9rem; }
.field.search { flex: 1 1 240px; }
.field select { max-width: 14em; }
.field input, .field select, .clear {
  font: 400 0.95rem/1.3 var(--sans); color: #dfdfdf; background: #141414;
  border: 1px solid #cccccc; border-radius: 3px; padding: 6px 10px;
}
.field.search input { width: 100%; min-width: 0; }
.field input::placeholder { color: #8f8a96; }
.field select { cursor: pointer; }
.field input:focus-visible, .field select:focus-visible, .clear:focus-visible, .more:focus-visible {
  outline: 2px solid rgb(255 255 255 / 0.75); outline-offset: 1px;
}
.tag-list { display: flex; flex-wrap: wrap; gap: 8px; }
.tag-list.collapsed { max-height: 76px; overflow: hidden; }
.filters.stuck .tag-list.collapsed { max-height: 34px; }
/* Phones: the dropdowns' first options say what they are, so their labels
   are left to screen readers and the two sit side by side. */
@media (max-width: 559px) {
  .filter-row { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
  .field.search { grid-column: 1 / -1; }
  .field .label {
    position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); white-space: nowrap;
  }
  .field select { width: 100%; max-width: none; }
  .field { min-width: 0; }
}
.tag-list button {
  height: 34px; padding: 0 14px; border-radius: 999px; cursor: pointer;
  font: 500 0.9rem/1 var(--sans); background: var(--pill); color: var(--text); border: 2px solid transparent;
}
.tag-list button .n { color: var(--dim); font-size: 0.8rem; margin-left: 6px; font-variant-numeric: tabular-nums; }
.tag-list button[aria-pressed="true"] { border-color: var(--ring); }
.tag-list button:hover { background: #432470; }
.tag-list button:focus-visible { outline: none; border-color: var(--ring); }
.filter-foot { display: flex; flex-wrap: wrap; align-items: center; gap: 8px 16px; min-height: 34px; }
.more {
  background: none; border: 0; padding: 4px 0; color: var(--text); cursor: pointer;
  font: 500 0.9rem var(--sans); text-decoration: underline; text-underline-offset: 3px;
}
.status { margin: 0; color: var(--dim); font-size: 0.9rem; flex: 1; }
.clear { cursor: pointer; padding: 5px 12px; font-size: 0.9rem; }
.clear:hover { background: #262626; }
.no-tags { margin: 0; color: var(--dim); font-size: 0.9rem; }
.empty { background: var(--panel); border-radius: 10px; padding: 28px 20px; text-align: center; color: var(--dim); }
.grid { display: grid; gap: 20px; grid-template-columns: repeat(auto-fill, minmax(min(100%, 330px), 1fr)); }
.card {
  background: var(--panel); border-radius: 10px; padding: 12px; display: flex; flex-direction: column;
  border: 2px solid transparent;
}
.card:focus-within { border-color: var(--ring); }
.card[hidden] { display: none; }
.shot { aspect-ratio: 4 / 3; border-radius: 6px; overflow: hidden; background: #000; }
.shot img { display: block; width: 100%; height: 100%; object-fit: cover; }
.no-preview { height: 100%; display: grid; place-items: center; color: var(--dim); }
.body { padding: 14px 6px 2px; display: flex; flex-direction: column; gap: 8px; flex: 1; }
.body header { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.body h2 { margin: 0; font-size: 1.45rem; font-weight: 500; line-height: 1.2; }
.version {
  background: var(--pill); border-radius: 999px; padding: 1px 10px; font-size: 0.8rem;
  color: var(--dim); font-variant-numeric: tabular-nums;
}
.meta { margin: 0; display: flex; align-items: center; gap: 8px; color: var(--dim); font-size: 0.95rem; }
.icon { width: 18px; height: 18px; fill: currentColor; flex: none; }
.desc { margin: 2px 0 0; }
.tags { display: flex; flex-wrap: wrap; gap: 6px; list-style: none; margin: 2px 0 0; padding: 0; }
.tags li { background: var(--pill); border-radius: 999px; padding: 3px 12px; font-size: 0.8rem; color: var(--dim); }
/* A small label over buttons like those on Songo's settings pages (e.g.
   Data and Storage): near-black boxes with a thin light grey outline and
   centred text. */
.downloads { margin-top: auto; padding-top: 6px; }
.downloads h3 { margin: 0 0 8px; font-size: 0.85rem; font-weight: 500; color: #ffffff; }
/* A built-in theme's note, in the #212121 panel of a Songo settings section,
   across the card's full width. */
.included {
  margin: auto 0 0; align-self: stretch; background: #212121; border-radius: 4px;
  padding: 10px 12px; font-size: 0.85rem; font-weight: 500; color: #ffffff;
}
.downloads .buttons { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.download {
  display: flex; align-items: baseline; justify-content: center; gap: 6px; flex-wrap: wrap;
  padding: 7px 10px; border-radius: 3px; border: 1px solid #cccccc;
  background: #141414; color: #dfdfdf; text-decoration: none; font: 400 1rem/1.3 var(--sans);
}
.download .size { color: #9a9a9a; font-size: 0.8rem; font-variant-numeric: tabular-nums; white-space: nowrap; }
.download:hover { background: #262626; color: #f2f2f2; }
.download:active { background: #000000; color: #ffffff; }
.download:focus-visible { outline: 2px solid rgb(255 255 255 / 0.75); outline-offset: 1px; }
.install { margin-top: 36px; background: var(--panel); border-radius: 10px; padding: 20px 24px; }
.install h2 { margin: 0 0 10px; font-size: 1.25rem; font-weight: 500; }
.install ol { margin: 0; padding-left: 1.3em; display: grid; gap: 8px; color: var(--dim); }
.install li::marker { color: var(--text); }
.install .note { margin: 14px 0 0; color: var(--dim); }
.install code {
  background: var(--pill); color: var(--text); border-radius: 5px; padding: 1px 7px;
  font: 700 0.9em var(--mono); overflow-wrap: anywhere;
}
.bottombar {
  font-size: 0.95rem; color: var(--text); flex-wrap: wrap;
  padding-bottom: calc(10px + env(safe-area-inset-bottom, 0px));
}
.bottombar .crumbs { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.bottombar a { color: inherit; }
.bottombar .built { color: var(--dim); font-variant-numeric: tabular-nums; }
@media (max-width: 480px) { .wordmark { font-size: 1.35rem; } }
"""

# Filters: optional, the page shows every theme without scripts. A theme is
# shown when it has every selected tag, credits the picked author, and, if an
# AI usage level is picked, states a level no higher than it. The choice is
# kept in the URL's hash (#tags=dark,retro&author=Riley&ai=2) so a filtered
# view can be linked.
PAGE_JS = """
(function () {
  var panel = document.getElementById('filters');
  if (!panel) return;
  panel.hidden = false;
  var root = document.documentElement;
  var topbar = document.querySelector('.topbar');
  var sentinel = document.getElementById('filters-sentinel');
  var grid = document.querySelector('.grid');
  var cards = Array.prototype.slice.call(document.querySelectorAll('.card'));
  var tagList = document.getElementById('tag-list');
  var tagButtons = Array.prototype.slice.call(tagList.querySelectorAll('button'));
  var search = document.getElementById('tag-search');
  var author = document.getElementById('author-filter');
  var ai = document.getElementById('ai-filter');
  var clear = document.getElementById('clear-filters');
  var more = document.getElementById('more-tags');
  var status = document.getElementById('filter-status');
  var noTags = document.getElementById('no-tag-matches');
  var empty = document.getElementById('no-matches');
  var foot = panel.querySelector('.filter-foot');
  var selected = [];
  var expanded = false;
  // The space between the top bar and the stuck panel (--sticky-gap in the CSS).
  var gap = parseFloat(getComputedStyle(panel).getPropertyValue('--sticky-gap')) || 0;

  function split(value) { return value ? value.split('|') : []; }
  function isSelected(tag) { return selected.indexOf(tag) !== -1; }
  function hasOption(select, value) {
    return Array.prototype.some.call(select.options, function (o) { return o.value === value; });
  }

  // Heights the CSS needs: where the panel sticks, and how far down a card
  // has to land to clear it.
  function measure() {
    root.style.setProperty('--topbar-h', topbar.offsetHeight + 'px');
    root.style.setProperty('--sticky-h', (topbar.offsetHeight + panel.offsetHeight) + 'px');
  }

  // The row under the tags only takes space when something in it is showing.
  function updateFoot() { foot.hidden = more.hidden && clear.hidden && !status.textContent; }

  function apply(userChange) {
    var max = ai.value === '' ? null : Number(ai.value);
    var person = author.value;
    var shown = 0;
    cards.forEach(function (card) {
      var tags = split(card.dataset.tags);
      var match = selected.every(function (tag) { return tags.indexOf(tag) !== -1; });
      if (match && person !== '') match = split(card.dataset.authors).indexOf(person) !== -1;
      if (match && max !== null) match = card.dataset.ai !== '' && Number(card.dataset.ai) <= max;
      card.hidden = !match;
      if (match) shown++;
    });
    // Selected tags move to the front so they stay in view when the list is folded.
    tagButtons.forEach(function (button) { button.setAttribute('aria-pressed', isSelected(button.dataset.tag)); });
    tagButtons.slice().sort(function (a, b) {
      return (isSelected(b.dataset.tag) - isSelected(a.dataset.tag)) || (a.dataset.order - b.dataset.order);
    }).forEach(function (button) { tagList.appendChild(button); });
    var filtering = selected.length > 0 || person !== '' || max !== null;
    clear.hidden = !filtering;
    status.textContent = filtering ? 'Showing ' + shown + ' of ' + cards.length + ' themes' : '';
    empty.hidden = shown > 0;
    updateFoot();
    if (userChange) {
      writeHash();
      // Scrolled down into the themes, the results start again just under the panel.
      measure();
      var offset = topbar.offsetHeight + gap + panel.offsetHeight + 16;
      var top = grid.getBoundingClientRect().top;
      if (top < offset) window.scrollTo(0, window.scrollY + top - offset);
    }
  }

  function showTags() {
    var query = search.value.trim().toLowerCase();
    var visible = 0;
    tagButtons.forEach(function (button) {
      var match = query === '' || button.dataset.tag.indexOf(query) !== -1;
      button.hidden = !match;
      if (match) visible++;
    });
    noTags.hidden = visible > 0 || tagButtons.length === 0;
    // Searching shows every match; otherwise fold (to two rows, or one while
    // stuck) unless expanded.
    if (query !== '') {
      tagList.classList.remove('collapsed');
      more.hidden = true;
    } else {
      tagList.classList.add('collapsed');
      var overflows = tagList.scrollHeight > tagList.clientHeight + 1;
      tagList.classList.toggle('collapsed', !expanded);
      more.hidden = !overflows;
      more.textContent = expanded ? 'Show fewer tags' : 'Show all ' + tagButtons.length + ' tags';
      more.setAttribute('aria-expanded', expanded);
    }
    updateFoot();
    measure();
  }

  function writeHash() {
    var parts = [];
    if (selected.length) parts.push('tags=' + selected.map(encodeURIComponent).join(','));
    if (author.value !== '') parts.push('author=' + encodeURIComponent(author.value));
    if (ai.value !== '') parts.push('ai=' + ai.value);
    try {
      history.replaceState(null, '', parts.length ? '#' + parts.join('&') : location.pathname + location.search);
    } catch (e) {}
  }

  function readHash() {
    var hash = location.hash.slice(1);
    if (hash.indexOf('=') === -1) return;  // e.g. a link straight to a theme's card
    hash.split('&').forEach(function (part) {
      var at = part.indexOf('=');
      var key = part.slice(0, at), value = part.slice(at + 1);
      if (key === 'tags' && value) {
        value.split(',').forEach(function (tag) {
          tag = decodeURIComponent(tag).toLowerCase();
          var known = tagButtons.some(function (b) { return b.dataset.tag === tag; });
          if (known && !isSelected(tag)) selected.push(tag);
        });
      } else if (key === 'author') {
        var name = decodeURIComponent(value);
        if (hasOption(author, name)) author.value = name;
      } else if (key === 'ai' && hasOption(ai, value)) {
        ai.value = value;
      }
    });
  }

  function toggle(tag) {
    if (isSelected(tag)) selected.splice(selected.indexOf(tag), 1);
    else selected.push(tag);
    showTags();
    apply(true);
  }

  tagList.addEventListener('click', function (event) {
    var button = event.target.closest('button');
    if (button) toggle(button.dataset.tag);
  });
  search.addEventListener('input', showTags);
  // Enter picks the tag when the search narrows the list to just one.
  search.addEventListener('keydown', function (event) {
    if (event.key !== 'Enter') return;
    var matches = tagButtons.filter(function (b) { return !b.hidden; });
    if (matches.length === 1) {
      event.preventDefault();
      search.value = '';
      toggle(matches[0].dataset.tag);
    }
  });
  author.addEventListener('change', function () { apply(true); });
  ai.addEventListener('change', function () { apply(true); });
  clear.addEventListener('click', function () {
    selected = [];
    author.value = '';
    ai.value = '';
    search.value = '';
    showTags();
    apply(true);
  });
  more.addEventListener('click', function () { expanded = !expanded; showTags(); });
  window.addEventListener('resize', showTags);

  // Stuck once the spot just above the panel has scrolled up past where the
  // panel sticks. Checked on every scroll: it's one position read, and the
  // tag list is only refolded when the state actually changes.
  function checkStuck() {
    var stuck = sentinel.getBoundingClientRect().top < topbar.offsetHeight + gap;
    if (stuck !== panel.classList.contains('stuck')) {
      panel.classList.toggle('stuck', stuck);
      showTags();
    }
  }
  window.addEventListener('scroll', checkStuck, { passive: true });
  window.addEventListener('resize', checkStuck);

  readHash();
  apply(false);
  showTags();
  checkStuck();
})();
"""


def render_filters(themes: list) -> str:
    """The filter panel. It starts hidden; the page's script shows it."""
    # Most used tags and most credited people first.
    counts = collections.Counter(tag for t in themes for tag in {x.lower() for x in t["tags"]})
    tags = sorted(counts, key=lambda tag: (-counts[tag], tag))
    tag_buttons = "".join(
        f'<button type="button" data-tag="{esc(tag)}" data-order="{order}" aria-pressed="false">'
        f'{esc(tag)}<span class="n">{counts[tag]}</span></button>'
        for order, tag in enumerate(tags))

    people = collections.Counter(name for t in themes for name in credited(t))
    names = sorted(people, key=lambda name: (-people[name], name.lower()))
    author_options = '<option value="">Any author</option>' + "".join(
        f'<option value="{esc(name)}">{esc(name)} ({people[name]})</option>' for name in names)

    ai_options = '<option value="">Any AI usage</option><option value="0">None (0 of 5)</option>' + "".join(
        f'<option value="{level}">Up to {level} of {AI_USAGE_MAX}</option>' for level in range(1, AI_USAGE_MAX))

    search = ("""<label class="field search"><span class="label">Tags</span>
        <input type="search" id="tag-search" placeholder="Find a tag" autocomplete="off" spellcheck="false"
          aria-controls="tag-list">
      </label>""" if tags else '<input type="search" id="tag-search" hidden>')
    return f"""<div class="filters-sentinel" id="filters-sentinel" aria-hidden="true"></div>
  <section class="filters" id="filters" aria-label="Filter themes" hidden>
    <div class="filter-row">
      {search}
      <label class="field"><span class="label">Author</span> <select id="author-filter">{author_options}</select></label>
      <label class="field"><span class="label">AI usage</span> <select id="ai-filter">{ai_options}</select></label>
    </div>
    <div class="tag-list collapsed" id="tag-list" role="group" aria-label="Tags"{"" if tags else " hidden"}>{tag_buttons}</div>
    <p class="no-tags" id="no-tag-matches" hidden>No tags match.</p>
    <div class="filter-foot">
      <button type="button" class="more" id="more-tags" aria-controls="tag-list" hidden></button>
      <p class="status" id="filter-status" aria-live="polite"></p>
      <button type="button" class="clear" id="clear-filters" hidden>Clear filters</button>
    </div>
  </section>"""


def render_page(themes: list, title: str, intro: str, repo_url: str) -> str:
    cards = "".join(render_card(t) for t in themes)
    filters = render_filters(themes)
    # The page's title, in the top bar like the app's own header. It links to
    # Songo itself.
    wordmark = (f'<h1 class="brand"><a class="wordmark" href="{esc(repo_url)}">{esc(title)}</a></h1>' if repo_url
                else f'<h1 class="brand"><span class="wordmark">{esc(title)}</span></h1>')
    count = len(themes)
    plural = "s" if count != 1 else ""
    built = datetime.date.today().isoformat()

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#231c2d">
<title>{esc(title)}</title>
<meta name="description" content="{esc(intro)}">
{FONTS}
<style>{PAGE_CSS}</style>
</head>
<body>
<header class="topbar">
  {wordmark}
  <span class="count">{count} theme{plural}</span>
</header>
<main class="wrap">
  {filters}
  <section class="grid" aria-label="{count} theme{plural}">{cards}
  </section>
  <p class="empty" id="no-matches" hidden>No themes match these filters.</p>
  <section class="install" id="install">
    <h2>Installing a theme</h2>
    <ol>
      <li>Download a theme and unzip it. You get one folder named after the theme; keep it as it is.</li>
      <li>Put that folder in a <code>songo_themes</code> folder next to Songo, or up to three folders above it.
        On PortMaster that's <code>ports/songo5/songo_themes/</code>.</li>
      <li>Or put it in Songo's <code>external_themes</code> folder:
        <code>~/.local/share/godot/app_userdata/Songo #5/external_themes/</code> on Linux,
        <code>%APPDATA%\\Godot\\app_userdata\\Songo #5\\external_themes\\</code> on Windows.</li>
      <li>Open Songo, go to Settings, then UI and Customization, and pick the theme.</li>
    </ol>
    <p class="note">The source download is the theme's editable folder. To change a theme, unzip it into
      <code>theme_dev/themes_raw/</code> in a Songo-5 checkout and open the project in the Godot editor.</p>
  </section>
</main>
<footer class="bottombar">
  <span class="crumbs">Main Menu &gt; Themes</span>
  <span class="built">Built {built} &middot; <a href="themes.json">themes.json</a></span>
</footer>
<script>{PAGE_JS}</script>
</body>
</html>
"""


def manifest_entry(theme: dict) -> dict:
    return {
        "id": theme["id"],
        "name": theme["name"],
        "version": theme["version"],
        "author": theme["author"],
        "co_authors": theme["co_authors"],
        "ai_usage": theme["ai_usage"],
        "description": theme["description"],
        "tags": theme["tags"],
        "builtin": theme["builtin"],
        "download": None if theme["builtin"] else f"themes/{theme['id']}.zip",
        "download_bytes": theme.get("zip_size"),
        "source": f"themes/{theme['id']}-source.zip" if theme["source_dir"] else None,
        "source_bytes": theme.get("source_size"),
        "preview": f"themes/{theme['slug']}.png" if theme["has_preview"] else None,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Builds the theme info and download page.")
    parser.add_argument("--packaged", type=Path, default=HERE / "themes_packaged",
                        help="folder of packaged themes (default: themes_packaged next to this script)")
    parser.add_argument("--raw", type=Path, default=HERE / "themes_raw",
                        help="folder of theme sources, zipped for the source downloads "
                             "(default: themes_raw next to this script)")
    parser.add_argument("--internal", type=Path, default=HERE.parent / "internal_themes",
                        help="Songo's built-in themes, listed without downloads "
                             "(default: ../internal_themes, there when theme_dev is inside Songo-5)")
    parser.add_argument("--out", type=Path, default=HERE / "docs",
                        help="where to write the site (default: docs next to this script)")
    parser.add_argument("--title", default=DEFAULT_TITLE, help="page title, shown in the top bar")
    parser.add_argument("--intro", default=DEFAULT_INTRO,
                        help="the page's description, for search engines and link previews")
    parser.add_argument("--repo-url", default=DEFAULT_REPO_URL,
                        help="where the title in the top bar links to (Songo itself); empty for no link")
    args = parser.parse_args()

    packaged = args.packaged.resolve()
    out = args.out.resolve()
    if not packaged.is_dir():
        print(f"No packaged themes folder at {packaged}", file=sys.stderr)
        return 1
    if out == packaged or packaged in out.parents:
        print("--out can't be inside the packaged themes folder", file=sys.stderr)
        return 1

    builtin = []
    internal = args.internal.resolve()
    if internal.is_dir():
        print(f"Reading built-in themes from {internal}")
        builtin = collect_builtin_themes(internal)
    else:
        print(f"  no built-in themes folder at {internal}, leaving them out", file=sys.stderr)

    print(f"Reading themes from {packaged}")
    # Built-in themes first: they're what everyone already has.
    themes = builtin + collect_themes(packaged, args.raw.resolve())
    if not themes:
        print("No themes found", file=sys.stderr)
        return 1

    # docs/themes/ only ever holds what this script writes, so it's rebuilt
    # from scratch and a removed theme doesn't linger.
    assets = out / "themes"
    if assets.exists():
        shutil.rmtree(assets)
    assets.mkdir(parents=True)

    for theme in themes:
        if theme["has_preview"]:
            shutil.copyfile(theme["dir"] / "preview.png", assets / f"{theme['slug']}.png")
        if theme["builtin"]:
            print(f"  {theme['id']}: {theme['name']} {theme['version']} (built in)")
            continue
        theme["zip_size"] = write_zip(theme["dir"], theme["id"], assets / f"{theme['id']}.zip")
        theme["zip_size_text"] = human_size(theme["zip_size"])
        if theme["source_dir"]:
            theme["source_size"] = write_zip(theme["source_dir"], theme["id"], assets / f"{theme['id']}-source.zip")
            theme["source_size_text"] = human_size(theme["source_size"])
        source = f", source {theme['source_size_text']}" if theme["source_dir"] else ", no source"
        print(f"  {theme['id']}: {theme['name']} {theme['version']} ({theme['zip_size_text']}{source})")

    (out / "index.html").write_text(render_page(themes, args.title, args.intro, args.repo_url), encoding="utf-8")
    (out / "themes.json").write_text(json.dumps({"themes": [manifest_entry(t) for t in themes]},
                                                indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (out / ".nojekyll").write_text("", encoding="utf-8")
    print(f"Wrote {out / 'index.html'} with {len(themes)} theme{'s' if len(themes) != 1 else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
