defmodule IRmark do
  @moduledoc """
  Documentation for `IRmark`.
  """

  @doc """
  Canonicalise the XML document.

  Returns `{:error, {:invalid_xml, reason}}` if the document cannot be
  parsed, or `{:error, {:failed_canonicalization, reason}}` if it cannot be
  canonicalised.
  """
  @spec c14n(xml :: String.t()) :: {:ok, String.t()} | {:error, term()}
  def c14n(xml) when is_binary(xml) do
    with {:ok, document} <- parse(xml),
         {:ok, canonical} <- XmerlC14n.canonicalize(document) do
      {:ok, String.replace(canonical, ~r/>\s+</, "><")}
    end
  end

  defp parse(xml) do
    {document, _rest} =
      xml
      |> String.to_charlist()
      |> :xmerl_scan.string(quiet: true, namespace_conformant: true, document: true)

    {:ok, document}
  catch
    :exit, {:fatal, reason} -> {:error, {:invalid_xml, reason}}
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
end
