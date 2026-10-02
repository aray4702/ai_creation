---
name: task-progress
description: >-
  Answer progress questions about the ai_creation repo's tasks from the repo itself: overall status
  (how many tasks are not started, in progress, done but unpublished, published),
  what was completed in a period with its time, tokens and cost, and which not-started tasks are
  ready to pick up next (no blockers, pairs kept together). Use this whenever the user asks "what's
  the status", "where are we", "what's left", "what got done today/this week", "list completed
  tasks", "which tasks have no dependencies", "what can I start next", "what's in flight", or wants
  numbers on progress, even if they don't say "progress" and even when .agents/QUEUE.md seems to
  have the answer — the queue file goes stale, the folders don't.
---

# Task progress

This repo moves each task through stages, and every stage leaves a footprint in the file tree:

| Stage | Where it shows |
|---|---|
| not started | a spec `.md` in `.tasks/<category>/` with nothing beside it |
| in progress | an output (`.html` or a folder) next to its spec in `.tasks/` |
| completed (unpublished) | `.completed_tasks/<slug>/` exists, but no card in `index.html` |
| published | a card in `index.html` on the local `dev` branch |

Publishing happens on `dev`, so the scanner reads `dev:index.html` and ignores `main` and
`origin/main`: those only catch up when a PR merges, and the local refs are often stale.

`.agents/QUEUE.md` is a hand-kept summary of the same thing, and it drifts. Treat it as a hint
about intent (who claimed what, known blockers) but answer from the tree. **Don't edit QUEUE.md**:
the user wants this skill to be read-only. If it disagrees with what you found, say so in one line
so the user can fix it.

## Gather the facts

Run the scanner from the repo root; it does the folder, git and transcript work in about a second:

```bash
python3 .claude/skills/task-progress/scripts/scan_progress.py                 # counts + lists by stage
python3 .claude/skills/task-progress/scripts/scan_progress.py --since 2026-10-01 [--until 2026-10-02]
python3 .claude/skills/task-progress/scripts/scan_progress.py --ready         # what can start next
python3 .claude/skills/task-progress/scripts/scan_progress.py --json          # everything, for follow-ups
```

How it decides the trickier things, so you can judge its output:

- **Completion date** is the last time Claude edited the task's output before it was filed (read
  from the Claude Code transcripts), shared across tasks finished in one run. Bulk filing scripts
  and moves don't count. Work Claude never edited falls back to the filing commit and is marked
  `(filed)`; `(run)` means the date came from a partner task in the same run. When a date looks
  wrong, say what it's based on rather than presenting it as certain.
- **Stats** (active minutes, tokens) come from the task's card in `index.html`, which is what was
  published. Tasks that share a run show the same figures; count each run once in any total.
- **Blockers** are keyword heuristics on the spec (Blender, Godot, Unity, Tinkercad, Xcode/iOS,
  live screen control, needs an input image). Read the spec before calling something blocked or
  ready. An "Execution note" can lift a blocker (e.g. "Blender is not installed: generate
  procedurally"), and an app where the user draws or uploads in the page is not blocked.
- **Pairs** are specs that share distinctive words, such as EN/CN twins or an explainer and its lab.
  Recommend starting them together, since one run builds both and keeps them consistent.

If the user asks about something the scanner doesn't cover (a single task's history, who is
working on what right now), look directly: `git log -- <path>`, recent files in `.agents/shots/`,
`gh pr list`.

## Answering

Lead with the answer, then the detail. Match the question:

- **Status:** one line of counts by stage, then short lists for the stages that need attention
  (in progress, completed but unpublished). Mention open PRs the scanner lists.
- **Completed in a period:** a table with task, stage, completion date, who built it, active time
  and tokens. Give a total that counts shared runs once. If the user wants cost, get current
  per-token prices from the claude-api skill rather than memory, and say which prices you used.
- **What's next:** the ready tasks first (pairs grouped), then the blocked ones with the reason,
  so the user can unblock them if they want (e.g. provide the input image).

Keep to what you checked. If a number comes from a heuristic, or something couldn't be determined,
say so briefly rather than smoothing it over.
