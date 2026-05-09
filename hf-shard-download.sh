#!/bin/bash
#
# hf-shard-download.sh — robust shard-by-shard downloader for large
# Hugging Face models on unreliable connections.
#
# Designed for situations like: large models (100+ shards),
# wobbly internet (Africa, mobile, hotel WiFi), and rate-limit-sensitive
# providers. Resume-safe, idempotent, restart-friendly.
#
# Copyright (C) 2026 Hermann Hans Klie
# SPDX-License-Identifier: Apache-2.0
#
# Usage:
#   HF_TOKEN=hf_xxxxx ./hf-shard-download.sh \
#       --repo mistralai/Mistral-Large-3-675B-Base-2512 \
#       --pattern 'consolidated-{i}-of-00272.safetensors' \
#       --start 1 --end 272 --width 5
#
#   Or with a config file:
#       ./hf-shard-download.sh --config job.conf
#
# All parameters can also be set via environment variables (HF_TOKEN,
# HF_REPO, HF_PATTERN, HF_START, HF_END, HF_WIDTH, HF_DELAY_MIN,
# HF_DELAY_MAX, HF_LOGFILE, HF_OUTDIR).
#
# Exit codes:
#   0  all shards downloaded
#   1  configuration error
#   2  authentication error
#   3  partial — some shards still missing (re-run to continue)

set -euo pipefail

# ---- Defaults ----
: "${HF_REPO:=}"
: "${HF_PATTERN:=}"
: "${HF_START:=1}"
: "${HF_END:=}"
: "${HF_WIDTH:=5}"
: "${HF_DELAY_MIN:=50}"
: "${HF_DELAY_MAX:=180}"
: "${HF_LOGFILE:=download.log}"
: "${HF_OUTDIR:=.}"
: "${HF_TOKEN:=}"

# ---- Argument parsing ----
usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

Required:
  --repo <user/model>     Hugging Face repo, e.g. mistralai/Mistral-Large-3-675B-Base-2512
  --pattern <pattern>     Filename pattern with {i} placeholder, e.g.
                          'consolidated-{i}-of-00272.safetensors'
  --end <N>               Last shard number (inclusive)

Optional:
  --start <N>             First shard number (default: 1)
  --width <N>             Zero-padding width for {i} (default: 5)
  --outdir <dir>          Output directory (default: current dir)
  --logfile <path>        Resume log (default: ./download.log)
  --delay-min <sec>       Min random delay between shards (default: 50)
  --delay-max <sec>       Max random delay between shards (default: 180)
  --config <file>         Source a shell-style config file with the above as vars
  -h, --help              This message

Authentication:
  Set HF_TOKEN environment variable. The script will refuse to run
  without it (no hardcoded tokens).

Example:
  export HF_TOKEN=hf_xxxxx
  ./hf-shard-download.sh \\
      --repo mistralai/Mistral-Large-3-675B-Base-2512 \\
      --pattern 'consolidated-{i}-of-00272.safetensors' \\
      --end 272

Resumability:
  Each successful shard is appended to the logfile. Re-running the
  script skips shards already in the log. Partial files (interrupted
  downloads) are continued via wget -c.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --repo)        HF_REPO="$2"; shift 2;;
        --pattern)     HF_PATTERN="$2"; shift 2;;
        --start)       HF_START="$2"; shift 2;;
        --end)         HF_END="$2"; shift 2;;
        --width)       HF_WIDTH="$2"; shift 2;;
        --outdir)      HF_OUTDIR="$2"; shift 2;;
        --logfile)     HF_LOGFILE="$2"; shift 2;;
        --delay-min)   HF_DELAY_MIN="$2"; shift 2;;
        --delay-max)   HF_DELAY_MAX="$2"; shift 2;;
        --config)      # shellcheck disable=SC1090
                       source "$2"; shift 2;;
        -h|--help)     usage; exit 0;;
        *)             echo "Unknown argument: $1" >&2; usage; exit 1;;
    esac
done

