defmodule IRmark do
  @moduledoc """
  Generate the HMRC IRmark for a GovTalk submission.

  The IRmark is a SHA-1 hash of the canonicalised `<Body>` of the
  `GovTalkMessage`, leaving out the `<IRmark>` element itself. Use
  `generate/1` to calculate it in one step.
  """

  require Record

  Record.defrecordp(
    :xmlElement,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  @doc """
  Generate the IRmark for a GovTalk submission.

  Takes the `<Body>` of the `GovTalkMessage`, removes the `<IRmark>` element
  from `<IRheader>` if present, canonicalises it and hashes it.

  Returns the base 64 form, which goes in the submission, and the base 32
  form, which is for viewing on screen and printing.

  Returns `{:error, :body_not_found}` if the root element has no `<Body>`
  child, or the same errors as `c14n/1`.
  """
  @spec generate(xml :: String.t()) ::
          {:ok, %{base64: String.t(), base32: String.t()}} | {:error, term()}
  def generate(xml) when is_binary(xml) do
    with {:ok, document} <- parse(xml),
         {:ok, body} <- find_body(document),
         {:ok, canonical} <- canonicalize(remove_irmark(body)),
         {:ok, digest} <- digest(canonical),
         {:ok, base64} <- encode(digest),
         {:ok, base32} <- encode32(digest) do
      {:ok, %{base64: base64, base32: base32}}
    end
  end

  @doc """
  Canonicalise the XML document using exclusive XML canonicalisation,
  leaving out comments.

  Returns `{:error, {:invalid_xml, reason}}` if the document cannot be
  parsed, or `{:error, {:failed_canonicalization, reason}}` if it cannot be
  canonicalised.
  """
  @spec c14n(xml :: String.t()) :: {:ok, String.t()} | {:error, term()}
  def c14n(xml) when is_binary(xml) do
    with {:ok, document} <- parse(xml) do
      canonicalize(document)
    end
  end

  defp parse(xml) do
    {document, _rest} =
      xml
      |> String.replace_prefix("\uFEFF", "")
      |> :binary.bin_to_list()
      |> :xmerl_scan.string(quiet: true, namespace_conformant: true, document: true)

    {:ok, document}
  catch
    :exit, {:fatal, reason} -> {:error, {:invalid_xml, reason}}
  end

  defp canonicalize(node) do
    with {:ok, canonical} <- XmerlC14n.canonicalize(node, false) do
      {:ok, unescape_text_tabs(canonical)}
    end
  end

  # XmerlC14n escapes tabs in text as "&#x9;", but canonical XML keeps them
  # as literal tabs. Tabs in attribute values must stay escaped, so skip
  # over whole tags (attribute values are always double quoted).
  # Remove once https://github.com/DoggettCK/xmerl_c14n/issues/3 is fixed.
  defp unescape_text_tabs(canonical) do
    Regex.replace(~r/<(?:[^>"]|"[^"]*")*>|&#x9;/, canonical, fn
      "&#x9;" -> "\t"
      tag -> tag
    end)
  end

  defp find_body({:xmlDocument, content}) do
    case Enum.find(content, &Record.is_record(&1, :xmlElement)) do
      nil -> {:error, :body_not_found}
      root -> find_body(root)
    end
  end

  defp find_body(root) do
    root
    |> xmlElement(:content)
    |> Enum.find(&element?(&1, "Body"))
    |> case do
      nil -> {:error, :body_not_found}
      body -> {:ok, body}
    end
  end

  defp remove_irmark(element) do
    content =
      element
      |> xmlElement(:content)
      |> Enum.reject(&(element?(element, "IRheader") and element?(&1, "IRmark")))
      |> Enum.map(fn child ->
        if Record.is_record(child, :xmlElement), do: remove_irmark(child), else: child
      end)

    xmlElement(element, content: content)
  end

  defp element?(node, local_name) do
    Record.is_record(node, :xmlElement) and local_name(node) == local_name
  end

  defp local_name(element) do
    case xmlElement(element, :nsinfo) do
      {_prefix, local} -> to_string(local)
      _ -> to_string(xmlElement(element, :name))
    end
  end

  @doc """
  Generate a 160-bit binary secure hash.

  ## Examples

      iex> IRmark.digest("1234567890abcdefghijklmnopqrstuvwxyz")
      {:ok, <<84, 113, 213, 228, 233, 29, 12, 13, 135, 36, 157, 88, 115, 215, 252, 181, 161, 65, 165, 130>>}
  """
  @spec digest(input :: binary()) :: {:ok, <<_::160>>}
  def digest(input) when is_binary(input) do
    result = :crypto.hash(:sha, input)

    {:ok, result}
  end

  @doc """
  Encode a 160-bit digest using base 64 to produce a 28 character
  string.

  Returns `{:error, :invalid_digest}` if the input is not 20 bytes long.

  ## Examples

      iex> {:ok, digest} = IRmark.digest("1234567890abcdefghijklmnopqrstuvwxyz")
      iex> IRmark.encode(digest)
      {:ok, "VHHV5OkdDA2HJJ1Yc9f8taFBpYI="}

      iex> IRmark.encode("not a digest")
      {:error, :invalid_digest}
  """
  @spec encode(digest :: binary()) :: {:ok, String.t()} | {:error, :invalid_digest}
  def encode(<<_::160>> = digest), do: {:ok, Base.encode64(digest)}
  def encode(_), do: {:error, :invalid_digest}

  @doc """
  Encode a 160-bit digest using base 32 to produce a 32 character
  uppercase string for viewing on screen and printing.

  Use `encode/1` for the value placed in the submission.

  Returns `{:error, :invalid_digest}` if the input is not 20 bytes long.

  ## Examples

      iex> {:ok, digest} = IRmark.digest("1234567890abcdefghijklmnopqrstuvwxyz")
      iex> IRmark.encode32(digest)
      {:ok, "KRY5LZHJDUGA3BZETVMHHV74WWQUDJMC"}

      iex> IRmark.encode32("not a digest")
      {:error, :invalid_digest}
  """
  @spec encode32(digest :: binary()) :: {:ok, String.t()} | {:error, :invalid_digest}
  def encode32(<<_::160>> = digest), do: {:ok, Base.encode32(digest)}
  def encode32(_), do: {:error, :invalid_digest}
end
