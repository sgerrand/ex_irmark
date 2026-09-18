# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Elixir library (`:irmark`, module `IRmark`) that makes the HMRC IRmark: a hash put in the `<IRheader>` of GovTalk tax submissions. It proves which document the taxpayer sent. The spec is `generic-irmark-specification-v1-2.pdf` at the repo root. Read it with `pdftotext -layout generic-irmark-specification-v1-2.pdf -`.

## Commands

```bash
mix deps.get
mix compile --warnings-as-errors
mix test --warnings-as-errors                 # CI runs with this flag
mix test test/i_rmark_test.exs:7              # single test by line
mix format --check-formatted                  # CI lint step
```

The CI matrix covers Elixir 1.14–1.18 and OTP 24–27 (see `.github/workflows/ci.yml`). Do not use language features newer than Elixir 1.14.

## How the IRmark is built (from the spec)

1. Take the `<Body>` of the `GovTalkMessage` and leave out the `<IRmark>` element.
2. Canonicalise it (C14N).
3. Hash it with SHA-1 (20 bytes).
4. Base64-encode the hash → 28 chars, ending in one `=`. Put this in `<IRmark Type="generic">`.
5. Base32-encode the hash → 32 uppercase chars, no padding. This form is for screen and print.

HMRC error 2021 means the IRmark does not match. Error 2022 means it is missing or in the wrong place.

## Code layout

All code is in `lib/i_rmark.ex`. There are three separate public steps: `c14n/1` (uses the `xmerl_c14n` dep), `digest/1` (`:crypto.hash(:sha, _)`) and `encode/1`. Nothing joins them yet. There is no code to take out `<Body>` or remove `<IRmark>`, no base32 output, and no insert or verify helpers.

Quirks to know before you change anything:
- `c14n/1` also strips whitespace between tags (`>\s+<` → `><`). This is not part of standard C14N. It changes the hash, so any change here needs a test against a real HMRC sample.
- `c14n/1` parses the XML itself with `:xmerl_scan` in quiet mode, then passes the parsed document to `XmerlC14n.canonicalize/1`. It does this because malformed XML makes `:xmerl_scan` exit, and `XmerlC14n` does not catch that exit. Parse errors come back as `{:error, {:invalid_xml, reason}}`.
- `encode/1` only accepts a 20-byte digest. Any other input returns `{:error, :invalid_digest}`.
- Doctests run via `doctest IRmark` in the test file, so `iex>` examples in `@doc` are real tests.
