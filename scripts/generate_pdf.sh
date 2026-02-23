#!/usr/bin/env bash
set -e

OUTPUT="reports/full-report.md"
PDF="reports/full-report.pdf"
TMP_TXT="$(mktemp /tmp/full-report.XXXXXX).txt"

cat \
  reports/master.md \
  reports/spec.md \
  reports/formal.md \
  reports/risk.md \
  reports/readiness.md \
  > "$OUTPUT"

if pandoc "$OUTPUT" -o "$PDF" 2>/dev/null; then
  :
else
  pandoc "$OUTPUT" -t plain -o "$TMP_TXT"
  cupsfilter "$TMP_TXT" > "$PDF"
fi

rm -f "$TMP_TXT"
echo "PDF generated at $PDF"
