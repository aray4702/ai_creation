# ai_creation publishing conventions

## Where things live

| Place | Contents | On `main`? |
|---|---|---|
| `.tasks/<category>/` | specs not yet done, work in progress | no |
| `.completed_tasks/<slug>/` | the record: original spec, outputs, one screenshot | no |
| `<slug>/` (repo root) | published copy: cleaned-up brief (original filename), outputs, screenshot | yes |
| `index.html`, `README.md` | the gallery listing every published task | yes |
| `.agents/` | queue, check script, screenshots (gitignored) | no |

`<slug>` is normally the output's basename (`fox-lantern-adventure`). Screenshots are named after the
first output (`fox-lantern-adventure.png`); folders such as Swift packages use an explicit `shot`.

## Manifest (one file drives file_tasks.py and publish_site.py)

```json
{
  "source_range": "28 Sep – 2 Oct 2026",
  "tasks": [
    {
      "slug": "fox-lantern-adventure",
      "spec": ".tasks/game/3d fox action game.md",
      "outputs": [".tasks/game/fox-lantern-adventure.html"],
      "screenshot": ".agents/shots/fox-3.png",
      "brief": "/path/to/scratch/briefs/fox.md",
      "cat": "Game",
      "title": "Fox Lantern Adventure: 3D Action Platformer",
      "desc": "One or two sentences on what it is and what you can do with it.",
      "by": "Main session",
      "links": [["fox-lantern-adventure.html", "Play Fox Lantern"]],
      "stats": {"min": 31.8, "in": 52, "cw": 84404, "cr": 1908960, "out": 23445}
    }
  ]
}
```

- `outputs` may include folders (a Swift package); build caches are dropped when filing.
- `links` are what the card's buttons open. For something a browser can't run, link to the GitHub
  tree, e.g. `https://github.com/aray4702/ai_creation/tree/main/music-player/music-player`, and set
  `"shot": "music-player.png"`.
- `stats` come straight from `transcript_stats.py` (`min`, `in`, `cw`, `cr`, `out`).

## Credit and stats rules

- **by**: `Main session` (built in the user's session), `Subagent` (built by a spawned subagent),
  or `<Agent> · finished by Claude` when another agent (Codex, Muse, …) built the first version.
- **Pairs** built in one run (e.g. EN + CN versions): give both the same stats and set
  `shared` to the other task's title. They are counted once in the totals and marked `*`.
- **Groups** of 3+ finished in one run: same stats, same `group` key, and a `note` that says what
  the figures cover. For outside agents, the note must say the figures are Claude's finishing run only
  and that the other agent's usage isn't recorded. Groups are counted once and marked `†`.
- **Which work counts:** only the session window that finished the task. Planning for other tasks,
  earlier build attempts in other sessions, and housekeeping stay out of the figures (an earlier
  attempt can be mentioned in the card's `note`). The same rule applies to tasks a subagent finished:
  measure that subagent's transcript (they live in `<session>/subagents/`).
- **Active time** excludes gaps over 20 minutes; **total tokens** are input, cache writes, cache
  reads and output added together.
- Never invent numbers. If a window can't be found, ask the user or leave the task out.

## Cleaned-up brief style

Keep the original filename, language and every requirement. Fix typos, give it a plain title, a
one-line summary, then short headed sections with bullets. Keep execution/delivery notes. Example:
the original "Develop a complete single-prompt 3D arcade kart racer in a single HTML file…" became
"# Arcade Kart Racer" / "A complete 3D kart racing game in one HTML file, built with Three.js/WebGL."

## What publish_site.py writes

- **index.html**: one `TASKS` entry per task (`dir, cat, title, desc, md, outputs, [shot], [shared],
  [group, note], min, in, cw, cr, out, by`); the header's "N builds" word; the footer date range.
- **README.md**: contents line `N. [Title](#N-slug)`, a section per task (anchor, title, category ·
  credit, linked screenshot, description, stats table, output and brief links), breakdown rows, and the
  totals row `| **N** | **time** | **output** | **total** |`.

Run `publish_site.py --check` any time to validate every link in both files.
