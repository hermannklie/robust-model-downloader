# robust-model-downloader

A robust shell script for downloading large Hugging Face models on
unreliable connections.

Built for situations like: huge models split across hundreds of shards,
wobbly internet (mobile hotspots, hotel WiFi, low-bandwidth regions),
and rate-limit-sensitive providers. Resume-safe across script restarts,
file-level resume via `wget -c`, randomized inter-shard delay to avoid
triggering rate limits.

Originally written for downloading Mistral-Large-3 (272 shards × ~5 GB
each) over an unstable connection in Africa.

---

## Quick start

```bash
git clone https://github.com/hermannklie/robust-model-downloader.git
cd robust-model-downloader
chmod +x hf-shard-download.sh

export HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxx   # from https://huggingface.co/settings/tokens

./hf-shard-download.sh \
    --repo mistralai/Mistral-Large-3-675B-Base-2512 \
    --pattern 'consolidated-{i}-of-00272.safetensors' \
    --end 272
```

If your connection drops, just re-run the same command. The script picks
up where it left off — both at the file level (resume partial download)
and at the script level (skip already-completed shards via the log).

---

## How it's robust

| Failure mode | How the script handles it |
|---|---|
| Internet drops mid-shard | `wget -c` resumes the partial file on next run |
| Internet drops between shards | Log records completed shards; script skips them on re-run |
| Provider rate-limits you | Random delay (default 50–180s) between shards |
| ISP serves HTML block-page with HTTP 200 | After-download `file` check rejects HTML/JSON/text; renames to `.bad`; on next run shard is re-fetched fresh |
| Auth token rotated mid-job | Just export the new `HF_TOKEN` and re-run; no state corruption |
| Disk fills up | Script aborts cleanly mid-shard, partial file remains for resume |
| Power outage / OS crash | Re-run; log file determines what's done |

The script does *not*:
- parallelize downloads (intentional — one shard at a time keeps the
  rate-limit dance polite, and unreliable links break worse with parallel
  streams)
- verify cryptographic checksums (HF doesn't expose them per-shard
  reliably; do `sha256sum -c` against the model's manifest if you want
  bit-level guarantees)
- decompress / unpack anything (it's a downloader, not a model loader)
- attempt sophisticated network workarounds (no parallel streams, no
  TLS-fingerprint manipulation, no HTTP/2 tricks). **This is deliberate.**
  In adversarial networks the threat is two-sided:
  (a) outbound — your ISP's DPI flags known circumvention patterns;
  (b) inbound — the destination CDN edge (Cloudflare et al.) applies
  harder default rules to traffic from flagged geographic ranges,
  including lower rate-limit thresholds and more frequent challenge
  pages. Any "smarter" client behaviour is doubly visible — flagged on
  both sides. The most reliable shape this script can take, on a hostile
  link from a flagged region, is plain sequential `wget -c` with a
  human-paced delay. Empirically tested from West African networks where
  the alternatives didn't survive the filters.

### Content validation (lightweight)

After each shard download, the script runs `file -b <output>` and rejects
anything that smells like an HTML block-page, JSON error, or plain text
masquerading as a binary file. On rejection the shard is renamed to
`<file>.bad` (kept for inspection if you want to see what your provider
served you), removed from the log, and re-fetched on the next run. This
catches the common "ISP serves a captive-portal HTML with HTTP 200"
failure mode that would otherwise log a 4 KB error page as a successful
5 GB shard.

---

## Configuration

All parameters work as CLI flags or environment variables. CLI takes
precedence.

| Flag | Env var | Default | Meaning |
|---|---|---|---|
| `--repo` | `HF_REPO` | (required) | HF model repo, e.g. `mistralai/Mistral-Large-3-675B-Base-2512` |
| `--pattern` | `HF_PATTERN` | (required) | Filename pattern with `{i}` placeholder |
| `--end` | `HF_END` | (required) | Last shard index (inclusive) |
| `--start` | `HF_START` | `1` | First shard index |
| `--width` | `HF_WIDTH` | `5` | Zero-padding width for `{i}` |
| `--outdir` | `HF_OUTDIR` | `.` | Where shards land |
| `--logfile` | `HF_LOGFILE` | `download.log` | Resume log (relative to outdir) |
| `--delay-min` | `HF_DELAY_MIN` | `50` | Min random delay (seconds) |
| `--delay-max` | `HF_DELAY_MAX` | `180` | Max random delay (seconds) |
| (env only) | `HF_TOKEN` | (required) | Hugging Face access token |

Example with config file:

```bash
cat > mistral-base.conf <<EOF
HF_REPO=mistralai/Mistral-Large-3-675B-Base-2512
HF_PATTERN='consolidated-{i}-of-00272.safetensors'
HF_END=272
EOF

export HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxx
./hf-shard-download.sh --config mistral-base.conf
```

---

## Security note

The script reads `HF_TOKEN` from the environment **only**. Never paste a
token directly into the script file or commit it to a repo. If you need
to persist the token across shells, put it in a sourced file outside
your project tree:

```bash
echo 'export HF_TOKEN=hf_xxxxxxxxxxxxxxxxxxxx' > ~/.hf_token
chmod 600 ~/.hf_token
# then in your shell:
source ~/.hf_token
```

If you ever suspect a token is exposed: revoke it immediately at
https://huggingface.co/settings/tokens and generate a new one.

---

## Why a shell script and not a Python tool

`huggingface-cli download` exists and is more featureful. Use it when
your connection is stable. This script is for the case when stability
itself is the problem — where you need:

- minimum dependencies (just `bash` + `wget`)
- transparent state (a single log file, plain text)
- forgiving restarts (no Python venv to maintain on a flaky link)
- ability to inspect / patch in the field with whatever editor is around

It's a tool of last-resort robustness, not a replacement for Hugging
Face's official tooling under normal conditions.

---

## License

Apache License 2.0 — see `LICENSE`.

Use freely, attribute the source, no warranty.

---

## Related

Part of the Bardo project ecosystem of local-first AI tools:
- [bardo-akten-scan](https://github.com/hermannklie/bardo-akten-scan) — local document scanning + OCR pipeline
- [text-generation-webui (Bardo fork)](https://github.com/hermannklie/text-generation-webui) — local LLM hosting with ktransformers/sglang integration
- [deliberative-alignment-base-axioms](https://github.com/hermannklie/deliberative-alignment-base-axioms) — research on Layer-0 axiom seeding
