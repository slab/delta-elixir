defmodule Slab.TandemTest.Delta.Compose do
  use ExUnit.Case

  alias Slab.Tandem.{Delta}

  test "insert + insert plain" do
    a = [%{"insert" => "A"}]
    b = [%{"insert" => "B"}]
    assert(Delta.compose(a, b) == [%{"insert" => "BA"}])
  end

  test "insert + insert with attributes" do
    a = [%{"insert" => "A", "attributes" => %{bold: true}}]
    b = [%{"insert" => "B", "attributes" => %{bold: true}}]

    assert(
      Delta.compose(a, b) == [
        %{
          "insert" => "BA",
          "attributes" => %{bold: true}
        }
      ]
    )
  end

  test "insert + retain" do
    a = [%{"insert" => "A"}]

    b = [
      %{
        "retain" => 1,
        "attributes" => %{
          bold: true,
          color: "red",
          font: nil
        }
      }
    ]

    assert(
      Delta.compose(a, b) == [
        %{
          "insert" => "A",
          "attributes" => %{
            bold: true,
            color: "red"
          }
        }
      ]
    )
  end

  test "insert + delete" do
    a = [%{"insert" => "A"}]
    b = [%{"delete" => 1}]
    assert(Delta.compose(a, b) == [])
  end

  test "delete + insert" do
    a = [%{"delete" => 1}]
    b = [%{"insert" => "B"}]
    assert(Delta.compose(a, b) == b ++ a)
  end

  test "delete + retain" do
    a = [%{"delete" => 1}]
    b = [%{"retain" => 1, "attributes" => %{bold: true, color: "red"}}]
    assert(Delta.compose(a, b) == a ++ b)
  end

  test "delete + delete" do
    a = [%{"delete" => 1}]
    b = [%{"delete" => 1}]
    assert(Delta.compose(a, b) == [%{"delete" => 2}])
  end

  test "retain + insert" do
    a = [%{"retain" => 1, "attributes" => %{color: "blue"}}]
    b = [%{"insert" => "B"}]
    assert(Delta.compose(a, b) == b ++ a)
  end

  test "retain + retain plain" do
    a = [%{"retain" => 1}]
    b = [%{"retain" => 1}]
    assert(Delta.compose(a, b) == [])
  end

  test "retain + retain" do
    a = [%{"retain" => 1, "attributes" => %{color: "blue", italic: true}}]

    b = [
      %{
        "retain" => 1,
        "attributes" => %{
          bold: true,
          color: "red",
          font: nil
        }
      }
    ]

    assert(
      Delta.compose(a, b) == [
        %{
          "retain" => 1,
          "attributes" => %{
            bold: true,
            color: "red",
            italic: true,
            font: nil
          }
        }
      ]
    )
  end

  test "retain + delete" do
    a = [%{"retain" => 1, "attributes" => %{color: "blue"}}]
    b = [%{"delete" => 1}]
    assert(Delta.compose(a, b) == b)
  end

  test "insert in middle of text" do
    a = [%{"insert" => "Hello"}]
    b = [%{"retain" => 3}, %{"insert" => "X"}]
    assert(Delta.compose(a, b) == [%{"insert" => "HelXlo"}])
  end

  test "insert and delete ordering" do
    a = [%{"insert" => "Hello"}]
    b_insert = [%{"retain" => 3}, %{"insert" => "X"}, %{"delete" => 1}]
    b_delete = [%{"retain" => 3}, %{"delete" => 1}, %{"insert" => "X"}]
    expected = [%{"insert" => "HelXo"}]
    assert(Delta.compose(a, b_insert) == expected)
    assert(Delta.compose(a, b_delete) == expected)
  end

  test "insert embed" do
    a = [%{"insert" => %{image: "image.png"}, "attributes" => %{width: "300"}}]
    b = [%{"retain" => 1, "attributes" => %{height: "200"}}]

    assert(
      Delta.compose(a, b) == [
        %{
          "insert" => %{image: "image.png"},
          "attributes" => %{
            height: "200",
            width: "300"
          }
        }
      ]
    )
  end

  test "delete entire text" do
    a = [%{"retain" => 4}, %{"insert" => "Hello"}]
    b = [%{"delete" => 9}]
    assert(Delta.compose(a, b) == [%{"delete" => 4}])
  end

  test "retain more than length of text" do
    a = [%{"insert" => "Hello"}]
    b = [%{"retain" => 10}]
    assert(Delta.compose(a, b) == a)
  end

  test "retain empty embed" do
    a = [%{"insert" => %{}}]
    b = [%{"retain" => 1}]
    assert(Delta.compose(a, b) == a)
  end

  test "remove all attributes" do
    a = [%{"insert" => "A", "attributes" => %{bold: true}}]
    b = [%{"retain" => 1, "attributes" => %{bold: nil}}]
    assert(Delta.compose(a, b) == [%{"insert" => "A"}])
  end

  test "remove all embed attributes" do
    a = [%{"insert" => %{}, "attributes" => %{bold: true}}]
    b = [%{"retain" => 1, "attributes" => %{bold: nil}}]
    assert(Delta.compose(a, b) == [%{"insert" => %{}}])
  end

  test "long composition" do
    a = [%{"insert" => "HloWrd"}]

    b = [
      %{"retain" => 1},
      %{"insert" => "e"},
      %{"retain" => 1},
      %{"insert" => "l"},
      %{"retain" => 1},
      %{"insert" => " "},
      %{"retain" => 1},
      %{"insert" => "o"},
      %{"retain" => 1},
      %{"insert" => "l"},
      %{"retain" => 1},
      %{"insert" => "!"}
    ]

    assert(Delta.compose(a, b) == [%{"insert" => "Hello World!"}])
  end

  test "retain at boundary" do
    a = [%{"insert" => "ab"}, %{"insert" => "cd"}]
    b = [%{"retain" => 2}, %{"delete" => 1}]

    assert(Delta.compose(a, b) == [%{"insert" => "abd"}])
  end

  test "non-compact" do
    a = [
      %{"insert" => ""},
      %{"attributes" => %{"link" => "link"}, "insert" => "2"},
      %{"insert" => "\n"}
    ]

    b = [%{"retain" => 1}, %{"delete" => 1}]

    assert(
      Delta.compose(a, b) == [
        %{"insert" => ""},
        %{"attributes" => %{"link" => "link"}, "insert" => "2"}
      ]
    )
  end
end
