#!/usr/bin/env python3
"""Where every ai_creation task stands, read from the repo itself (not from .agents/QUEUE.md).

  scan_progress.py              # summary by stage
  scan_progress.py --json       # everything, machine-readable
  scan_progress.py --since 2026-10-01 [--until 2026-10-02]   # tasks completed in a period
  scan_progress.py --ready      # not-started tasks with no blockers, grouped with their pairs

Stages (furthest one wins):
  not_started   spec in .tasks/<category>/ and no output next to it
  in_progress   spec in .tasks/ with an output beside it (html file or folder)
  completed     filed in .completed_tasks/<slug>/ but no card in index.html yet
  published     has a card in index.html on the local dev branch (where publishing happens;
                main and origin/main are not consulted, since they lag behind dev)

Completion date: the last time Claude wrote or edited the task's output file, read from the
Claude Code transcripts (~/.claude/projects/<repo>/, including subagent transcripts). Only edits made
before the task was filed count (later touch-ups are maintenance). Work Claude never touched
(e.g. built entirely by another agent) falls back to when .completed_tasks/<slug>/ was first
committed. Git commit dates alone mislead: a batch filed in one commit gets one date.

Blockers and pairs are heuristics from each spec's text and filename: confirm them by
reading the spec (an "Execution note" can lift a blocker, e.g. "Blender is not installed:
generate procedurally").
"""
import argparse, json, os, re, subprocess, sys
from datetime import datetime, date

STOP = set('a an and the of for with in on to 3d 2d game sim simulation simulator animation app based interactive '
           'procedural real time real-time browser html engine chinese cn en md'.split())


