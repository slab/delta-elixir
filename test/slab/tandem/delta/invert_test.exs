defmodule Slab.Tandem.Delta.InvertTest do
  use ExUnit.Case

  alias Slab.{Config, TestDeltaEmbed}
  alias Slab.Tandem.{Delta, Op}

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
    setup do
      embeds = Config.get(:delta, :custom_embeds, [])
      Application.put_env(:slab, :delta, custom_embeds: [TestDeltaEmbed])
      on_exit(fn -> Application.put_env(:slab, :delta, custom_embeds: embeds) end)
    end

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
  end
end
