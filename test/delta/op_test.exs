defmodule Tests.Op do
  use ExUnit.Case, async: true

  alias Delta.Op

  describe ".compose/2 : retain + delete" do
    test "retain + delete" do
      a = Op.retain(1)
      b = Op.delete(1)

      assert Op.compose(a, b) == {Op.delete(1), false, false}
    end

    test "retain + bigger delete" do
      a = Op.retain(1)
      b = Op.delete(2)

      assert Op.compose(a, b) == {Op.delete(1), false, Op.delete(1)}
    end

    test "retain + smaller delete" do
      a = Op.retain(2)
      b = Op.delete(1)

      assert Op.compose(a, b) == {Op.delete(1), Op.retain(1), false}
    end

    test "retain with attributes + bigger delete" do
      a = Op.retain(1, %{"foo" => true})
      b = Op.delete(2)

      assert Op.compose(a, b) == {Op.delete(1), false, Op.delete(1)}
    end

    test "retain with attributes + smaller delete" do
      a = Op.retain(2, %{"foo" => true})
      b = Op.delete(1)

      assert Op.compose(a, b) == {Op.delete(1), Op.retain(1, %{"foo" => true}), false}
    end
  end

  describe ".compose/2 : retain + retain" do
    test "retain + retain" do
      a = Op.retain(1)
      b = Op.retain(1)

      assert Op.compose(a, b) == {Op.retain(1), false, false}
    end

    test "retain + retain with attributes" do
      a = Op.retain(1, %{"foo" => true})
      b = Op.retain(1, %{"bar" => true})

      assert Op.compose(a, b) == {Op.retain(1, %{"foo" => true, "bar" => true}), false, false}
    end

    test "retain + bigger retain" do
      a = Op.retain(1)
      b = Op.retain(2)

      assert Op.compose(a, b) == {Op.retain(1), false, Op.retain(1)}
    end

    test "retain + smaller retain" do
      a = Op.retain(2)
      b = Op.retain(1)

      assert Op.compose(a, b) == {Op.retain(1), Op.retain(1), false}
    end

    test "retain + bigger retain with attributes" do
      a = Op.retain(1)
      b = Op.retain(2, %{"foo" => true})

      assert Op.compose(a, b) ==
               {Op.retain(1, %{"foo" => true}), false, Op.retain(1, %{"foo" => true})}
    end

    test "retain + smaller retain with attributes" do
      a = Op.retain(2)
      b = Op.retain(1, %{"foo" => true})

      assert Op.compose(a, b) == {Op.retain(1, %{"foo" => true}), Op.retain(1), false}
    end

    test "retain + bigger retain both with attributes" do
      a = Op.retain(1, %{"bar" => true})
      b = Op.retain(2, %{"foo" => true})

      assert Op.compose(a, b) ==
               {Op.retain(1, %{"foo" => true, "bar" => true}), false,
                Op.retain(1, %{"foo" => true})}
    end
  end

  describe ".compose/2 : insert + retain" do
    test "insert + retain" do
      a = Op.insert("A")
      b = Op.retain(1)

      assert Op.compose(a, b) == {Op.insert("A"), false, false}
    end

    test "insert + smaller retain" do
      a = Op.insert("Hello")
      b = Op.retain(4)

      assert Op.compose(a, b) == {Op.insert("Hell"), Op.insert("o"), false}
    end

    test "insert + bigger retain" do
      a = Op.insert("Hello")
      b = Op.retain(6)

      assert Op.compose(a, b) == {Op.insert("Hello"), false, Op.retain(1)}
    end

    test "insert + retain both with attributes" do
      a = Op.insert("A", %{"foo" => true})
      b = Op.retain(1, %{"bar" => true})

      assert Op.compose(a, b) == {Op.insert("A", %{"foo" => true, "bar" => true}), false, false}
    end

    test "insert + smaller retain with attributes" do
      a = Op.insert("Hello")
      b = Op.retain(4, %{"foo" => true})

      assert Op.compose(a, b) == {Op.insert("Hell", %{"foo" => true}), Op.insert("o"), false}
    end

    test "insert + bigger retain with attributes" do
      a = Op.insert("Hello")
      b = Op.retain(6, %{"foo" => true})

      assert Op.compose(a, b) ==
               {Op.insert("Hello", %{"foo" => true}), false, Op.retain(1, %{"foo" => true})}
    end

    test "insert + smaller retain both with attributes" do
      a = Op.insert("Hello", %{"foo" => true})
      b = Op.retain(4, %{"bar" => true})

      assert Op.compose(a, b) ==
               {Op.insert("Hell", %{"foo" => true, "bar" => true}),
                Op.insert("o", %{"foo" => true}), false}
    end

    test "insert + bigger retain both with attributes" do
      a = Op.insert("Hello", %{"foo" => true})
      b = Op.retain(6, %{"bar" => true})

      assert Op.compose(a, b) ==
               {Op.insert("Hello", %{"foo" => true, "bar" => true}), false,
                Op.retain(1, %{"bar" => true})}
    end
  end

  describe ".compose/2 unsupported" do
    test "delete on the left" do
      delete = Op.delete(1)
      retain = Op.retain(1)
      insert = Op.insert("A")

      assert Op.compose(delete, retain) == {false, false, false}
      assert Op.compose(delete, insert) == {false, false, false}
    end

    test "insert on the right" do
      retain = Op.retain(1)
      insert = Op.insert("A")

      assert Op.compose(retain, insert) == {false, false, false}
      assert Op.compose(insert, insert) == {false, false, false}
    end
  end
end
