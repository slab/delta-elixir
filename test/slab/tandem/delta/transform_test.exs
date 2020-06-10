defmodule Slab.TandemTest.Delta.Transform do
  use ExUnit.Case

  alias Slab.Tandem.Delta

  test "insert + insert" do
    a = [%{"insert" => "A"}]
    b = [%{"insert" => "B"}]

    assert(
      Delta.transform(a, b, true) == [
        %{"retain" => 1},
        %{"insert" => "B"}
      ]
    )

    assert(
      Delta.transform(a, b, false) == [
        %{"insert" => "B"}
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
          color: "red"
        }
      }
    ]

    assert(
      Delta.transform(a, b) == [
        %{
          "retain" => 1
        },
        %{
          "retain" => 1,
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

    assert(
      Delta.transform(a, b, true) == [
        %{"retain" => 1},
        %{"delete" => 1}
      ]
    )
  end

  test "delete + insert" do
    a = [%{"delete" => 1}]
    b = [%{"insert" => "B"}]
    assert(Delta.transform(a, b, true) == [%{"insert" => "B"}])
  end

  test "delete + retain" do
    a = [%{"delete" => 1}]
    b = [%{"retain" => 1, "attributes" => %{bold: true, color: "red"}}]
    assert(Delta.transform(a, b, true) == [])
  end

  test "delete + delete" do
    a = [%{"delete" => 1}]
    b = [%{"delete" => 1}]
    assert(Delta.transform(a, b) == [])
  end

  test "retain + insert" do
    a = [%{"retain" => 1, "attributes" => %{color: "blue"}}]
    b = [%{"insert" => "B"}]
    assert(Delta.transform(a, b, true) == [%{"insert" => "B"}])
  end

  test "retain + retain" do
    a = [%{"retain" => 1, "attributes" => %{color: "blue"}}]
    b = [%{"retain" => 1, "attributes" => %{bold: true, color: "red"}}]

    assert(
      Delta.transform(a, b, true) == [
        %{
          "retain" => 1,
          "attributes" => %{bold: true}
        }
      ]
    )

    assert(Delta.transform(b, a, true) == [])
  end

  test "retain + retain without priority" do
    a = [%{"retain" => 1, "attributes" => %{color: "blue"}}]
    b = [%{"retain" => 1, "attributes" => %{bold: true, color: "red"}}]

    assert(
      Delta.transform(a, b, false) == [
        %{
          "retain" => 1,
          "attributes" => %{bold: true, color: "red"}
        }
      ]
    )

    assert(
      Delta.transform(b, a, false) == [
        %{
          "retain" => 1,
          "attributes" => %{color: "blue"}
        }
      ]
    )
  end

  test "retain + delete" do
    a = [%{"retain" => 1, "attributes" => %{color: "blue"}}]
    b = [%{"delete" => 1}]
    assert(Delta.transform(a, b, true) == b)
  end

  test "alternating edits" do
    a = [%{"retain" => 2}, %{"insert" => "si"}, %{"delete" => 5}]

    b = [
      %{"retain" => 1},
      %{"insert" => "e"},
      %{"delete" => 5},
      %{"retain" => 1},
      %{"insert" => "ow"}
    ]

    assert(
      Delta.transform(a, b, false) == [
        %{"retain" => 1},
        %{"insert" => "e"},
        %{"delete" => 1},
        %{"retain" => 2},
        %{"insert" => "ow"}
      ]
    )

    assert(
      Delta.transform(b, a, false) == [
        %{"retain" => 2},
        %{"insert" => "si"},
        %{"delete" => 1}
      ]
    )
  end

  test "conflicting appends" do
    a = [%{"retain" => 3}, %{"insert" => "aa"}]
    b = [%{"retain" => 3}, %{"insert" => "bb"}]
    assert(Delta.transform(a, b, true) == [%{"retain" => 5}, %{"insert" => "bb"}])
    assert(Delta.transform(b, a, false) == [%{"retain" => 3}, %{"insert" => "aa"}])
  end

  test "prepend + append" do
    a = [%{"insert" => "aa"}]
    b = [%{"retain" => 3}, %{"insert" => "bb"}]
    assert(Delta.transform(a, b, false) == [%{"retain" => 5}, %{"insert" => "bb"}])
    assert(Delta.transform(b, a, false) == [%{"insert" => "aa"}])
  end

  test "trailing deletes with differing lengths" do
    a = [%{"retain" => 2}, %{"delete" => 1}]
    b = [%{"delete" => 3}]
    assert(Delta.transform(a, b, false) == [%{"delete" => 2}])
    assert(Delta.transform(b, a, false) == [])
  end
end
