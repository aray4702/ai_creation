#!/usr/bin/env python3
"""Publish filed tasks: top-level folders, index.html cards and README.md sections.

  publish_site.py manifest.json            # build folders + update index.html and README.md
  publish_site.py --check                  # only validate every link in index.html / README.md

Run from the repo root, after file_tasks.py. Per task the manifest needs:

  slug    folder name; the filed copy lives in .completed_tasks/<slug>/
  brief   path to the cleaned-up brief you wrote (published under the ORIGINAL spec filename)
  spec    original spec path (only its filename is used here)
  cat     card category: Game, Simulation, Animation, Media, 3D, App ...
  title   display title;  desc  one or two sentence description
  by      credit line: "Main session", "Subagent", or "<Agent> · finished by Claude"
  links   [[target, label], ...]  target is a file inside the folder, or an https:// URL
          (use a GitHub tree URL for things a browser can't run, like a Swift package)
  stats   {"min", "in", "cw", "cr", "out"} from transcript_stats.py
optional:
  shot    screenshot filename when it isn't <first link>.png (e.g. for a package)
  shared  title of the other task in a pair built in one run (set it on both tasks)
  group   key shared by 3+ tasks finished in one run; give each the same "note" text
  note    optional one-line note shown on the card and in the README (e.g. an earlier attempt)

Top-level manifest fields (optional): "source_range" for the footer, e.g. "28 Sep – 2 Oct 2026".
"""
import json, os, re, shutil, subprocess, sys
from urllib.parse import quote, unquote

SKIP = shutil.ignore_patterns('.build', 'node_modules', '.DS_Store', '__pycache__')
TASKS_RE = re.compile(r'const TASKS = \[')
WORDS = ('zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen '
         'sixteen seventeen eighteen nineteen').split()
TENS = 'twenty thirty forty fifty sixty seventy eighty ninety'.split()


