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

## How the IRmark is built

1. Take the `<Body>` of the `GovTalkMessage` and leave out the `<IRmark>` element.
2. Canonicalise it with **exclusive** C14N, leaving out comments. Namespaces declared outside `<Body>` still apply inside it.
3. Hash it with SHA-1 (20 bytes).
4. Base64-encode the hash → 28 chars, ending in one `=`. Put this in `<IRmark Type="generic">`.
5. Base32-encode the hash → 32 uppercase chars, no padding. This form is for screen and print.

The spec only says "C14N". The details in step 2 come from HMRC's own code (`IrMarkProcessor.scala` in `hmrc/construction-industry-scheme`) and were checked against real submissions. Whitespace between tags is part of the hash. Do not strip or reformat it.

HMRC error 2021 means the IRmark does not match. Error 2022 means it is missing or in the wrong place.

## Code layout

All code is in `lib/i_rmark.ex`. `generate/1` runs the whole pipeline and returns `%{base64: _, base32: _}`. It uses the public steps `c14n/1` (uses the `xmerl_c14n` dep), `digest/1` (`:crypto.hash(:sha, _)`), `encode/1` (base64, for the submission) and `encode32/1` (base32, for screen and print). `verify/1` checks the IRmark already in a document (errors match HMRC 2021 and 2022). `insert/2` writes an IRmark into `<IRheader>`.

`test/fixtures/hmrc_cis_return.xml` is HMRC's own test vector (Apache-2.0). Any change to parsing or canonicalisation must keep it passing.

Quirks to know before you change anything:
- The XML is parsed with `:xmerl_scan` in quiet mode, then the parsed tree goes to `XmerlC14n.canonicalize/2`. This is because malformed XML makes `:xmerl_scan` exit, and `XmerlC14n` does not catch that exit. Parse errors come back as `{:error, {:invalid_xml, reason}}`. A leading byte order mark is removed first, because `:xmerl_scan` rejects it. The XML is passed to `:xmerl_scan.string/2` as UTF-8 bytes (`:binary.bin_to_list/1`), not characters, because it decodes UTF-8 itself. Passing characters breaks on any non-ASCII text.
- `XmerlC14n` wrongly escapes tabs in text as `&#x9;`. `unescape_text_tabs/1` turns them back into literal tabs, but only outside tags, because tabs in attribute values must stay escaped. Remove this once [DoggettCK/xmerl_c14n#3](https://github.com/DoggettCK/xmerl_c14n/issues/3) is fixed and the dependency is updated.
- `generate/1` only removes `<IRmark>` elements that are direct children of `<IRheader>`. Whitespace around the removed element stays, as it does in HMRC's code.
- `encode/1` and `encode32/1` only accept a 20-byte digest. Any other input returns `{:error, :invalid_digest}`.
- `insert/2` edits the original text with regexes, not the parsed tree, because writing the tree back out would change other bytes and so the IRmark. Regex positions are byte offsets, so split with `binary_part/3`, never `String.split_at/2`. It adds no whitespace, because whitespace is part of the hash. After editing, it parses the result and checks the `<Body>` hash is unchanged and the new value reads back. If that check fails it returns `{:error, :insert_failed}`.
- Doctests run via `doctest IRmark` in the test file, so `iex>` examples in `@doc` are real tests.

## Releases

Releases are automated in two workflows:

- `.github/workflows/release.yml` runs release-please through `release-mate/action` on every push to `main`. It opens or updates a release PR. Merging that PR tags the release and publishes a GitHub Release.
- `.github/workflows/publish.yml` runs when a GitHub Release is published. It checks out the tag and pushes the package and docs to Hex.

The publish workflow only starts because release-mate creates the release with a GitHub App token. A release created with `GITHUB_TOKEN` does not trigger other workflows.

- Commit messages must be Conventional Commits. release-please uses them for the version bump and the changelog.
- Do not edit the version in `mix.exs` or `CHANGELOG.md` by hand. release-please owns both.
- `release-please-config.json` sets `initial-version` to `0.1.0`. Without it the first release would be `1.0.0`.
- Secrets needed: `RELEASE_MATE_CLIENT_ID`, `RELEASE_MATE_PRIVATE_KEY` and `HEX_API_KEY`.
