defmodule Slab.TandemTest.Delta do
  use ExUnit.Case

  alias Slab.Tandem.{Delta, Op}

  test "slice across" do
    delta = [
      %{"insert" => "ABC"},
      %{"insert" => "012", "attributes" => %{bold: true}},
      %{"insert" => "DEF"}
    ]
    assert(Delta.slice(delta, 1, 7) == [
      %{"insert" => "BC"},
      %{"insert" => "012", "attributes" => %{bold: true}},
      %{"insert" => "DE"}
    ])
  end

  test "slice boundaries" do
    delta = [
      %{"insert" => "ABC"},
      %{"insert" => "012", "attributes" => %{bold: true}},
      %{"insert" => "DEF"}
    ]
    assert(Delta.slice(delta, 3, 3) == [
      %{"insert" => "012", "attributes" => %{bold: true}}
    ])
  end

  test "slice middle" do
    delta = [
      %{"insert" => "ABC"},
      %{"insert" => "012", "attributes" => %{bold: true}},
      %{"insert" => "DEF"}
    ]
    assert(Delta.slice(delta, 4, 1) == [
      %{"insert" => "1", "attributes" => %{bold: true}}
    ])
  end

  test "push merge" do
    delta = []
      |> Delta.push(Op.insert("Hello"))
      |> Delta.push(Op.insert(" World!"))
    assert(delta == [%{"insert" => "Hello World!"}])
  end

  test "push redundant" do
    delta = []
      |> Delta.push(Op.insert("Hello"))
      |> Delta.push(Op.retain(0))
    assert(delta == [%{"insert" => "Hello"}])
  end
end
