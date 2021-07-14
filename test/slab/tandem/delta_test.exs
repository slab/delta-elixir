defmodule Slab.Tandem.DeltaTest do
  use ExUnit.Case, async: true
  alias Slab.Tandem.{Delta, Op}

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
end