# ---- Validation ----
if [[ -z "$HF_TOKEN" ]]; then
    echo "Error: HF_TOKEN environment variable is not set." >&2
    echo "Get a token at https://huggingface.co/settings/tokens and run:" >&2
    echo "    export HF_TOKEN=hf_xxxxx" >&2
    exit 2
fi
if [[ -z "$HF_REPO" || -z "$HF_PATTERN" || -z "$HF_END" ]]; then
    echo "Error: --repo, --pattern, and --end are required." >&2
    usage
    exit 1
fi
if [[ "$HF_PATTERN" != *"{i}"* ]]; then
    echo "Error: pattern must contain the {i} placeholder." >&2
    exit 1
fi

mkdir -p "$HF_OUTDIR"
cd "$HF_OUTDIR"
touch "$HF_LOGFILE"

BASE_URL="https://huggingface.co/${HF_REPO}/resolve/main"
TOTAL=$((HF_END - HF_START + 1))
DONE=0
SKIPPED=0
FAILED=0

echo "Repo:      $HF_REPO"
echo "Pattern:   $HF_PATTERN"
echo "Range:     $HF_START..$HF_END (width=$HF_WIDTH)"
echo "Output:    $HF_OUTDIR"
echo "Log:       $HF_LOGFILE"
echo "Delay:     ${HF_DELAY_MIN}..${HF_DELAY_MAX}s random"
echo "─────────────────────────────────────────────────"

for i in $(seq "$HF_START" "$HF_END"); do
    INDEX=$(printf "%0${HF_WIDTH}d" "$i")
    FILE="${HF_PATTERN//\{i\}/$INDEX}"

    if grep -qFx "$FILE" "$HF_LOGFILE"; then
        echo "OK   $FILE  (already in log, skipping)"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "GET  $FILE"
    URL="${BASE_URL}/${FILE}?download=true"

    if wget -c "$URL" \
            --header="Authorization: Bearer $HF_TOKEN" \
            -O "$FILE" 2>&1 | tail -3; then
        # Content-Validierung: ISP/Provider-Filter liefern oft HTML-Block-Seiten
        # oder JSON-Error mit HTTP 200, was wget als Erfolg sieht. Hier nach
        # Empfang prüfen ob es plausibel binäre Modell-Daten sind.
        ftype=$(file -b "$FILE" 2>/dev/null)
        if [[ ! -s "$FILE" ]]; then
            echo "FAIL $FILE  (empty file — likely network-level block)"
            mv -f "$FILE" "${FILE}.bad" 2>/dev/null || rm -f "$FILE"
            FAILED=$((FAILED + 1))
        elif [[ "$ftype" == *HTML* ]] \
          || [[ "$ftype" == *XML* ]] \
          || [[ "$ftype" == *"ASCII text"* ]] \
          || [[ "$ftype" == *"UTF-8"*"text"* ]] \
          || [[ "$ftype" == *JSON* ]]; then
            echo "FAIL $FILE  (got '$ftype' — provider-filter response, not binary)"
            mv -f "$FILE" "${FILE}.bad" 2>/dev/null || rm -f "$FILE"
            FAILED=$((FAILED + 1))
        else
            echo "$FILE" >> "$HF_LOGFILE"
            echo "DONE $FILE"
            DONE=$((DONE + 1))
        fi
    else
        echo "FAIL $FILE  (re-run to continue)"
        FAILED=$((FAILED + 1))
    fi

    DELAY=$((RANDOM % (HF_DELAY_MAX - HF_DELAY_MIN + 1) + HF_DELAY_MIN))
    if [[ $i -lt $HF_END ]]; then
        echo "wait ${DELAY}s before next shard"
        sleep "$DELAY"
    fi
done

echo "─────────────────────────────────────────────────"
echo "Summary: ${DONE} downloaded, ${SKIPPED} skipped, ${FAILED} failed (of ${TOTAL})"
if [[ $FAILED -gt 0 ]]; then
    echo "Re-run the same command to continue from where it stopped."
    exit 3
fi
exit 0
