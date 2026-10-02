---
name: publish-completed-tasks
description: >-
  Publish finished tasks in the ai_creation repo: file each task into .completed_tasks/<slug>/
  (spec, outputs, one screenshot), build its public top-level folder with a cleaned-up brief,
  work out active time and tokens from the Claude Code transcripts, add cards to index.html and
  sections to README.md, commit on dev, and open a pull request to main that carries only the
  published files. Use this whenever the user wants to publish, release, ship, file, "move to
  completed", put on the site, or open the PR for tasks in ai_creation, or asks to update
  index.html / README with newly finished tasks, even if they only say "publish them" or
  "move today's tasks to completed_tasks".
---

# Publish completed tasks

This repo is a gallery of AI-built deliverables. Specs and work in progress live in `.tasks/<category>/`;
finished work is kept as a record in `.completed_tasks/<slug>/`; the public site (GitHub Pages from
`main`) shows a top-level `<slug>/` folder per task, listed in `index.html` and `README.md` with the
time and tokens it took. Publishing moves tasks through all three places and ends with a pull
request for the user to merge.

Read `references/conventions.md` once before starting. It has the manifest format, the credit and
stats rules, and the exact shape of cards and README sections.

## Before you start

1. **Confirm which tasks.** Default to the "Verified — awaiting publish" list in `.agents/QUEUE.md`,
   or what the user named. Publish only tasks that were actually checked: their output loads
   without errors and a screenshot was reviewed. If something on the list hasn't been verified,
   say so instead of publishing it quietly.
2. **Check the tree.** `git status` and `git branch --show-current`. Work on `dev`. Unrelated
   uncommitted changes should be raised with the user, not swept into the commit.

## Steps

### 1. Gather each task's pieces and stats

For every task, find:
- the spec (`.tasks/<category>/<name>.md`), the output file(s) or folder, and the best screenshot
  (`.agents/shots/` usually has several; pick the one that shows the piece at its best, not a title
  screen or a frame where the camera is clipping);
- who built it, and in which session and time window.

Get the time windows from the transcripts rather than guessing:

```bash
python3 .claude/skills/publish-completed-tasks/scripts/transcript_stats.py messages --date YYYY-MM-DD
```

**What counts (the user's rule):** only the session window that *finished* the task, from the first
message where work on this task begins to the message that turns to something else. Leave out:
- planning or hand-off chat for *other* tasks, even when it sits just before this task in the
  same session (picking tasks for another agent, writing their prompts);
- earlier build attempts in other sessions (e.g. a subagent that built a first version days before
  and hit a limit). Mention them in the task's `note` if they matter, but don't add them to the figures;
- overhead such as usage reports, listings, memory or queue housekeeping.

So read the messages around each boundary, not just the first one that names the task. If a session
interleaves several tasks, give one task several windows (repeat its label). Then measure every window
at once:

```bash
python3 .claude/skills/publish-completed-tasks/scripts/transcript_stats.py stats --date YYYY-MM-DD \
  fox=d95ba9e1@15:12:30-15:46:39 moai=d95ba9e1@15:46:39-16:53:27 music=5d159eb1 --json /tmp/stats.json
```

Tasks done in one run (an EN/CN pair, a batch finished together) share one window; record it once
and mark the tasks as `shared` (pairs) or one `group` (3+). Leave out pure overhead like usage
reports. If a screenshot is missing (native apps, say), make one: native apps in this repo have an
`--autotest --snapshot=<dir>` hook; web pages use `.agents/check.sh`.

### 2. Write the manifest and the cleaned-up briefs

Write a manifest JSON (format in `references/conventions.md`) to the scratchpad, and one cleaned-up
brief per task. The published brief keeps the original filename and language but reads as a clear,
well-structured spec: fix typos, turn run-on requirements into short headed sections, keep every
requirement and any delivery note. The original stays untouched in `.completed_tasks/` as the record.

### 3. File the tasks

```bash
python3 .claude/skills/publish-completed-tasks/scripts/file_tasks.py manifest.json --dry-run
python3 .claude/skills/publish-completed-tasks/scripts/file_tasks.py manifest.json
```

It validates everything before moving anything, drops build caches, and copies the screenshot in as
`<output-name>.png`.

### 4. Build the site entries

```bash
python3 .claude/skills/publish-completed-tasks/scripts/publish_site.py manifest.json
```

This creates the top-level folders, appends the cards to `index.html`, adds README contents entries,
sections and breakdown rows, recomputes the totals and the "N builds" count, and ends by checking
every link. Fix anything it reports as broken before moving on.

Then look at the result: render the page and read the new cards.

```bash
.agents/check.sh "$PWD/index.html" "$PWD/.agents/shots/pub-index.png" "" 1280 7400 5
```

Also update `.agents/QUEUE.md`: move the tasks to Done, adjust the counts, add a status-log line.

### 5. Commit on dev

Stage everything (`git add -A`), check that nothing large or generated slipped in (build folders,
caches), and commit with a message listing the tasks.

### 6. Pull request with only the published files

The user reviews before anything reaches `main`, and the record folders stay off the public branch.

First check whether an earlier publish is still waiting: `gh pr list --state open` (or, offline,
look for `publish-*` branches not merged into `main`). That decides the base:

- **No open publish PR:** branch from `main`.
- **An open publish PR exists:** branch from *its* branch and target the PR at it. `index.html` and
  `README.md` on `dev` list everything, so a branch from `main` would carry the earlier batch's
  folders too (a confusing duplicate PR), and one without them would ship broken links. Stacking keeps
  this PR to just the new tasks; say in the PR body that it should merge after the earlier one.

```bash
git switch -c publish-YYYY-MM-DD <main or the open publish branch>
git checkout dev -- README.md index.html <each new slug folder>
git diff --cached --name-only | grep -E '^\.(completed_tasks|tasks)/|^\.gitignore' || echo clean
git commit -m "Publish N tasks completed on YYYY-MM-DD"
```

If the new tasks *replace* entries that the open PR already carries (a re-publish), ask the user
whether to update that PR instead of opening another.

**Ask the user before pushing**: pushing and opening a PR are visible to others. Once they agree:
`git push -u origin publish-YYYY-MM-DD`, then `gh pr create --base <main or the open publish branch>` with a body that lists the
tasks by builder, notes how the stats were measured, and states anything that couldn't be checked
(such as audio). Never merge into `main` yourself, and switch back to `dev` afterwards.

## When something looks wrong

You will sometimes notice problems in what's already published (a wrong figure, a mismatched pair
name, an odd screenshot). Verify before reporting: open the image, re-run the numbers. If it holds up,
fix it in the same commit and call it out; if it doesn't, drop it. An unverified "the screenshots are
swapped" costs the user more time than it saves.

## Report back

Say what was filed and published (a short table is fine), the new totals, the PR link, and anything
unverified. Keep caveats honest: if a soundtrack couldn't be heard or a stat is partial, say so.
