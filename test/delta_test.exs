defmodule DeltaTest do
  use ExUnit.Case
  doctest Delta

  test "greets the world" do
    assert Delta.hello() == :world
  end
end
