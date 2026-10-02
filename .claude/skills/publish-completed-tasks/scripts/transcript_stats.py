#!/usr/bin/env python3
"""Active time and token usage for tasks, read from Claude Code session transcripts.

Two subcommands:

  messages  List the user messages of a day (or one session) with local timestamps,
            so you can find where each task started and ended.
  stats     Sum time and tokens for one or more labelled windows.

A window is  label=SESSION[@START[-END]]  where SESSION is a transcript id (or a unique
prefix of it) and START/END are local HH:MM[:SS] times on --date. Without @START-END the
whole day of that session counts. Repeat a label to add several windows to one task.

Rules (they match how the published figures were computed):
  * each assistant message is counted once (transcripts repeat a message per content block, and
    older transcripts log partial usage while streaming, so the largest value per field is kept);
  * timestamps are sorted before measuring gaps, because compaction can write lines out of order;
  * active time leaves out any gap longer than --idle minutes (default 20);
  * total tokens = input + cache writes + cache reads + output.

Examples:
  transcript_stats.py messages --date 2026-10-01
  transcript_stats.py stats --date 2026-10-01 \
      fox=d95ba9e1@15:12:30-15:46:39 moai=d95ba9e1@15:46:39-16:53:27 music=5d159eb1
"""
import argparse, glob, json, os, sys
from datetime import datetime, timedelta, timezone


def default_project_dir():
    cwd = os.getcwd()
    return os.path.expanduser('~/.claude/projects/' + cwd.replace('/', '-').replace('_', '-'))


def local_tz(offset):
    if offset is None:
        return datetime.now().astimezone().tzinfo
    return timezone(timedelta(hours=offset))


def load(path, tz):
    rows = []
    with open(path) as f:
        for line in f:
            try:
                d = json.loads(line)
            except ValueError:
                continue
            t = d.get('timestamp')
            if t:
                rows.append((datetime.fromisoformat(t.replace('Z', '+00:00')).astimezone(tz), d))
    return rows


def sessions(project_dir):
    # top-level sessions plus subagent transcripts (<session>/subagents/agent-*.jsonl)
    paths = glob.glob(os.path.join(project_dir, '*.jsonl')) + glob.glob(os.path.join(project_dir, '*', 'subagents', '*.jsonl'))
    return {os.path.basename(p)[:-6]: p for p in paths}


def resolve(sid, sess):
    hits = [k for k in sess if k.startswith(sid)]
    if len(hits) != 1:
        sys.exit(f'session "{sid}" matches {len(hits)} transcripts: {hits[:5]}')
    return hits[0]


def user_text(d):
    if d.get('type') != 'user':
        return None
    c = d.get('message', {}).get('content')
    if isinstance(c, list):
        c = ' '.join(x.get('text', '') for x in c if isinstance(x, dict) and x.get('type') == 'text')
    if not isinstance(c, str) or not c.strip() or c.startswith('<'):
        return None
    return c


def cmd_messages(a, tz, sess):
    day = datetime.strptime(a.date, '%Y-%m-%d').replace(tzinfo=tz)
    ids = [resolve(a.session, sess)] if a.session else sorted(sess)
    for sid in ids:
        rows = [r for r in load(sess[sid], tz) if day <= r[0] < day + timedelta(days=1)]
        msgs = [(t, user_text(d)) for t, d in rows]
        msgs = [(t, m) for t, m in msgs if m]
        if not msgs:
            continue
        print(f'== {sid}  ({min(r[0] for r in rows):%H:%M}-{max(r[0] for r in rows):%H:%M})')
        for t, m in sorted(msgs, key=lambda x: x[0]):
            print(f'  {t:%H:%M:%S}  {m[:110].replace(chr(10), " ")}')


def parse_hms(day, s):
    for fmt in ('%H:%M:%S', '%H:%M'):
        try:
            t = datetime.strptime(s, fmt)
            return day.replace(hour=t.hour, minute=t.minute, second=t.second)
        except ValueError:
            pass
    sys.exit(f'bad time "{s}"')


def cmd_stats(a, tz, sess):
    day = datetime.strptime(a.date, '%Y-%m-%d').replace(tzinfo=tz)
    groups = {}
    for w in a.windows:
        label, _, spec = w.partition('=')
        sid, _, span = spec.partition('@')
        sid = resolve(sid, sess)
        if span:
            s, _, e = span.partition('-')
            start, end = parse_hms(day, s), (parse_hms(day, e) if e else day + timedelta(days=1))
        else:
            start, end = day, day + timedelta(days=1)
        groups.setdefault(label, []).append((sid, start, end))
    cache = {}
    out = {}
    for label, wins in groups.items():
        rows = []
        for sid, s, e in wins:
            if sid not in cache:
                cache[sid] = load(sess[sid], tz)
            rows += [r for r in cache[sid] if s <= r[0] < e]
        per_msg = {}
        for _, d in rows:
            m = d.get('message', {})
            if d.get('type') != 'assistant' or not m.get('usage'):
                continue
            us, cur = m['usage'], per_msg.setdefault(m.get('id') or id(d), [0, 0, 0, 0])
            for i, k in enumerate(('input_tokens', 'cache_creation_input_tokens', 'cache_read_input_tokens', 'output_tokens')):
                cur[i] = max(cur[i], us.get(k, 0) or 0)
        u = dict(min=0.0, **{'in': 0, 'cw': 0, 'cr': 0, 'out': 0})
        for a_, b_, c_, d_ in per_msg.values():
            u['in'] += a_; u['cw'] += b_; u['cr'] += c_; u['out'] += d_
        ts = sorted(r[0] for r in rows)
        u['min'] = round(sum((b - a2).total_seconds() for a2, b in zip(ts, ts[1:])
                             if (b - a2).total_seconds() <= a.idle * 60) / 60, 1)
        u['total'] = u['in'] + u['cw'] + u['cr'] + u['out']
        out[label] = u
        print(f"{label:24} {u['min']:7.1f} min  in={u['in']:,} cw={u['cw']:,} cr={u['cr']:,} out={u['out']:,} total={u['total']:,}")
    if a.json:
        with open(a.json, 'w') as f:
            json.dump(out, f, indent=1)
        print('wrote', a.json)


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--project-dir', default=None, help='transcript folder (default: derived from the current directory)')
    p.add_argument('--tz', type=float, default=None, help='UTC offset in hours (default: this machine)')
    sub = p.add_subparsers(dest='cmd', required=True)
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument('--project-dir', dest='project_dir2', default=None)
    common.add_argument('--tz', dest='tz2', type=float, default=None)
    m = sub.add_parser('messages', parents=[common])
    m.add_argument('--date', required=True)
    m.add_argument('--session')
    s = sub.add_parser('stats', parents=[common])
    s.add_argument('--date', required=True)
    s.add_argument('--idle', type=float, default=20)
    s.add_argument('--json')
    s.add_argument('windows', nargs='+')
    a = p.parse_args()
    a.project_dir = a.project_dir or a.project_dir2
    a.tz = a.tz if a.tz is not None else a.tz2
    pd = a.project_dir or default_project_dir()
    sess = sessions(pd)
    if not sess:
        sys.exit(f'no transcripts in {pd}')
    tz = local_tz(a.tz)
    (cmd_messages if a.cmd == 'messages' else cmd_stats)(a, tz, sess)


if __name__ == '__main__':
    main()
