defmodule Tests.Delta.TransformPosition do
  use Delta.Support.Case, async: true

  test "insert before position" do
    delta = [%{"insert" => "A"}]
    assert Delta.transform(2, delta) == 3
  end

  test "insert after position" do
    delta = [%{"retain" => 2}, %{"insert" => "A"}]
    assert Delta.transform(1, delta) == 1
  end

  test "insert at position" do
    delta = [%{"retain" => 2}, %{"insert" => "A"}]
    assert Delta.transform(2, delta, true) == 2
    assert Delta.transform(2, delta, false) == 3
  end

  test "delete before position" do
    delta = [%{"delete" => 2}]
    assert Delta.transform(4, delta) == 2
  end

  test "delete after position" do
    delta = [%{"retain" => 4}, %{"delete" => 2}]
    assert Delta.transform(2, delta) == 2
  end

  test "delete across position" do
    delta = [%{"retain" => 1}, %{"delete" => 4}]
    assert Delta.transform(2, delta) == 1
  end

  test "insert and delete before position" do
    delta = [%{"retain" => 2}, %{"insert" => "A"}, %{"delete" => 2}]
    assert Delta.transform(4, delta) == 3
  end

  test "insert before and delete across position" do
    delta = [%{"retain" => 2}, %{"insert" => "A"}, %{"delete" => 4}]
    assert Delta.transform(4, delta) == 3
  end

  test "delete before and delete across position" do
    delta = [%{"delete" => 1}, %{"retain" => 1}, %{"delete" => 4}]
    assert Delta.transform(4, delta) == 1
  end
end
