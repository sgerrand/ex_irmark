defmodule IRmarkTest do
  use ExUnit.Case, async: true

  doctest IRmark

  @hmrc_cis_return File.read!("test/fixtures/hmrc_cis_return.xml")

  describe "generate/1" do
    test "matches the IRmark HMRC's own implementation produces" do
      assert IRmark.generate(@hmrc_cis_return) ==
               {:ok,
                %{
                  base64: "tpwOaKfCHJDirqJn31ceHrX1XYc=",
                  base32: "W2OA42FHYIOJBYVOUJT56VY6D227KXMH"
                }}
    end

    test "ignores the value of an existing IRmark" do
      changed =
        String.replace(
          @hmrc_cis_return,
          "tpwOaKfCHJDirqJn31ceHrX1XYc=",
          "AAAAAAAAAAAAAAAAAAAAAAAAAAA="
        )

      assert IRmark.generate(changed) == IRmark.generate(@hmrc_cis_return)
    end

    test "gives the same result when the IRmark element is missing" do
      without_irmark =
        String.replace(
          @hmrc_cis_return,
          ~r/<IRmark Type="generic">[^<]*<\/IRmark>/,
          ""
        )

      refute without_irmark == @hmrc_cis_return
      assert IRmark.generate(without_irmark) == IRmark.generate(@hmrc_cis_return)
    end

    test "only hashes the Body" do
      changed =
        String.replace(@hmrc_cis_return, "<Class>IR-CIS-CIS300MR</Class>", "<Class>X</Class>")

      assert IRmark.generate(changed) == IRmark.generate(@hmrc_cis_return)
    end

    test "changes when the Body changes" do
      changed =
        String.replace(
          @hmrc_cis_return,
          "<NilReturn>yes</NilReturn>",
          "<NilReturn>no</NilReturn>"
        )

      refute IRmark.generate(changed) == IRmark.generate(@hmrc_cis_return)
    end

    test "only removes IRmark elements inside IRheader" do
      changed = String.replace(@hmrc_cis_return, "<NilReturn>", "<IRmark/><NilReturn>")

      refute IRmark.generate(changed) == IRmark.generate(@hmrc_cis_return)
    end

    test "uses namespaces declared outside the Body" do
      inherited =
        ~s(<GovTalkMessage xmlns="urn:envelope" xmlns:x="urn:x"><Body><x:a>1</x:a></Body></GovTalkMessage>)

      local =
        ~s(<GovTalkMessage xmlns="urn:envelope"><Body><x:a xmlns:x="urn:x">1</x:a></Body></GovTalkMessage>)

      assert IRmark.generate(inherited) == IRmark.generate(local)
    end

    test "returns an error when there is no Body" do
      assert IRmark.generate(~s(<GovTalkMessage><Header/></GovTalkMessage>)) ==
               {:error, :body_not_found}
    end

    test "returns an error for malformed XML" do
      assert {:error, {:invalid_xml, _reason}} = IRmark.generate("<GovTalkMessage>")
    end
  end

  @hmrc_irmark "tpwOaKfCHJDirqJn31ceHrX1XYc="

  defp envelope(header) do
    ~s(<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope"><Header/><Body>) <>
      ~s(<IRenvelope xmlns="urn:ir"><IRheader>#{header}</IRheader><Data>1</Data></IRenvelope>) <>
      ~s(</Body></GovTalkMessage>)
  end

  defp irmark_for(xml) do
    {:ok, %{base64: irmark}} = IRmark.generate(xml)
    irmark
  end

  describe "verify/1" do
    test "accepts HMRC's test vector" do
      assert IRmark.verify(@hmrc_cis_return) == :ok
    end

    test "reports a wrong IRmark" do
      wrong = String.replace(@hmrc_cis_return, @hmrc_irmark, "AAAAAAAAAAAAAAAAAAAAAAAAAAA=")

      assert IRmark.verify(wrong) ==
               {:error,
                {:irmark_mismatch,
                 %{expected: @hmrc_irmark, actual: "AAAAAAAAAAAAAAAAAAAAAAAAAAA="}}}
    end

    test "reports a changed Body" do
      changed =
        String.replace(
          @hmrc_cis_return,
          "<NilReturn>yes</NilReturn>",
          "<NilReturn>no</NilReturn>"
        )

      assert {:error, {:irmark_mismatch, %{actual: @hmrc_irmark}}} = IRmark.verify(changed)
    end

    test "does not trim the IRmark value" do
      padded = String.replace(@hmrc_cis_return, @hmrc_irmark, " #{@hmrc_irmark} ")

      assert {:error, {:irmark_mismatch, %{actual: " " <> _}}} = IRmark.verify(padded)
    end

    test "reports a missing IRmark" do
      assert IRmark.verify(envelope("<Sender>Company</Sender>")) == {:error, :irmark_not_found}
    end

    test "reports an empty IRmark as a mismatch" do
      assert {:error, {:irmark_mismatch, %{actual: ""}}} =
               IRmark.verify(envelope(~s(<IRmark Type="generic"/>)))
    end

    test "returns errors from generate/1" do
      assert IRmark.verify(~s(<GovTalkMessage/>)) == {:error, :body_not_found}
      assert {:error, {:invalid_xml, _}} = IRmark.verify("<GovTalkMessage>")
    end
  end

  describe "insert/2" do
    test "replaces an existing IRmark" do
      xml = String.replace(@hmrc_cis_return, @hmrc_irmark, "")

      assert {:ok, updated} = IRmark.insert(xml, @hmrc_irmark)
      assert updated == @hmrc_cis_return
    end

    test "replaces an empty IRmark element" do
      xml = envelope(~s(<IRmark Type="generic"/><Sender>Company</Sender>))
      irmark = irmark_for(xml)

      assert IRmark.insert(xml, irmark) ==
               {:ok,
                envelope(~s(<IRmark Type="generic">#{irmark}</IRmark><Sender>Company</Sender>))}
    end

    test "adds the IRmark before Sender" do
      xml = envelope("<Keys/><Sender>Company</Sender>")
      irmark = irmark_for(xml)

      assert IRmark.insert(xml, irmark) ==
               {:ok,
                envelope(
                  ~s(<Keys/><IRmark Type="generic">#{irmark}</IRmark><Sender>Company</Sender>)
                )}
    end

    test "adds the IRmark at the end of IRheader when there is no Sender" do
      xml = envelope("<Keys/>")
      irmark = irmark_for(xml)

      assert IRmark.insert(xml, irmark) ==
               {:ok, envelope(~s(<Keys/><IRmark Type="generic">#{irmark}</IRmark>))}
    end

    test "gives a document that verify/1 accepts" do
      xml = envelope("<Keys/><Sender>Company</Sender>")

      assert {:ok, updated} = IRmark.insert(xml, irmark_for(xml))
      assert IRmark.verify(updated) == :ok
    end

    test "keeps the namespace prefix of IRheader" do
      xml =
        ~s(<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope"><Body>) <>
          ~s(<ir:IRenvelope xmlns:ir="urn:ir"><ir:IRheader><ir:Sender>Company</ir:Sender></ir:IRheader></ir:IRenvelope>) <>
          ~s(</Body></GovTalkMessage>)

      irmark = irmark_for(xml)

      assert {:ok, updated} = IRmark.insert(xml, irmark)
      assert updated =~ ~s(<ir:IRmark Type="generic">#{irmark}</ir:IRmark><ir:Sender>)
      assert IRmark.verify(updated) == :ok
    end

    test "handles multi-byte characters before the IRheader" do
      xml =
        ~s(<GovTalkMessage xmlns="http://www.govtalk.gov.uk/CM/envelope">) <>
          ~s(<Header><Name>Zoë Brontë – £100</Name></Header><Body>) <>
          ~s(<IRenvelope xmlns="urn:ir"><IRheader><Sender>Café</Sender></IRheader></IRenvelope>) <>
          ~s(</Body></GovTalkMessage>)

      assert {:ok, updated} = IRmark.insert(xml, irmark_for(xml))
      assert IRmark.verify(updated) == :ok
    end

    test "rejects a value that is not a base 64 digest" do
      assert IRmark.insert(@hmrc_cis_return, "not an irmark") == {:error, :invalid_irmark}

      assert IRmark.insert(@hmrc_cis_return, Base.encode64("too short")) ==
               {:error, :invalid_irmark}
    end

    test "returns an error when there is no IRheader" do
      xml = ~s(<GovTalkMessage><Body><Data/></Body></GovTalkMessage>)

      assert IRmark.insert(xml, @hmrc_irmark) == {:error, :irheader_not_found}
    end

    test "returns errors from generate/1" do
      assert IRmark.insert(~s(<GovTalkMessage/>), @hmrc_irmark) == {:error, :body_not_found}
    end
  end

  describe "c14n/1" do
    test "transforms XML document into canonical format" do
      source =
        ~s(<!DOCTYPE doc [<!ATTLIST e9 attr CDATA "default">]>) <>
          ~s(<doc>) <>
          ~s(<e1   />) <>
          ~s(<e2   ></e2>) <>
          ~s(<e3   name = "elem3"   id="elem3"   />) <>
          ~s(<e4   name="elem4"   id="elem4"   ></e4>) <>
          ~s(<e5 a:attr="out" b:attr="sorted" attr2="all" attr="I'm"
            xmlns:b="http://www.ietf.org"
            xmlns:a="http://www.w3.org"
            xmlns="http://example.org"/>) <>
          ~s(<e6 xmlns="" xmlns:a="http://www.w3.org">) <>
          ~s(<e7 xmlns="http://www.ietf.org">) <>
          ~s(<e8 xmlns="" xmlns:a="http://www.w3.org">) <>
          ~s(<e9 xmlns="" xmlns:a="http://www.ietf.org"/>) <>
          ~s(</e8></e7></e6></doc>)

      expected =
        ~s(<doc><e1></e1><e2></e2><e3 id="elem3" name="elem3"></e3><e4 id="elem4" name="elem4"></e4><e5 xmlns="http://example.org" xmlns:a="http://www.w3.org" xmlns:b="http://www.ietf.org" attr="I'm" attr2="all" b:attr="sorted" a:attr="out"></e5><e6><e7 xmlns="http://www.ietf.org"><e8 xmlns=""><e9></e9></e8></e7></e6></doc>)

      assert IRmark.c14n(source) == {:ok, expected}
    end

    test "keeps whitespace between elements" do
      source = "<a>\n  <b> </b>\n</a>"

      assert IRmark.c14n(source) == {:ok, source}
    end

    test "keeps tabs in text as literal tabs" do
      assert IRmark.c14n("<a>\t<b>x\ty</b></a>") == {:ok, "<a>\t<b>x\ty</b></a>"}
    end

    test "keeps tabs in attribute values escaped" do
      assert IRmark.c14n(~s(<a b="x&#9;y" c="&gt;">\t</a>)) ==
               {:ok, ~s(<a b="x&#x9;y" c=">">\t</a>)}
    end

    test "leaves out comments" do
      assert IRmark.c14n("<a><!-- note -->b</a>") == {:ok, "<a>b</a>"}
    end

    test "keeps non-ASCII characters" do
      source = ~s(<a b="é">Zoë £100 – 日本</a>)

      assert IRmark.c14n(source) == {:ok, source}
    end

    test "ignores a leading byte order mark" do
      assert IRmark.c14n("\uFEFF<a>b</a>") == {:ok, "<a>b</a>"}
    end

    test "returns an error for malformed XML" do
      assert {:error, {:invalid_xml, _reason}} = IRmark.c14n("<a><b>")
    end

    test "returns an error for non-XML input" do
      assert {:error, {:invalid_xml, _reason}} = IRmark.c14n("not xml")
    end

    test "returns an error for an undeclared namespace prefix" do
      assert {:error, {:invalid_xml, _reason}} = IRmark.c14n(~s(<a x:y="1"/>))
    end
  end

  describe "encode/1" do
    test "produces a 28 character string for a SHA-1 digest" do
      {:ok, digest} = IRmark.digest("")

      assert {:ok, encoded} = IRmark.encode(digest)
      assert String.length(encoded) == 28
    end

    test "rejects input that is not 20 bytes long" do
      assert IRmark.encode(<<0::152>>) == {:error, :invalid_digest}
      assert IRmark.encode(<<0::168>>) == {:error, :invalid_digest}
    end
  end

  describe "encode32/1" do
    test "produces a 32 character uppercase string with no padding" do
      {:ok, digest} = IRmark.digest("")

      assert {:ok, encoded} = IRmark.encode32(digest)
      assert String.length(encoded) == 32
      assert encoded =~ ~r/\A[A-Z2-7]{32}\z/
    end

    test "encodes the same digest as encode/1" do
      {:ok, digest} = IRmark.digest("")
      {:ok, base64} = IRmark.encode(digest)
      {:ok, base32} = IRmark.encode32(digest)

      assert Base.decode64!(base64) == Base.decode32!(base32)
    end

    test "rejects input that is not 20 bytes long" do
      assert IRmark.encode32(<<0::152>>) == {:error, :invalid_digest}
      assert IRmark.encode32(<<0::168>>) == {:error, :invalid_digest}
    end
  end
end
