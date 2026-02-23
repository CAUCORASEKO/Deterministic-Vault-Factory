#!/bin/bash
set -e

OUTPUT="reports/full-report.md"
PDF="reports/full-report.pdf"

cat \
reports/master.md \
reports/spec.md \
reports/formal.md \
reports/risk.md \
reports/readiness.md \
> $OUTPUT

pandoc $OUTPUT -o $PDF

echo "PDF generated at $PDF"