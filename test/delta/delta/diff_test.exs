defmodule Tests.Delta.Diff do
  use Delta.Support.Case, async: false
  doctest Delta, only: [diff: 2]

  describe ".diff/2 (basic)" do
    test "insert" do
      a = [Op.insert("A")]
      b = [Op.insert("AB")]

      assert [Op.retain(1), Op.insert("B")] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "delete" do
      a = [Op.insert("AB")]
      b = [Op.insert("A")]

      assert [Op.retain(1), Op.delete(1)] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "retain" do
      a = [Op.insert("A")]
      b = [Op.insert("A")]

      assert [] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "format" do
      a = [Op.insert("A")]
      b = [Op.insert("A", %{"bold" => true})]

      assert [Op.retain(1, %{"bold" => true})] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "object attributes" do
      a = [Op.insert("A", %{"font" => %{"family" => "Helvetica", "size" => "15px"}})]
      b = [Op.insert("A", %{"font" => %{"family" => "Helvetica", "size" => "15px"}})]

      assert [] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "embed integer match" do
      a = [Op.insert(%{"embed" => 1})]
      b = [Op.insert(%{"embed" => 1})]

      assert [] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "embed integer mismatch" do
      a = [Op.insert(%{"embed" => 1})]
      b = [Op.insert(%{"embed" => 2})]

      assert [Op.delete(1), Op.insert(%{"embed" => 2})] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "embed object match" do
      a = [Op.insert(%{"image" => "http://example.com"})]
      b = [Op.insert(%{"image" => "http://example.com"})]

      assert [] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "embed object mismatch" do
      a = [Op.insert(%{"image" => %{"url" => "http://example.com", "alt" => "overwrite"}})]
      b = [Op.insert(%{"image" => %{"url" => "http://example.com"}})]

      assert [Op.delete(1), Op.insert(%{"image" => %{"url" => "http://example.com"}})] ==
               Delta.diff(a, b)

      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "embed object change" do
      a = [Op.insert(%{"image" => "http://example.com"})]
      b = [Op.insert(%{"image" => "http://example.org"})]

      assert [Op.delete(1), Op.insert(%{"image" => "http://example.org"})] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "error on non-documents" do
      a = [Op.insert("A")]
      b = [Op.retain(1), Op.insert("B")]

      assert_raise RuntimeError, fn -> Delta.diff(a, b) end
      assert_raise RuntimeError, fn -> Delta.diff(b, a) end
    end

    test "inconvenient indices" do
      a = [Op.insert("12", %{"bold" => true}), Op.insert("34", %{"italic" => true})]
      b = [Op.insert("123", %{"color" => "red"})]

      assert [
               Op.retain(2, %{"bold" => nil, "color" => "red"}),
               Op.retain(1, %{"italic" => nil, "color" => "red"}),
               Op.delete(1)
             ] == Delta.diff(a, b)

      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "combination" do
      a = [Op.insert("Bad", %{"color" => "red"}), Op.insert("cat", %{"color" => "blue"})]
      b = [Op.insert("Good", %{"bold" => true}), Op.insert("dog", %{"italic" => true})]

      # semantic cleanup simplifies this diff
      assert [
               Op.delete(6),
               Op.insert("Good", %{"bold" => true}),
               Op.insert("dog", %{"italic" => true})
             ] == Delta.diff(a, b)

      assert Delta.compose(a, Delta.diff(a, b)) == b
    end
  end

  describe ".diff/2 (custom embeds)" do
    @describetag custom_embeds: [TestEmbed]

    test "equal strings" do
      a = [Op.insert("A")]
      b = [Op.insert("A")]

      assert [] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "equal embeds" do
      a = [Op.insert(%{"delta" => [Op.insert("hello")]})]
      b = [Op.insert(%{"delta" => [Op.insert("hello")]})]

      assert [] == Delta.diff(a, b)
      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "basic embed diff" do
      a = [Op.insert(%{"delta" => [Op.insert("hello world")]})]
      b = [Op.insert(%{"delta" => [Op.insert("goodbye world")]})]

      assert [
               Op.retain(%{
                 "delta" => [
                   Op.delete(5),
                   Op.insert("goodbye")
                 ]
               })
             ] == Delta.diff(a, b)

      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    test "embed diff with attribute changes" do
      a = [
        Op.insert(
          %{"delta" => [Op.insert("hello world")]},
          %{"bold" => true, "color" => "red"}
        )
      ]

      b = [
        Op.insert(
          %{"delta" => [Op.insert("goodbye world")]},
          %{"italic" => true, "color" => "yellow"}
        )
      ]

      assert [
               Op.retain(
                 %{
                   "delta" => [
                     Op.delete(5),
                     Op.insert("goodbye")
                   ]
                 },
                 %{
                   "bold" => nil,
                   "italic" => true,
                   "color" => "yellow"
                 }
               )
             ] == Delta.diff(a, b)

      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    @tag custom_embeds: [TestEmbed, QuoteEmbed]
    test "different embeds" do
      a = [Op.insert(%{"delta" => [Op.insert("hello world")]})]
      b = [Op.insert(%{"quote" => [Op.insert("goodbye world")]})]

      assert [
               Op.delete(1),
               Op.insert(%{"quote" => [Op.insert("goodbye world")]})
             ] == Delta.diff(a, b)

      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    @tag custom_embeds: [QuoteEmbed]
    test "embeds without handler diff attributes if equal" do
      a = [Op.insert(%{"quote" => [Op.insert("hello world")]}, %{"author" => "A"})]
      b = [Op.insert(%{"quote" => [Op.insert("hello world")]}, %{"author" => "B"})]

      assert [
               Op.retain(1, %{"author" => "B"})
             ] == Delta.diff(a, b)

      assert Delta.compose(a, Delta.diff(a, b)) == b
    end

    @tag custom_embeds: [QuoteEmbed]
    test "embeds without handler replaces whole operation if different content" do
      a = [Op.insert(%{"quote" => [Op.insert("foo")]}, %{"author" => "A"})]
      b = [Op.insert(%{"quote" => [Op.insert("bar")]}, %{"author" => "B"})]

      assert [
               Op.delete(1),
               Op.insert(%{"quote" => [Op.insert("bar")]}, %{"author" => "B"})
             ] == Delta.diff(a, b)
    end

    @tag custom_embeds: [__MODULE__.CaseInsensitiveEmbed]
    test "embeds consider operations equal" do
      # Let's imagine the embed is case-insensitive
      a = [Op.insert(%{"delta" => [Op.insert("HELLO")]})]
      b = [Op.insert(%{"delta" => [Op.insert("hello")]})]

      assert [] == Delta.diff(a, b)

      # The invariant breaks for obvious reasons
      refute Delta.compose(a, Delta.diff(a, b)) == b
    end

    @tag custom_embeds: [__MODULE__.HomographEmbed]
    test "embeds consider equal inserts as different" do
      # Let's imagine the embed considers homographs as different words based on
      # `meaning` attribute
      a = [Op.insert(%{"delta" => [Op.insert("football", %{"meaning" => "american"})]})]
      b = [Op.insert(%{"delta" => [Op.insert("football", %{"meaning" => "soccer"})]})]

      assert [
               Op.delete(1),
               Op.insert(%{"delta" => [Op.insert("football", %{"meaning" => "soccer"})]})
             ] == Delta.diff(a, b)

      assert Delta.compose(a, Delta.diff(a, b)) == b
    end
  end

  defmodule CaseInsensitiveEmbed do
    def name, do: "delta"

    def diff(%{"insert" => %{"delta" => [%{"insert" => "HELLO"}]}}, %{
          "insert" => %{"delta" => [%{"insert" => "hello"}]}
        }) do
      []
    end
  end

  defmodule HomographEmbed do
    def name, do: "delta"

    def diff(_, b) do
      [Delta.Op.delete(1), b]
    end
  end
end
