# IRmark

An Elixir library to generate, insert and check the HMRC IRmark in GovTalk submissions.

The IRmark is a hash of the `<Body>` of a submission. HMRC uses it to prove which document a taxpayer sent. HMRC rejects a submission if the IRmark is missing (error 2022) or wrong (error 2021).

## Installation

Add `irmark` to your list of dependencies in `mix.exs`:

<!-- x-release-please-start-version -->

```elixir
def deps do
  [
    {:irmark, "~> 0.1.0"}
  ]
end
```

<!-- x-release-please-end -->

## Usage

Calculate the IRmark and put it into the submission:

```elixir
{:ok, %{base64: irmark, base32: display}} = IRmark.generate(xml)
{:ok, xml} = IRmark.insert(xml, irmark)
```

`base64` is the value that goes in the submission. `base32` is the same IRmark in a form that is easier to read. Show it on screen and on printed copies.

Check the IRmark before you send a submission:

```elixir
case IRmark.verify(xml) do
  :ok -> :ready_to_send
  {:error, :irmark_not_found} -> :missing
  {:error, {:irmark_mismatch, %{expected: expected, actual: actual}}} -> :wrong
  {:error, reason} -> {:could_not_check, reason}
end
```

The last clause catches the rest: `:body_not_found` when the document has no `<Body>`, `{:invalid_xml, reason}` when it cannot be parsed, and `{:failed_canonicalization, reason}` when it cannot be canonicalised.

`insert/2` changes nothing else in the document. Any change to the `<Body>` after you insert the IRmark, including whitespace, makes the IRmark wrong.

## How it works

1. Take the `<Body>` of the `GovTalkMessage`, leaving out the `<IRmark>` element.
2. Canonicalise it with exclusive XML canonicalisation, without comments.
3. Hash it with SHA-1.
4. Encode the hash with base 64 (28 characters) and base 32 (32 characters).

This follows HMRC's Generic IRmark specification and matches HMRC's own implementation. It is tested against HMRC's own test data.

## Documentation

Documentation is at <https://hexdocs.pm/irmark>.

## Licence

BSD 2-Clause. See [LICENSE](LICENSE).
