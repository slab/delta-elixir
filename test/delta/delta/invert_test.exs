defmodule Tests.Delta.Invert do
  use Delta.Support.Case, async: false
  doctest Delta, only: [invert: 2]

  describe ".invert/2 (basic)" do
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

  describe ".invert/2 (custom embeds)" do
    @describetag custom_embeds: [TestEmbed]

    test "invert a normal change" do
      change = [Op.retain(1, %{"bold" => true})]
      base = [Op.insert(%{"delta" => [Op.insert("a")]})]
      expected = [Op.retain(1, %{"bold" => nil})]
      inverted = Delta.invert(change, base)

      assert inverted == expected
      assert base == base |> Delta.compose(change) |> Delta.compose(inverted)
    end

    test "invert an embed change" do
      change = [Op.retain(%{"delta" => [Op.insert("b")]})]
      base = [Op.insert(%{"delta" => [Op.insert("a")]})]
      expected = [Op.retain(%{"delta" => [Op.delete(1)]})]
      inverted = Delta.invert(change, base)

      assert inverted == expected
      assert base == base |> Delta.compose(change) |> Delta.compose(inverted)
    end

    test "invert an embed change with numbers" do
      delta = [
        Op.retain(1),
        Op.retain(1, %{"bold" => true}),
        Op.retain(%{"delta" => [Op.insert("b")]})
      ]

      base = [Op.insert("\n\n"), Op.insert(%{"delta" => [Op.insert("a")]})]

      expected = [
        Op.retain(1),
        Op.retain(1, %{"bold" => nil}),
        Op.retain(%{"delta" => [Op.delete(1)]})
      ]

      inverted = Delta.invert(delta, base)

      assert inverted == expected
      assert base == base |> Delta.compose(delta) |> Delta.compose(inverted)
    end

    test "respects base attributes" do
      delta = [
        Op.delete(1),
        Op.retain(1, %{"header" => 2}),
        Op.retain(%{"delta" => [Op.insert("b")]}, %{"padding" => 10, "margin" => 0})
      ]

      base = [
        Op.insert("\n"),
        Op.insert("\n", %{"header" => 1}),
        Op.insert(%{"delta" => [Op.insert("a")]}, %{"margin" => 10})
      ]

      expected = [
        Op.insert("\n"),
        Op.retain(1, %{"header" => 1}),
        Op.retain(%{"delta" => [Op.delete(1)]}, %{"padding" => nil, "margin" => 10})
      ]

      inverted = Delta.invert(delta, base)

      assert inverted == expected
      assert base == base |> Delta.compose(delta) |> Delta.compose(inverted)
    end

    test "works with multiple embeds" do
      delta = [
        Op.retain(1),
        Op.retain(%{"delta" => [Op.delete(1)]}),
        Op.retain(%{"delta" => [Op.delete(1)]})
      ]

      base = [
        Op.insert("\n"),
        Op.insert(%{"delta" => [Op.insert("a")]}),
        Op.insert(%{"delta" => [Op.insert("b")]})
      ]

      expected = [
        Op.retain(1),
        Op.retain(%{"delta" => [Op.insert("a")]}),
        Op.retain(%{"delta" => [Op.insert("b")]})
      ]

      inverted = Delta.invert(delta, base)

      assert inverted == expected
      assert base == base |> Delta.compose(delta) |> Delta.compose(inverted)
    end
  end
end
