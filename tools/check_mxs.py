# -*- coding: utf-8 -*-
"""
check_mxs.py - static sanity check for the MAXScript files in this repository.

There is no MAXScript compiler available outside 3ds Max, so this script catches
the mistakes that break a .ms file most often:

  * unbalanced parentheses  (computed outside comments and strings)
  * ';' used to glue several statements on one line  (unreliable in MAXScript)
  * '\\' line continuation  (MAXScript does not support it)
  * UTF-8 BOM  (some Max versions choke on it)
  * duplicated fn / rollout / macroScript names across the whole tree

usage:
    python tools/check_mxs.py [root]      # root defaults to ./src

exit code 0 = clean, 1 = at least one error.
"""

import os
import re
import sys
import collections


def scan_source(src):
    """Return (problems, names) after walking the source char by char.

    problems: list of (kind, line, text)
    names:    list of declared fn / rollout / macroScript names
    """
    problems = []
    names = []
    depth = 0
    line = 1
    i = 0
    n = len(src)
    in_str = False
    in_block = False

    while i < n:
        c = src[i]

        if c == '\n':
            line += 1
            i += 1
            continue

        if in_block:
            if src[i:i + 2] == '*/':
                in_block = False
                i += 2
                continue
            i += 1
            continue

        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue

        if src[i:i + 2] == '/*':
            in_block = True
            i += 2
            continue

        if src[i:i + 2] == '--':
            j = src.find('\n', i)
            i = n if j < 0 else j
            continue

        if c == '"':
            in_str = True
            i += 1
            continue

        # a namelist such as #{1..3} must not be mistaken for syntax
        if src[i:i + 2] == '#{':
            j = src.find('}', i)
            i = n if j < 0 else j + 1
            continue

        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth < 0:
                problems.append(('paren', line, 'unexpected ")"'))
                depth = 0
        i += 1

    if depth != 0:
        problems.append(('paren', line, 'unbalanced parentheses, leftover %d' % depth))

    names += [('fn', m) for m in re.findall(r'^fn (\w+)', src, re.M)]
    names += [('rollout', m) for m in re.findall(r'^rollout (\w+)', src, re.M)]
    names += [('macro', m) for m in re.findall(r'^macroScript (\w+)', src, re.M)]

    for lineno, text in enumerate(src.split('\n'), start=1):
        stripped = text.lstrip()
        if stripped.startswith('--') or stripped.startswith('*'):
            continue
        body = strip_literals(text)
        if ';' in body:
            problems.append(('semicolon', lineno, text.strip()[:90]))
        if text.rstrip().endswith('\\'):
            problems.append(('backslash', lineno, text.strip()[:90]))

    return problems, names


def strip_literals(text):
    """Blank out string literals so punctuation inside them is ignored."""
    out = []
    in_str = False
    i = 0
    while i < len(text):
        c = text[i]
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
            out.append(' ')
            i += 1
            continue
        if text[i:i + 2] == '--':
            break
        if c == '"':
            in_str = True
            out.append(' ')
            i += 1
            continue
        out.append(c)
        i += 1
    return ''.join(out)


def main():
    root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src')
    root = os.path.abspath(root)

    files = []
    for dirpath, dirnames, filenames in os.walk(root):
        for f in sorted(filenames):
            if f.lower().endswith('.ms'):
                files.append(os.path.join(dirpath, f))

    if not files:
        print('no .ms file found under', root)
        return 1

    print('checking %d MAXScript files under %s\n' % (len(files), root))

    all_names = []
    failed = False
    for path in files:
        raw = open(path, 'rb').read()
        rel = os.path.relpath(path, os.path.dirname(root))
        src = raw.decode('utf-8')
        if raw[:3] == b'\xef\xbb\xbf':
            print('  BOM!   %s' % rel)
            failed = True
        problems, names = scan_source(src)
        all_names += names
        lines = src.count('\n') + 1
        if problems:
            failed = True
            print('  FAIL   %-44s %5d lines' % (rel, lines))
            for kind, lineno, detail in problems:
                print('           %-10s line %-5d %s' % (kind, lineno, detail))
        else:
            print('  ok     %-44s %5d lines  (%s)' % (
                rel, lines, ', '.join('%s:%d' % (k, sum(1 for t, _ in names if t == k))
                                      for k in ('fn', 'rollout', 'macro')
                                      if any(t == k for t, _ in names)) or 'no declaration'))

    dupes = [(kind, name) for (kind, name), cnt in collections.Counter(all_names).items() if cnt > 1]
    print()
    if dupes:
        failed = True
        print('duplicate declarations:')
        for kind, name in dupes:
            print('   %s %s' % (kind, name))
    else:
        print('no duplicate fn / rollout / macroScript name (%d symbols)' % len(all_names))

    print('\nresult: %s' % ('ERRORS FOUND' if failed else 'clean'))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
