defmodule Slab.TandemTest.Delta.Transform do
  use ExUnit.Case

  alias Slab.{Config, TestDeltaEmbed}
  alias Slab.Tandem.{Delta, Op}

  describe ".transform/3 (basic)" do
    test "insert + insert" do
      a = [Op.insert("A")]
      b = [Op.insert("B")]

      assert Delta.transform(a, b, true) == [Op.retain(1), Op.insert("B")]
      assert Delta.transform(a, b, false) == [Op.insert("B")]
    end

    test "insert + retain" do
      a = [Op.insert("A")]
      b = [Op.retain(1, %{"bold" => true, "color" => "red"})]

      assert Delta.transform(a, b) == [Op.retain(1) | b]
    end

    test "insert + delete" do
      a = [Op.insert("A")]
      b = [Op.delete(1)]

      assert Delta.transform(a, b) == [Op.retain(1), Op.delete(1)]
    end

    test "delete + insert" do
      a = [Op.delete(1)]
      b = [Op.insert("B")]

      assert Delta.transform(a, b, true) == b
    end

    test "delete + retain" do
      a = [Op.delete(1)]
      b = [Op.retain(1, %{"bold" => true, "color" => "red"})]

      assert Delta.transform(a, b, true) == []
    end

    test "delete + delete" do
      a = b = [Op.delete(1)]

      assert Delta.transform(a, b) == []
    end

    test "retain + insert" do
      a = [Op.retain(1, %{"color" => "blue"})]
      b = [Op.insert("B")]

      assert Delta.transform(a, b, true) == b
    end

    test "retain + retain (with priority)" do
      a = [Op.retain(1, %{"color" => "blue"})]
      b = [Op.retain(1, %{"color" => "red", "bold" => true})]

      assert Delta.transform(a, b, true) == [Op.retain(1, %{"bold" => true})]
      assert Delta.transform(b, a, true) == []
    end

    test "retain + retain (without priority)" do
      a = [Op.retain(1, %{"color" => "blue"})]
      b = [Op.retain(1, %{"color" => "red", "bold" => true})]

      assert Delta.transform(a, b, false) == [Op.retain(1, %{"bold" => true, "color" => "red"})]
      assert Delta.transform(b, a, false) == [Op.retain(1, %{"color" => "blue"})]
    end

    test "retain + delete" do
      a = [Op.retain(1, %{"color" => "blue"})]
      b = [Op.delete(1)]

      assert Delta.transform(a, b, true) == b
    end

    test "alternating edits" do
      a = [Op.retain(2), Op.insert("si"), Op.delete(5)]
      b = [Op.retain(1), Op.insert("e"), Op.delete(5), Op.retain(1), Op.insert("ow")]

      assert Delta.transform(a, b, false) == [
               Op.retain(1),
               Op.insert("e"),
               Op.delete(1),
               Op.retain(2),
               Op.insert("ow")
             ]

      assert Delta.transform(b, a, false) == [
               Op.retain(2),
               Op.insert("si"),
               Op.delete(1)
             ]
    end

    test "conflicting appends" do
      a = [Op.retain(3), Op.insert("aa")]
      b = [Op.retain(3), Op.insert("bb")]

      assert Delta.transform(a, b, true) == [Op.retain(5), Op.insert("bb")]
      assert Delta.transform(b, a, false) == [Op.retain(3), Op.insert("aa")]
    end

    test "prepend + append" do
      a = [Op.insert("aa")]
      b = [Op.retain(3), Op.insert("bb")]

      assert Delta.transform(a, b, false) == [Op.retain(5), Op.insert("bb")]
      assert Delta.transform(b, a, false) == [Op.insert("aa")]
    end

    test "trailing deletes with differing lengths" do
      a = [Op.retain(2), Op.delete(1)]
      b = [Op.delete(3)]

      assert Delta.transform(a, b, false) == [Op.delete(2)]
      assert Delta.transform(b, a, false) == []
    end
  end

  describe ".transform/3 (custom embeds)" do
    setup do
      embeds = Config.get(:delta, :custom_embeds, [])
      Application.put_env(:slab, :delta, custom_embeds: [TestDeltaEmbed])
      on_exit(fn -> Application.put_env(:slab, :delta, custom_embeds: embeds) end)
    end

    test "transform an embed change with number" do
      a = [Op.retain(1)]
      b = [Op.retain(%{"delta" => [Op.insert("b")]})]

      expected = [Op.retain(%{"delta" => [Op.insert("b")]})]

      assert Delta.transform(a, b, true) == expected
      assert Delta.transform(a, b, false) == expected
    end

    test "transform an embed change" do
      a = [Op.retain(%{"delta" => [Op.insert("a")]})]
      b = [Op.retain(%{"delta" => [Op.insert("b")]})]

      with_priority = [Op.retain(%{"delta" => [Op.retain(1), Op.insert("b")]})]
      without_priority = [Op.retain(%{"delta" => [Op.insert("b")]})]

      assert Delta.transform(a, b, true) == with_priority
      assert Delta.transform(a, b, false) == without_priority
    end
  end
end