def sh(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ''


def words(s):
    s = re.sub(r'\[.*?\]', ' ', s.lower())
    return {w for w in re.findall(r'[a-z]+', s) if w not in STOP and len(w) > 2}


def tasks_in_index(text):
    if not text:
        return {}
    a = text.find('const TASKS = [')
    if a < 0:
        return {}
    b = text.find('\n];\n', a)
    out = {}
    for m in re.finditer(r'\{ dir: "([^"]+)",(.*?)\},\n', text[a:b + 4], re.S):
        body = m.group(2)
        def num(k):
            mm = re.search(r'\b%s: ([\d.]+)' % k, body)
            return float(mm.group(1)) if mm else None
        title = re.search(r'title: "((?:[^"\\]|\\.)*)"', body)
        by = re.search(r'by: "((?:[^"\\]|\\.)*)"', body)
        shared = re.search(r'shared: "((?:[^"\\]|\\.)*)"', body)
        group = re.search(r'group: "([^"]+)"', body)
        out[m.group(1)] = dict(title=title.group(1) if title else m.group(1), by=by.group(1) if by else None,
                               shared=shared.group(1) if shared else None, group=group.group(1) if group else None,
                               min=num('min'), **{k: num(k) for k in ('in', 'cw', 'cr', 'out')})
    return out


BLOCKERS = [
    ('Blender', r'\bblender\b|\bbpy\b', r'blender is not installed'),
    ('Godot engine', r'\bgodot\b', None),
    ('Unity engine', r'\bunity\b', None),
    ('Tinkercad (web app, needs screen control)', r'tinkercad|thinkercard', None),
    ('Xcode / iOS', r'\bios\b|iphone|xcode', r'command line tools|swift package'),
    ('live screen / computer use', r'computer use|control (the )?(mouse|screen)|macos chess', None),
    ('needs an input image', r'from (an |a )?(image|photo|picture|sketch|drawing)|input image|upload(ed)? (an |a )?(image|photo)|floor ?plan|pencil sketch|image to', r'sample|procedurally generated sample|generate (a |the )?(sample|placeholder)'),
]


# shell commands that edit a file in place (moves and copies don't count as building it)
MODIFY = re.compile(r"python3? -|sed -i|>\s*\S|\btee\b|open\([^)]*'w'")
ELSEWHERE = re.compile(r"/scratchpad/|/tmp/|-workspace/|/private/var/")


def last_writes(names, project_dir, repo, pkg_dirs=()):
    """Latest Write/Edit timestamp per output basename across all transcripts."""
    import glob
    from datetime import timezone
    files = glob.glob(os.path.join(project_dir, '*.jsonl')) + glob.glob(os.path.join(project_dir, '*', 'subagents', '*.jsonl'))
    found = {}
    for f in files:
        with open(f, errors='ignore') as fh:
            for line in fh:
                if not any(n in line for n in names) and not any('/' + p + '/' in line for p in pkg_dirs):
                    continue
                try:
                    d = json.loads(line)
                except ValueError:
                    continue
                if d.get('type') != 'assistant':
                    continue
                for c in d.get('message', {}).get('content', []) or []:
                    if c.get('type') != 'tool_use':
                        continue
                    inp = c.get('input', {}) or {}
                    hits = []
                    if c.get('name') in ('Write', 'Edit', 'NotebookEdit', 'MultiEdit'):
                        fp_full = str(inp.get('file_path', ''))
                        if fp_full.startswith(repo) and not ELSEWHERE.search(fp_full):
                            hits = [os.path.basename(fp_full)] + ['DIR:' + p for p in pkg_dirs if '/' + p + '/' in fp_full]
                    elif c.get('name') == 'Bash' and MODIFY.search(str(inp.get('command', ''))) and not ELSEWHERE.search(str(inp.get('command', ''))):
                        # shell edits: python patches, sed -i, cp/mv, redirects that name the file
                        cmd = str(inp.get('command', ''))
                        hits = [n for n in names if n in cmd] + ['DIR:' + p for p in pkg_dirs if '/' + p + '/' in cmd]
                        if len(hits) > 2:   # bulk filing/publishing scripts name many tasks; they aren't edits
                            hits = []
                    for fp in hits:
                        if fp not in names and not fp.startswith('DIR:'):
                            continue
                        t = datetime.fromisoformat(d['timestamp'].replace('Z', '+00:00')).astimezone()
                        if fp not in found or t > found[fp]:
                            found[fp] = t
    return {k: v.strftime('%Y-%m-%d %H:%M') for k, v in found.items()}


def blockers_for(text):
    t = text.lower()
    found = []
    for name, pat, lift in BLOCKERS:
        if re.search(pat, t) and not (lift and re.search(lift, t)):
            found.append(name)
    return found


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--since')
    ap.add_argument('--until')
    ap.add_argument('--ready', action='store_true')
    ap.add_argument('--project-dir', help='transcript folder (default: derived from the current directory)')
    a = ap.parse_args()
    if not os.path.isdir('.tasks') or not os.path.exists('index.html'):
        sys.exit('run from the ai_creation repo root')

    branch = sh('git', 'branch', '--show-current').strip()
    site_ref = 'dev'
    idx_here = tasks_in_index(sh('git', 'show', f'{site_ref}:index.html'))
    open_prs = []
    gh = sh('gh', 'pr', 'list', '--state', 'open', '--json', 'number,title,headRefName')
    if gh:
        try:
            open_prs = json.loads(gh)
        except ValueError:
            pass

    tasks = []
    # work still in .tasks/
    for cat in sorted(os.listdir('.tasks')):
        cdir = os.path.join('.tasks', cat)
        if not os.path.isdir(cdir):
            continue
        entries = [e for e in os.listdir(cdir) if not e.startswith('.')]
        specs = [e for e in entries if e.endswith('.md')]
        outputs = [e for e in entries if not e.endswith('.md')]
        claimed = {}
        for sp in specs:
            text = open(os.path.join(cdir, sp), errors='ignore').read()
            head = re.search(r'^#\s+(.+)$', text, re.M)
            sw = words(sp[:-3]) | words(head.group(1) if head else '')
            best, score = None, 0.0
            for o in outputs:
                ow = words(os.path.splitext(o)[0].replace('-', ' '))
                if not ow:
                    continue
                s = len(sw & ow) / len(ow)
                if s > score:
                    best, score = o, s
            out = best if score >= 0.5 else None
            if out:
                claimed[out] = sp
            path = os.path.join(cdir, sp)
            st = None
            if out:
                op = os.path.join(cdir, out)
                st = datetime.fromtimestamp(os.path.getmtime(op)).strftime('%Y-%m-%d %H:%M')
            tasks.append(dict(spec=path, category=cat, title=(head.group(1).strip() if head else sp[:-3]),
                              stage='in_progress' if out else 'not_started', output=os.path.join(cdir, out) if out else None,
                              output_modified=st, blockers=blockers_for(text + ' ' + sp),
                              chinese=bool(re.search(r'chinese|\[cn\]', sp.lower()) or re.search(r'[一-鿿]{6,}', text))))
        for o in outputs:
            if o not in claimed:
                tasks.append(dict(spec=None, category=cat, title=o, stage='in_progress', output=os.path.join(cdir, o),
                                  output_modified=datetime.fromtimestamp(os.path.getmtime(os.path.join(cdir, o))).strftime('%Y-%m-%d %H:%M'),
                                  blockers=[], note='output with no matching spec'))

    # filed / published
    proj = os.path.expanduser('~/.claude/projects/' + os.getcwd().replace('/', '-').replace('_', '-'))
    if a.project_dir:
        proj = os.path.expanduser(a.project_dir)
    outs_by_slug = {}
    for slug in os.listdir('.completed_tasks'):
        d = os.path.join('.completed_tasks', slug)
        if os.path.isdir(d):
            outs_by_slug[slug] = [f for f in os.listdir(d) if not f.endswith(('.md', '.png')) and not f.startswith('.')]
    names = {n for v in outs_by_slug.values() for n in v if not os.path.isdir(os.path.join('.completed_tasks', '_', n))}
    # a package folder counts as edited when any file inside it is (matched by its folder path)
    pkg_dirs = {o: slug for slug, outs in outs_by_slug.items() for o in outs
                if os.path.isdir(os.path.join('.completed_tasks', slug, o))}
    writes = last_writes(names, proj, os.getcwd(), tuple(pkg_dirs)) if os.path.isdir(proj) else {}
    for slug in sorted(os.listdir('.completed_tasks')):
        d = os.path.join('.completed_tasks', slug)
        if not os.path.isdir(d):
            continue
        first = sh('git', 'log', '--diff-filter=A', '--format=%ad', '--date=format:%Y-%m-%d %H:%M', '--', d).strip().split('\n')
        filed = first[-1] if first and first[-1] else datetime.fromtimestamp(os.path.getmtime(d)).strftime('%Y-%m-%d %H:%M') + ' (uncommitted)'
        built = [writes[n] for n in outs_by_slug.get(slug, []) if n in writes]
        built += [writes['DIR:' + p] for p, s2 in pkg_dirs.items() if s2 == slug and 'DIR:' + p in writes]
        # edits after filing are maintenance (README tweaks, fixes), not completion
        cutoff = filed[:16]
        built = [b for b in built if b <= cutoff] or ([] if 'uncommitted' not in filed else built)
        when = max(built) if built else filed
        source = 'last Claude edit' if built else 'filing commit'
        info = idx_here.get(slug)
        stage = 'published' if info else 'completed'
        spec = next((f for f in os.listdir(d) if f.endswith('.md')), None)
        tasks.append(dict(slug=slug, spec=os.path.join(d, spec) if spec else None, stage=stage, completed=when, completed_source=source, filed=filed,
                          title=(info or {}).get('title', slug), by=(info or {}).get('by'),
                          stats={k: (info or {}).get(k) for k in ('min', 'in', 'cw', 'cr', 'out')} if info else None,
                          shared=(info or {}).get('shared'), group=(info or {}).get('group')))

    # tasks finished in one run (pairs, groups) share the latest completion date of the set
    done = [t for t in tasks if t.get('slug')]
    by_title = {t['title']: t for t in done}
    for t in done:
        mates = [u for u in done if u is not t and ((t.get('group') and u.get('group') == t['group'])
                 or (t.get('shared') and u['title'] == t['shared']) or (u.get('shared') == t['title']))]
        real = [x for x in [t] + mates if x['completed_source'] == 'last Claude edit']
        if mates and real:
            latest = max(real, key=lambda x: x['completed'][:16])
            if latest is not t and (latest['completed'][:16] > t['completed'][:16] or t['completed_source'] != 'last Claude edit'):
                t['completed'], t['completed_source'] = latest['completed'], 'shared run (' + latest['slug'] + ')'

    # pairs among not-started/in-progress: shared distinctive words (EN/CN twins, explainer + lab ...)
    live_work = [t for t in tasks if t['stage'] in ('not_started', 'in_progress') and t.get('spec')]
    for t in live_work:
        tw = words(os.path.basename(t['spec'])[:-3])
        mates = []
        for u in live_work:
            if u is t:
                continue
            uw = words(os.path.basename(u['spec'])[:-3])
            if len(tw & uw) >= 2 or (t.get('chinese') != u.get('chinese') and len(tw & uw) >= 1 and t['category'] == u['category']):
                mates.append(os.path.basename(u['spec']))
        t['pair_with'] = mates

    if a.since:
        lo = a.since
        hi = a.until or '9999'
        sel = [t for t in tasks if t.get('completed') and lo <= t['completed'][:10] <= hi]
        if a.json:
            print(json.dumps(sel, indent=1, ensure_ascii=False)); return
        print(f'Completed {lo}' + (f' – {a.until}' if a.until else ' onward') + f': {len(sel)}')
        seen = set()
        for t in sel:
            s = t.get('stats') or {}
            key = t.get('group') or ('|'.join(sorted([t['title'], t['shared']])) if t.get('shared') else t['slug'])
            dup = key in seen; seen.add(key)
            tot = sum(int(s.get(k) or 0) for k in ('in', 'cw', 'cr', 'out')) if s else 0
            fig = (f'{s["min"]} min, {tot:,} tok' + (' (shared run, counted above)' if dup else '')) if s and s.get('min') is not None else 'no stats yet'
            print(f'  [{t["stage"]:9}] {t["slug"]:34} {t["completed"]:16} {"" if t["completed_source"].startswith("last") else ("(run)" if t["completed_source"].startswith("shared") else "(filed)"):8} {t.get("by") or "":30} {fig}')
        return

    if a.ready:
        ns = [t for t in tasks if t['stage'] == 'not_started']
        ready = [t for t in ns if not t['blockers']]
        blocked = [t for t in ns if t['blockers']]
        if a.json:
            print(json.dumps(dict(ready=ready, blocked=blocked), indent=1, ensure_ascii=False)); return
        print(f'Ready to start ({len(ready)}):')
        for t in ready:
            pair = f'  (pair with: {", ".join(t["pair_with"])})' if t.get('pair_with') else ''
            print(f'  {t["category"]:10} {os.path.basename(t["spec"])}{pair}')
        print(f'\nBlocked ({len(blocked)}):')
        for t in blocked:
            print(f'  {t["category"]:10} {os.path.basename(t["spec"]):62} {"; ".join(t["blockers"])}')
        return

    if a.json:
        print(json.dumps(dict(branch=branch, site_ref=site_ref, open_prs=open_prs, tasks=tasks), indent=1, ensure_ascii=False)); return
    order = ['published', 'completed', 'in_progress', 'not_started']
    counts = {s: sum(1 for t in tasks if t['stage'] == s) for s in order}
    print(f'branch {branch}; published = card in {site_ref}:index.html; {len(tasks)} tasks: ' + ', '.join(f'{v} {k.replace("_", " ")}' for k, v in counts.items()))
    if open_prs:
        print('open PRs: ' + '; '.join(f'#{p["number"]} {p["title"]} ({p["headRefName"]})' for p in open_prs))
    for s in order[1:]:
        rows = [t for t in tasks if t['stage'] == s]
        if not rows:
            continue
        print(f'\n{s.replace("_", " ").upper()} ({len(rows)})')
        for t in rows:
            if s == 'in_progress':
                print(f'  {t["category"]:10} {os.path.basename(t["output"] or ""):40} modified {t["output_modified"]}  {t.get("note", "")}')
            elif s == 'not_started':
                b = ('  [blocked: ' + '; '.join(t['blockers']) + ']') if t['blockers'] else ''
                print(f'  {t["category"]:10} {os.path.basename(t["spec"])}{b}')
            else:
                print(f'  {t["slug"]:34} completed {t["completed"]}')


if __name__ == '__main__':
    main()
