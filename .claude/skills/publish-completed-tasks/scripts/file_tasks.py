#!/usr/bin/env python3
"""Move finished tasks out of .tasks/ into .completed_tasks/<slug>/.

Reads the same manifest as publish_site.py and uses these fields per task:
  slug        folder name, normally the output's basename (e.g. "fox-lantern-adventure")
  spec        path of the original task brief, e.g. ".tasks/game/3d fox action game.md"
  outputs     list of output paths (files or folders) under .tasks/
  screenshot  path of the chosen screenshot, e.g. ".agents/shots/fox-3.png"

Each task folder gets: the original spec (moved), the outputs (moved; build caches such
as .build/ and node_modules/ are dropped), and the screenshot copied as <main>.png, where
<main> is the first output's name without extension.

Everything is checked before anything moves, so a typo stops the run with nothing half-done.

  file_tasks.py manifest.json            # do it
  file_tasks.py manifest.json --dry-run  # only show what would happen
"""
import json, os, shutil, sys

SKIP = shutil.ignore_patterns('.build', 'node_modules', '.DS_Store', '__pycache__')


def main_name(t):
    return os.path.splitext(os.path.basename(t['outputs'][0].rstrip('/')))[0]


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    man = json.load(open(sys.argv[1]))
    dry = '--dry-run' in sys.argv
    problems = []
    for t in man['tasks']:
        dst = os.path.join('.completed_tasks', t['slug'])
        if os.path.exists(dst):
            problems.append(f'{dst} already exists')
        for p in [t['spec'], *t['outputs'], t['screenshot']]:
            if not os.path.exists(p):
                problems.append(f'missing: {p}')
    if problems:
        sys.exit('Nothing moved:\n  ' + '\n  '.join(problems))
    for t in man['tasks']:
        dst = os.path.join('.completed_tasks', t['slug'])
        shot = os.path.join(dst, main_name(t) + '.png')
        print(f'{t["slug"]}: {t["spec"]} + {len(t["outputs"])} output(s) + {t["screenshot"]} -> {dst}/')
        if dry:
            continue
        os.makedirs(dst)
        shutil.move(t['spec'], dst)
        for o in t['outputs']:
            o = o.rstrip('/')
            if os.path.isdir(o):
                shutil.copytree(o, os.path.join(dst, os.path.basename(o)), ignore=SKIP)
                shutil.rmtree(o)
            else:
                shutil.move(o, dst)
        shutil.copy2(t['screenshot'], shot)
    print('dry run, nothing moved' if dry else f'filed {len(man["tasks"])} task(s)')


if __name__ == '__main__':
    main()