def words(n):
    if n < 20:
        return WORDS[n]
    if n < 100:
        return TENS[n // 10 - 2] + ('' if n % 10 == 0 else '-' + WORDS[n % 10])
    return str(n)


def fm(n):
    return f'{n / 1e6:.1f}M' if n >= 1e6 else f'{round(n / 1e3)}K'


def fmin(m):
    return f'{int(m // 60)}h {round(m % 60)}m' if m >= 60 else f'{m:.1f} min'


def js(v):
    return json.dumps(v, ensure_ascii=False)


def is_url(s):
    return bool(re.match(r'https?:', s))


def eval_tasks():
    code = r'''
const s=require("fs").readFileSync("index.html","utf8");
const a=s.indexOf("const TASKS = [")+14, b=s.indexOf("\n];\n",a)+3;
const TASKS=eval(s.slice(a,b));
const seen=new Set(); let m=0,o=0,t=0;
for(const x of TASKS){ const k=x.group||(x.shared?[x.title,x.shared].sort().join("|"):x.dir);
  if(seen.has(k))continue; seen.add(k); m+=x.min; o+=x.out; t+=x.in+x.cw+x.cr+x.out; }
console.log(JSON.stringify({tasks:TASKS,n:TASKS.length,min:m,out:o,all:t}));'''
    r = subprocess.run(['node', '-e', code], capture_output=True, text=True)
    if r.returncode:
        sys.exit('could not evaluate TASKS in index.html:\n' + r.stderr)
    return json.loads(r.stdout)


def check():
    data, bad = eval_tasks(), []
    titles = {t['title'] for t in data['tasks']}
    for t in data['tasks']:
        # a pair counts once only if each names the other's exact title
        if t.get('shared') and t['shared'] not in titles:
            bad.append(f'index: {t["dir"]} shared -> "{t["shared"]}" matches no title (pair would be counted twice)')
    for t in data['tasks']:
        files = [t['md'], t.get('shot') or t['outputs'][0][0].replace('.html', '.png')]
        files += [f for f, _ in t['outputs'] if not is_url(f)]
        files += [f.replace('.html', '.png') for f, _ in t['outputs'] if not is_url(f) and f.endswith('.html')]
        bad += [f'index: {t["dir"]}/{f}' for f in files if not os.path.exists(os.path.join(t['dir'], f))]
    rd = open('README.md').read()
    for link in re.findall(r'\]\(([^)]+)\)', rd) + re.findall(r'(?:src|href)="([^"]+)"', rd):
        if is_url(link) or link.startswith('#'):
            continue
        if not os.path.exists(unquote(link.split('#')[0])):
            bad.append(f'README: {link}')
    for a in re.findall(r'\]\(#([^)]+)\)', rd):
        if f'<a id="{a}">' not in rd:
            bad.append(f'README anchor: #{a}')
    print(f'{data["n"]} tasks in index.html; {len(bad)} broken link(s)')
    for b in bad:
        print('  ', b)
    return not bad


# index.html render code needs these features; patch them in if an older page lacks them
RENDER_PATCHES = [
    ('const enc = (dir, f) => dir + "/" + encodeURIComponent(f);',
     'const enc = (dir, f) => /^https?:/.test(f) ? f : dir + "/" + encodeURIComponent(f);\n'
     'const shotOf = (t, f) => enc(t.dir, t.shot || f.replace(/\\.html$/, ".png"));'),
    ('  const key = t.shared ? [t.title, t.shared].sort().join("|") : t.dir;',
     '  const key = t.group || (t.shared ? [t.title, t.shared].sort().join("|") : t.dir);'),
    ('<img loading="lazy" src="${enc(t.dir, png(f))}"', '<img loading="lazy" src="${shotOf(t, f)}"'),
]


def update_index(tasks, man):
    idx = open('index.html').read()
    if 'shotOf' not in idx:
        for a, b in RENDER_PATCHES:
            if a not in idx:
                sys.exit('index.html render code changed shape; update RENDER_PATCHES first')
            idx = idx.replace(a, b)
    entries = []
    for t in tasks:
        s = t['stats']
        e = (f'  {{ dir: {js(t["slug"])}, cat: {js(t["cat"])}, title: {js(t["title"])},\n'
             f'    desc: {js(t["desc"])},\n'
             f'    md: {js(os.path.basename(t["spec"]))}, outputs: {js(t["links"])},')
        if t.get('shot'):
            e += f' shot: {js(t["shot"])},'
        e += '\n    '
        if t.get('shared'):
            e += f'shared: {js(t["shared"])}, '
        if t.get('group'):
            e += f'group: {js(t["group"])}, '
        if t.get('note'):
            e += f'note: {js(t["note"])}, '
        e += (f'min: {s["min"]}, in: {s["in"]}, cw: {s["cw"]}, cr: {s["cr"]}, out: {s["out"]}, '
              f'by: {js(t["by"])} }},')
        entries.append(e)
    m = TASKS_RE.search(idx)
    end = idx.index('\n];\n', m.end())
    idx = idx[:end] + '\n' + '\n'.join(entries) + idx[end:]
    open('index.html', 'w').write(idx)
    data = eval_tasks()
    idx = open('index.html').read()
    idx = re.sub(r'(<p>)([A-Za-z-]+)( builds)', lambda mm: mm.group(1) + words(data['n']).capitalize() + mm.group(3), idx, count=1)
    if man.get('source_range'):
        idx = re.sub(r'(Source: Claude Code session transcripts, )[^.]*\.', r'\g<1>' + man['source_range'] + '.', idx, count=1)
    open('index.html', 'w').write(idx)
    return data


def update_readme(tasks, man, data):
    rd = open('README.md').read()
    nums = [int(x) for x in re.findall(r'^<a id="(\d+)-', rd, re.M)]
    start = max(nums) + 1 if nums else 1
    rd = re.sub(r'^([A-Za-z-]+)( builds)', lambda mm: words(data['n']).capitalize() + mm.group(2), rd, count=1, flags=re.M)
    rd = re.sub(r'^\| \*\*\d+\*\* \| \*\*[^*]+\*\* \| \*\*[^*]+\*\* \| \*\*[^*]+\*\* \|$',
                f'| **{data["n"]}** | **{fmin(data["min"])}** | **{fm(data["out"])}** | **{fm(data["all"])}** |',
                rd, count=1, flags=re.M)
    if man.get('source_range'):
        rd = re.sub(r'(Source: Claude Code session transcripts, )[^.]*\.', r'\g<1>' + man['source_range'] + '.', rd, count=1)
    lines = rd.split('\n')
    last_toc = max(i for i, l in enumerate(lines) if re.match(r'^\d+\. \[.*\]\(#\d+-', l))
    lines[last_toc + 1:last_toc + 1] = [f'{start + i}. [{t["title"]}](#{start + i}-{t["slug"]})' for i, t in enumerate(tasks)]
    rd = '\n'.join(lines)
    secs, rows = [], []
    for i, t in enumerate(tasks):
        n, d, s = start + i, t['slug'], t['stats']
        tot = s['in'] + s['cw'] + s['cr'] + s['out']
        target, label = t['links'][0]
        link = target if is_url(target) else f'{d}/{quote(target)}'
        shot = f'{d}/{quote(t.get("shot") or os.path.splitext(target)[0] + ".png")}'
        if is_url(target):
            local = [x for x in os.listdir(d) if os.path.isdir(os.path.join(d, x))]
            if local:
                link = f'{d}/{quote(local[0])}/'
        note = ''
        if t.get('note'):
            note = f'\n> {t["note"]}\n'
        elif t.get('shared'):
            note = f'\n> Built in the same agent run as *{t["shared"]}*; the figures cover both tasks.\n'
        outs = ' · '.join(f'[{lb}]({tg if is_url(tg) else d + "/" + quote(tg)})' for tg, lb in t['links'])
        if is_url(target):
            outs = f'[{label}]({link})'
        secs.append(f'''<a id="{n}-{d}"></a>
## {n}. {t["title"]}

**{t["cat"]}** · {t["by"]}

<p><a href="{link}"><img src="{shot}" alt="Screenshot of {label}" width="640"></a></p>

{t["desc"]}
{note}
| Active time | Output tokens | Total tokens |
|:-:|:-:|:-:|
| {fmin(s["min"])} | {s["out"]:,} | {fm(tot)} ({tot:,}) |

**Output:** {outs}<br>
**Task brief:** [{os.path.basename(t["spec"])}]({d}/{quote(os.path.basename(t["spec"]))})

---
''')
        mark = ' †' if t.get('group') else (' \\*' if t.get('shared') else '')
        rows.append(f'| {t["title"]}{mark} | {fmin(s["min"])} | {s["in"]:,} | {s["cw"]:,} | {s["cr"]:,} | {s["out"]:,} | {tot:,} |')
    rd = rd.replace('## Full token breakdown', '\n'.join(secs) + '\n## Full token breakdown', 1)
    lines = rd.split('\n')
    bd = lines.index('## Full token breakdown')
    last_row = max(i for i in range(bd, len(lines)) if lines[i].startswith('| ') and not lines[i].startswith('|:'))
    lines[last_row + 1:last_row + 1] = rows
    rd = '\n'.join(lines)
    if any(t.get('group') for t in tasks) and '† ' not in rd:
        rd = rd.replace('\\* One agent run covered both tasks in the pair; each pair is counted once in the totals.',
                        '\\* One agent run covered both tasks in the pair; each pair is counted once in the totals.  \n'
                        '† Finished by Claude after another agent built the first version. The figures are Claude’s single '
                        'finishing run for the group (counted once in the totals); the other agent’s usage isn’t recorded.', 1)
    open('README.md', 'w').write(rd)


def main():
    if '--check' in sys.argv:
        sys.exit(0 if check() else 1)
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    man = json.load(open(sys.argv[1]))
    tasks = man['tasks']
    problems = []
    for t in tasks:
        for k in ('slug', 'brief', 'spec', 'cat', 'title', 'desc', 'by', 'links', 'stats'):
            if k not in t:
                problems.append(f'{t.get("slug", "?")}: missing "{k}"')
        if os.path.exists(t.get('slug', '')):
            problems.append(f'{t["slug"]}/ already exists at the top level')
        if not os.path.isdir(os.path.join('.completed_tasks', t.get('slug', ''))):
            problems.append(f'.completed_tasks/{t.get("slug")}/ not found (run file_tasks.py first)')
        if t.get('brief') and not os.path.exists(t['brief']):
            problems.append(f'brief not found: {t["brief"]}')
        if t.get('shared') and t['shared'] not in {x['title'] for x in tasks} and t['shared'] not in open('index.html').read():
            problems.append(f'{t["slug"]}: shared -> "{t["shared"]}" is not the exact title of another task')
        if t.get('group') and not t.get('note'):
            problems.append(f'{t["slug"]}: group tasks need a "note"')
    if problems:
        sys.exit('Nothing changed:\n  ' + '\n  '.join(problems))
    for t in tasks:
        src, dst = os.path.join('.completed_tasks', t['slug']), t['slug']
        spec_name = os.path.basename(t['spec'])
        os.makedirs(dst)
        shutil.copy2(t['brief'], os.path.join(dst, spec_name))
        for name in os.listdir(src):
            if name == spec_name or name.startswith('.'):
                continue
            p = os.path.join(src, name)
            (shutil.copytree(p, os.path.join(dst, name), ignore=SKIP) if os.path.isdir(p) else shutil.copy2(p, dst))
        print('built', dst + '/')
    data = update_index(tasks, man)
    update_readme(tasks, man, data)
    print(f'index.html + README.md now list {data["n"]} tasks: {fmin(data["min"])}, '
          f'{fm(data["out"])} output, {fm(data["all"])} total tokens')
    check()


if __name__ == '__main__':
    main()
