#!/usr/bin/env python3
"""Prove that an edit to a device-tree file changed ONLY comments.

Usage: check_comments_only.py <old-file> <new-file>

Strips comments and blank lines from both and compares what is left.  The point
is to make a bulk comment relocation reviewable: if this prints OK, not a single
directive, variable assignment, fstab line or rc command was touched.

Comment syntax handled, by extension:
  .mk .bp .rc .fstab .flags .gitattributes .gitignore   '#' to end of line
  .xml                                                 '<!--' ... '-->'
  .mk (Android.mk) / .bp                               also '//'
"""
import sys, re, os


def strip(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    ext = os.path.splitext(path)[1].lower()
    if ext == ".xml":
        text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    else:
        out = []
        for line in text.split("\n"):
            # '#' starts a comment in make, rc, fstab, flags and git config files
            i = line.find("#")
            if i >= 0:
                line = line[:i]
            if ext in (".mk", ".bp"):
                j = line.find("//")
                if j >= 0:
                    line = line[:j]
            out.append(line)
        text = "\n".join(out)
    keep = []
    for line in text.split("\n"):
        line = re.sub(r"[ \t]+", " ", line).strip()
        if line:
            keep.append(line)
    return keep


def main():
    a, b = sys.argv[1], sys.argv[2]
    old, new = strip(a), strip(b)
    if old == new:
        print("OK   comment-only change: %d code lines identical" % len(old))
        return 0
    import difflib
    print("FAIL code changed: %s -> %s" % (a, b))
    for l in list(difflib.unified_diff(old, new, "old", "new", lineterm=""))[:60]:
        print("   " + l)
    return 1


if __name__ == "__main__":
    sys.exit(main())
