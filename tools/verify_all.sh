#!/bin/bash
cd /mnt/d/Projects/Github/yarp_device_zte_P725A02 || exit 1
mkdir -p /tmp/headv
fail=0
for f in $(git diff --name-only HEAD); do
  case "$f" in *.md) continue;; esac
  ext=$(basename "$f" | grep -o '\.[a-z]*$')
  old="/tmp/headv/old$ext"
  if git show HEAD:"$f" > "$old" 2>/dev/null; then
    out=$(python3 tools/check_comments_only.py "$old" "$f" 2>&1 | head -1)
    printf '%-52s %s\n' "$f" "$out"
    case "$out" in OK*) ;; *) fail=1;; esac
  fi
done
echo '----'
if [ $fail -eq 0 ]; then echo 'ALL FILES: comment-only'; else echo 'SOME FILES FAILED'; fi