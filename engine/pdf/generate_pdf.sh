#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
export TZ=UTC
export SOURCE_DATE_EPOCH=1771912800

OUTPUT_DIR="engine/output"
INPUT_MD="${OUTPUT_DIR}/final_report.md"
TMP_PDF="${OUTPUT_DIR}/_tmp_report.pdf"
OUTPUT_PDF="${OUTPUT_DIR}/final_report.pdf"

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_file() {
  [[ -f "$1" ]] || fail "Missing required file: $1"
}

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

main() {
  require_file "$INPUT_MD"

  rm -f "$TMP_PDF" "$OUTPUT_PDF"

  # Step 1 — Render with stable system fonts
  pandoc "$INPUT_MD" \
    --pdf-engine=xelatex \
    -V geometry:margin=1in \
    -V fontsize=11pt \
    -V mainfont="Helvetica" \
    -V monofont="Courier New" \
    -V date="" \
    -V author="" \
    -V title="" \
    -V subject="" \
    -V keywords="" \
    -o "$TMP_PDF"

  # Step 2 — Deterministic rewrite (NO -dUseCIEColor)
  gs -dNOPAUSE -dBATCH -dSAFER \
     -sDEVICE=pdfwrite \
     -dCompatibilityLevel=1.4 \
     -dDetectDuplicateImages=true \
     -dCompressFonts=true \
     -dSubsetFonts=true \
     -dEmbedAllFonts=true \
     -dPDFSETTINGS=/prepress \
     -dFixedMedia \
     -dDeterministicID=true \
     -sOutputFile="$OUTPUT_PDF" \
     "$TMP_PDF"

  rm -f "$TMP_PDF"

  PDF_HASH="$(hash_file "$OUTPUT_PDF")"
  printf '%s  final_report.pdf\n' "$PDF_HASH" > "${OUTPUT_PDF}.sha256"

  printf 'PDF generated: %s\n' "$OUTPUT_PDF"
  printf 'PDF SHA-256 : %s\n' "$PDF_HASH"
}

main "$@"