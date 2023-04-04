defmodule Tests.Delta do
  use Delta.Support.Case, async: true

  doctest Delta,
    only: [
      compact: 1,
      concat: 2,
      diff: 2,
      push: 2,
      size: 1,
      slice: 3,
      slice_max: 3,
      split: 3
    ]

  # NOTE: {compose, transform, invert} tests are in their
  # dedicated test suites under delta/

  describe ".slice/3" do
    test "slice across" do
      delta = [
        %{"insert" => "ABC"},
        %{"insert" => "012", "attributes" => %{bold: true}},
        %{"insert" => "DEF"}
      ]

      assert Delta.slice(delta, 1, 7) == [
               %{"insert" => "BC"},
               %{"insert" => "012", "attributes" => %{bold: true}},
               %{"insert" => "DE"}
             ]
    end

    test "slice boundaries" do
      delta = [
        %{"insert" => "ABC"},
        %{"insert" => "012", "attributes" => %{bold: true}},
        %{"insert" => "DEF"}
      ]

      assert Delta.slice(delta, 3, 3) == [
               %{"insert" => "012", "attributes" => %{bold: true}}
             ]
    end

    test "slice middle" do
      delta = [
        %{"insert" => "ABC"},
        %{"insert" => "012", "attributes" => %{bold: true}},
        %{"insert" => "DEF"}
      ]

      assert Delta.slice(delta, 4, 1) == [
               %{"insert" => "1", "attributes" => %{bold: true}}
             ]
    end

    test "slice normal emoji" do
      delta = [%{"insert" => "01🙋45"}]
      assert Delta.slice(delta, 1, 4) == [%{"insert" => "1🙋4"}]
    end

    test "slice emoji with zero width joiner" do
      delta = [%{"insert" => "01🙋‍♂️78"}]
      assert Delta.slice(delta, 1, 7) == [%{"insert" => "1🙋‍♂️7"}]
    end

    test "slice emoji with joiner and modifer" do
      delta = [%{"insert" => "01🙋🏽‍♂️90"}]
      assert Delta.slice(delta, 1, 9) == [%{"insert" => "1🙋🏽‍♂️9"}]
    end

    test "slice with 0 index" do
      delta = [Op.insert("12")]
      assert Delta.slice(delta, 0, 1) == [%{"insert" => "1"}]
    end

    test "slice insert object with 0 index" do
      delta = [Op.insert(%{"id" => "1"}), Op.insert(%{"id" => "2"})]
      assert Delta.slice(delta, 0, 1) == [%{"insert" => %{"id" => "1"}}]
    end
  end

  describe ".slice_max/3" do
    test "slice across" do
      delta = [
        %{"insert" => "ABC"},
        %{"insert" => "012", "attributes" => %{bold: true}},
        %{"insert" => "DEF"}
      ]

      assert Delta.slice_max(delta, 1, 7) == [
               %{"insert" => "BC"},
               %{"insert" => "012", "attributes" => %{bold: true}},
               %{"insert" => "DE"}
             ]
    end

    test "slice boundaries" do
      delta = [
        %{"insert" => "ABC"},
        %{"insert" => "012", "attributes" => %{bold: true}},
        %{"insert" => "DEF"}
      ]

      assert Delta.slice_max(delta, 3, 3) == [
               %{"insert" => "012", "attributes" => %{bold: true}}
             ]
    end

    test "slice middle" do
      delta = [
        %{"insert" => "ABC"},
        %{"insert" => "012", "attributes" => %{bold: true}},
        %{"insert" => "DEF"}
      ]

      assert Delta.slice_max(delta, 4, 1) == [
               %{"insert" => "1", "attributes" => %{bold: true}}
             ]
    end

    test "slice normal emoji" do
      delta = [%{"insert" => "01🙋45"}]
      assert Delta.slice_max(delta, 1, 4) == [%{"insert" => "1🙋4"}]
    end

    test "slice emoji with zero width joiner" do
      delta = [%{"insert" => "01🙋‍♂️78"}]
      assert Delta.slice_max(delta, 1, 7) == [%{"insert" => "1🙋‍♂️7"}]
    end

    test "slice emoji with joiner and modifer" do
      delta = [%{"insert" => "01🙋🏽‍♂️90"}]
      assert Delta.slice_max(delta, 1, 9) == [%{"insert" => "1🙋🏽‍♂️9"}]
    end

    test "slice with 0 index" do
      delta = [Op.insert("12")]
      assert Delta.slice_max(delta, 0, 1) == [%{"insert" => "1"}]
    end

    test "slice insert object with 0 index" do
      delta = [Op.insert(%{"id" => "1"}), Op.insert(%{"id" => "2"})]
      assert Delta.slice_max(delta, 0, 1) == [%{"insert" => %{"id" => "1"}}]
    end

    test "slice emoji: codepoint + variation selector" do
      # "01☹️345"
      delta = [%{"insert" => "01\u2639\uFE0F345"}]
      assert Delta.slice_max(delta, 1, 2) == [%{"insert" => "1"}]
      assert Delta.slice_max(delta, 1, 3) == [%{"insert" => "1\u2639\uFE0F"}]
    end

    test "slice emoji: codepoint + skin tone modifier" do
      # "01🤵🏽345"
      delta = [%{"insert" => "01\u{1F935}\u{1F3FD}345"}]
      assert Delta.slice_max(delta, 1, 2) == [%{"insert" => "1"}]
      assert Delta.slice_max(delta, 1, 3) == [%{"insert" => "1"}]
      assert Delta.slice_max(delta, 1, 4) == [%{"insert" => "1"}]
      assert Delta.slice_max(delta, 1, 5) == [%{"insert" => "1\u{1F935}\u{1F3FD}"}]
    end

    test "slice emoji: codepoint + ZWJ + codepoint" do
      # "01👨‍🏭345"
      delta = [%{"insert" => "01\u{1F468}\u200D\u{1F3ED}345"}]
      assert Delta.slice_max(delta, 1, 2) == [%{"insert" => "1"}]
      assert Delta.slice_max(delta, 1, 3) == [%{"insert" => "1"}]
      assert Delta.slice_max(delta, 1, 4) == [%{"insert" => "1"}]
      assert Delta.slice_max(delta, 1, 5) == [%{"insert" => "1"}]
      assert Delta.slice_max(delta, 1, 6) == [%{"insert" => "1\u{1F468}\u200D\u{1F3ED}"}]
    end

    test "slice emoji: flags" do
      # "01🇦🇺345"
      delta = [%{"insert" => "01\u{1F1E6}\u{1F1FA}345"}]
      assert Delta.slice_max(delta, 1, 2) == [%{"insert" => "1"}]
      # "1🇦"
      assert Delta.slice_max(delta, 1, 3) == [%{"insert" => "1\u{1F1E6}"}]
      # "1🇦"
      assert Delta.slice_max(delta, 1, 4) == [%{"insert" => "1\u{1F1E6}"}]
      # "1🇦🇺"
      assert Delta.slice_max(delta, 1, 5) == [%{"insert" => "1\u{1F1E6}\u{1F1FA}"}]
    end

    test "slice emoji: tag sequence" do
      # "01🏴󠁧󠁢󠁳󠁣󠁴󠁿345"
      delta = [
        %{"insert" => "01\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}345"}
      ]

      for len <- 2..14 do
        assert Delta.slice_max(delta, 1, len) == [%{"insert" => "1"}]
      end

      assert Delta.slice_max(delta, 1, 15) == [
               %{"insert" => "1\u{1F3F4}\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}"}
             ]
    end

    test "slice complex emoji" do
      # "01🚵🏻‍♀️345"
      delta = [%{"insert" => "01\u{1F6B5}\u{1F3FB}\u{200D}\u{2640}\u{FE0F}345"}]

      for len <- 2..7 do
        assert Delta.slice_max(delta, 1, len) == [%{"insert" => "1"}]
      end

      assert Delta.slice_max(delta, 1, 8) == [
               %{"insert" => "1\u{1F6B5}\u{1F3FB}\u{200D}\u{2640}\u{FE0F}"}
             ]
    end
  end

  describe ".push/2" do
    test "push merge" do
      delta =
        []
        |> Delta.push(Op.insert("Hello"))
        |> Delta.push(Op.insert(" World!"))

      assert(delta == [%{"insert" => "Hello World!"}])
    end

    test "push redundant" do
      delta =
        []
        |> Delta.push(Op.insert("Hello"))
        |> Delta.push(Op.retain(0))

      assert(delta == [%{"insert" => "Hello"}])
    end

    @tag skip: true
    test "insert after delete" do
      flunk("implement this")
    end
  end

  describe ".diff/2" do
    test "insert" do
      a = [Op.insert("A")]
      b = [Op.insert("AB")]

      assert [Op.retain(1), Op.insert("B")] == Delta.diff(a, b)
    end

    test "delete" do
      a = [Op.insert("AB")]
      b = [Op.insert("A")]

      assert [Op.retain(1), Op.delete(1)] == Delta.diff(a, b)
    end

    test "retain" do
      a = [Op.insert("A")]
      b = [Op.insert("A")]

      assert [] == Delta.diff(a, b)
    end

    test "format" do
      a = [Op.insert("A")]
      b = [Op.insert("A", %{"bold" => true})]

      assert [Op.retain(1, %{"bold" => true})] == Delta.diff(a, b)
    end

    test "object attributes" do
      a = [Op.insert("A", %{"font" => %{"family" => "Helvetica", "size" => "15px"}})]
      b = [Op.insert("A", %{"font" => %{"family" => "Helvetica", "size" => "15px"}})]

      assert [] == Delta.diff(a, b)
    end

    test "embed integer match" do
      a = [Op.insert(%{"embed" => 1})]
      b = [Op.insert(%{"embed" => 1})]

      assert [] == Delta.diff(a, b)
    end

    test "embed integer mismatch" do
      a = [Op.insert(%{"embed" => 1})]
      b = [Op.insert(%{"embed" => 2})]

      assert [Op.delete(1), Op.insert(%{"embed" => 2})] == Delta.diff(a, b)
    end

    test "embed object match" do
      a = [Op.insert(%{"image" => "http://example.com"})]
      b = [Op.insert(%{"image" => "http://example.com"})]

      assert [] == Delta.diff(a, b)
    end

    test "embed object mismatch" do
      a = [Op.insert(%{"image" => "http://example.com", "alt" => "overwrite"})]
      b = [Op.insert(%{"image" => "http://example.com"})]

      assert [Op.delete(1), Op.insert(%{"image" => "http://example.com"})] == Delta.diff(a, b)
    end

    test "embed object change" do
      a = [Op.insert(%{"image" => "http://example.com"})]
      b = [Op.insert(%{"image" => "http://example.org"})]

      assert [Op.delete(1), Op.insert(%{"image" => "http://example.org"})] == Delta.diff(a, b)
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
    end

    test "combination" do
      a = [Op.insert("Bad", %{"color" => "red"}), Op.insert("cat", %{"color" => "blue"})]
      b = [Op.insert("Good", %{"bold" => true}), Op.insert("dog", %{"italic" => true})]

      assert [
               Op.delete(2),
               Op.insert("Good", %{"bold" => true}),
               Op.retain(1, %{"italic" => true, "color" => nil}),
               Op.delete(3),
               Op.insert("og", %{"italic" => true})
             ] == Delta.diff(a, b)
    end
  end
end
