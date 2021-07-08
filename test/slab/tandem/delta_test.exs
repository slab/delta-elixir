defmodule Slab.Tandem.DeltaTest do
  use ExUnit.Case, async: true

  alias Slab.Tandem.{Delta, Op}

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

  describe ".compose/3" do
    test "insert + insert" do
      a = [Op.insert("A")]
      b = [Op.insert("B")]
      expected = [Op.insert("BA")]

      assert Delta.compose(a, b) == expected
    end

    test "insert + retain" do
      a = [Op.insert("A")]
      b = [Op.retain(1, %{"bold" => true, "color" => "red", "font" => nil})]
      expected = [Op.insert("A", %{"bold" => true, "color" => "red"})]

      assert Delta.compose(a, b) == expected
    end

    test "insert + delete" do
      a = [Op.insert("A")]
      b = [Op.delete(1)]
      expected = []

      assert Delta.compose(a, b) == expected
    end

    test "delete + insert" do
      a = [Op.delete(1)]
      b = [Op.insert("B")]
      expected = [Op.insert("B"), Op.delete(1)]

      assert Delta.compose(a, b) == expected
    end

    test "delete + retain" do
      a = [Op.delete(1)]
      b = [Op.retain(1, %{"bold" => true, "color" => "red"})]
      expected = [Op.delete(1), Op.retain(1, %{"bold" => true, "color" => "red"})]

      assert Delta.compose(a, b) == expected
    end

    test "delete + delete" do
      a = [Op.delete(1)]
      b = [Op.delete(1)]
      expected = [Op.delete(2)]

      assert Delta.compose(a, b) == expected
    end

    test "retain + insert" do
      a = [Op.retain(1, %{"color" => "blue"})]
      b = [Op.insert("B")]
      expected = [Op.insert("B"), Op.retain(1, %{"color" => "blue"})]

      assert Delta.compose(a, b) == expected
    end

    test "retain + retain" do
      a = [Op.retain(1, %{"color" => "blue"})]
      b = [Op.retain(1, %{"bold" => true, "color" => "red", "font" => nil})]
      expected = [Op.retain(1, %{"bold" => true, "color" => "red", "font" => nil})]

      assert Delta.compose(a, b) == expected
    end

    test "retain + delete" do
      a = [Op.retain(1, %{"color" => "blue"})]
      b = [Op.delete(1)]
      expected = [Op.delete(1)]

      assert Delta.compose(a, b) == expected
    end

    test "insert in middle of text" do
      a = [Op.insert("Hello")]
      b = [Op.retain(3), Op.insert("X")]
      expected = [Op.insert("HelXlo")]

      assert Delta.compose(a, b) == expected
    end

    test "insert/delete ordering" do
      base = [Op.insert("Hello")]
      insert_first = [Op.retain(3), Op.insert("X"), Op.delete(1)]
      delete_first = [Op.retain(3), Op.delete(1), Op.insert("X")]
      expected = [Op.insert("HelXo")]

      assert Delta.compose(base, insert_first) == expected
      assert Delta.compose(base, delete_first) == expected
    end

    test "insert embed" do
      a = [Op.insert(1, %{"src" => "http://quilljs.com/image.png"})]
      b = [Op.retain(1, %{"alt" => "logo"})]
      expected = [Op.insert(1, %{"src" => "http://quilljs.com/image.png", "alt" => "logo"})]

      assert Delta.compose(a, b) == expected
    end

    test "delete entire text" do
      a = [Op.retain(4), Op.insert("Hello")]
      b = [Op.delete(9)]
      expected = [Op.delete(4)]

      assert Delta.compose(a, b) == expected
    end

    test "retain more than length of text" do
      a = [Op.insert("Hello")]
      b = [Op.retain(10)]
      expected = [Op.insert("Hello")]

      assert Delta.compose(a, b) == expected
    end

    test "retain empty embed" do
      a = [Op.insert(1)]
      b = [Op.retain(1)]
      expected = [Op.insert(1)]

      assert Delta.compose(a, b) == expected
    end

    test "remove all attributes" do
      a = [Op.insert("A", %{"bold" => true})]
      b = [Op.retain(1, %{"bold" => nil})]
      expected = [Op.insert("A")]

      assert Delta.compose(a, b) == expected
    end

    test "remove all embed attributes" do
      a = [Op.insert(2, %{"bold" => true})]
      b = [Op.retain(1, %{"bold" => nil})]
      expected = [Op.insert(2)]

      assert Delta.compose(a, b) == expected
    end

    test "retain start optimization" do
      a = [
        Op.insert("A", %{"bold" => true}),
        Op.insert("B"),
        Op.insert("C", %{"bold" => true}),
        Op.delete(1)
      ]

      b = [
        Op.retain(3),
        Op.insert("D"),
      ]

      expected = [
        Op.insert("A", %{"bold" => true}),
        Op.insert("B"),
        Op.insert("C", %{"bold" => true}),
        Op.insert("D"),
        Op.delete(1)
      ]

      assert Delta.compose(a, b) == expected
    end

    test "retain start optimization split" do
      a = [
        Op.insert("A", %{"bold" => true}),
        Op.insert("B"),
        Op.insert("C", %{"bold" => true}),
        Op.retain(5),
        Op.delete(1)
      ]

      b = [
        Op.retain(4),
        Op.insert("D"),
      ]

      expected = [
        Op.insert("A", %{"bold" => true}),
        Op.insert("B"),
        Op.insert("C", %{"bold" => true}),
        Op.retain(1),
        Op.insert("D"),
        Op.retain(4),
        Op.delete(1)
      ]

      assert Delta.compose(a, b) == expected
    end

    test "retain end optimization" do
      a = [
        Op.insert("A", %{"bold" => true}),
        Op.insert("B"),
        Op.insert("C", %{"bold" => true}),
      ]

      b = [Op.delete(1)]
      expected = [Op.insert("B"), Op.insert("C", %{"bold" => true})]

      assert Delta.compose(a, b) == expected
    end

    test "retain end optimization join" do
      a = [
        Op.insert("A", %{"bold" => true}),
        Op.insert("B"),
        Op.insert("C", %{"bold" => true}),
        Op.insert("D"),
        Op.insert("E", %{"bold" => true}),
        Op.insert("F"),
      ]

      b = [
        Op.retain(1),
        Op.delete(1)
      ]

      expected = [
        Op.insert("AC", %{"bold" => true}),
        Op.insert("D"),
        Op.insert("E", %{"bold" => true}),
        Op.insert("F"),
      ]

      assert Delta.compose(a, b) == expected
    end
  end

  describe ".invert/2" do
    test "insert" do
      change = [%{"retain" => 2}, %{"insert" => "A"}]
      base = [%{"insert" => "123456"}]
      expected = [%{"retain" => 2}, %{"delete" => 1}]
      inverted = Delta.invert(change, base)

      assert inverted == expected
      assert base == base |> Delta.compose(change) |> Delta.compose(inverted)
    end

    test "delete" do
      change = [%{"retain" => 2}, %{"delete" => 3}]
      base = [%{"insert" => "123456"}]
      expected = [%{"retain" => 2}, %{"insert" => "345"}]
      inverted = Delta.invert(change, base)

      assert inverted == expected
      assert base == base |> Delta.compose(change) |> Delta.compose(inverted)
    end

    test "retain" do
      change = [%{"retain" => 2}, %{"retain" => 3, "attributes" => %{"bold" => true}}]
      base = [%{"insert" => "123456"}]
      expected = [%{"retain" => 2}, %{"retain" => 3, "attributes" => %{"bold" => nil}}]
      inverted = Delta.invert(change, base)

      assert inverted == expected
      assert base == base |> Delta.compose(change) |> Delta.compose(inverted)
    end

    test "retain on a delta with different attributes" do
      base = [%{"insert" => "123"}, %{"insert" => "4", "attributes" => %{"bold" => true}}]
      change = [%{"retain" => 4, "attributes" => %{"italic" => true}}]
      expected = [%{"retain" => 4, "attributes" => %{"italic" => nil}}]
      inverted = Delta.invert(change, base)

      assert inverted == expected
      assert base == base |> Delta.compose(change) |> Delta.compose(inverted)
    end

    test "combined" do
      change = [
        %{"retain" => 2},
        %{"delete" => 2},
        %{"insert" => "AB", "attributes" => %{"italic" => true}},
        %{"retain" => 2, "attributes" => %{"italic" => nil, "bold" => true}},
        %{"retain" => 2, "attributes" => %{"color" => "red"}},
        %{"delete" => 1}
      ]

      base = [
        %{"insert" => "123", "attributes" => %{"bold" => true}},
        %{"insert" => "456", "attributes" => %{"italic" => true}},
        %{"insert" => "789", "attributes" => %{"bold" => true, "color" => "red"}}
      ]

      expected = [
        %{"retain" => 2},
        %{"insert" => "3", "attributes" => %{"bold" => true}},
        %{"insert" => "4", "attributes" => %{"italic" => true}},
        %{"delete" => 2},
        %{"retain" => 2, "attributes" => %{"italic" => true, "bold" => nil}},
        %{"retain" => 2},
        %{"insert" => "9", "attributes" => %{"bold" => true, "color" => "red"}}
      ]

      inverted = Delta.invert(change, base)
      assert inverted == expected
      assert base == base |> Delta.compose(change) |> Delta.compose(inverted)
    end
  end
end
