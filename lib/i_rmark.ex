defmodule IRmark do
  @moduledoc """
  Documentation for `IRmark`.
  """

  @doc """
  Canonicalise the XML document.
  """
  @spec c14n(xml :: String.t()) :: {:ok, binary()}
  def c14n(xml) when is_binary(xml) do
    case result =
           xml
           |> XmerlC14n.canonicalize!()
           |> String.replace(~r/>\s+</, "><") do
      nil -> :error
      _ -> {:ok, result}
    end
  end

  @doc """
  Generate a 160-bit binary secure hash.

  ## Examples

      iex> IRmark.digest("1234567890abcdefghijklmnopqrstuvwxyz")
      {:ok, <<84, 113, 213, 228, 233, 29, 12, 13, 135, 36, 157, 88, 115, 215, 252, 181, 161, 65, 165, 130>>}
  """
  @spec digest(input :: binary()) :: {:ok, <<_::20>>}
  def digest(input) when is_binary(input) do
    result = :crypto.hash(:sha, input)

    {:ok, result}
  end

  @doc """
  Encode the binary data using base 64 to produce a 28 character
  string.

  ## Examples

      iex> IRmark.encode("1234567890abcdefghijklmnopqrstuvwxyz")
      {:ok, "MTIzNDU2Nzg5MGFiY2RlZmdoaWpr"}
  """
  def encode(data) do
    result =
      data
      |> Base.encode64()
      |> String.slice(0, 28)

    {:ok, result}
  end
end
