defmodule Tests.Delta.Attr do
  use Delta.Support.Case, async: false

  @attr %{bold: true, color: "red"}

  test "compose left undefined" do
    assert Attr.compose(nil, @attr) == @attr
  end

  test "compose right undefined" do
    assert Attr.compose(@attr, nil) == @attr
  end

  test "both undefined" do
    assert Attr.compose(nil, nil) == false
  end

  test "compose missing" do
    param = %{italic: true}

    assert Attr.compose(@attr, param) == %{
             bold: true,
             italic: true,
             color: "red"
           }
  end

  test "compose overwrite" do
    param = %{bold: false, color: "blue"}

    assert Attr.compose(@attr, param) == %{
             bold: false,
             color: "blue"
           }
  end

  test "compose remove" do
    param = %{bold: nil}
    assert Attr.compose(@attr, param) == %{color: "red"}
  end

  test "compose keep removal" do
    param = %{bold: nil}

    assert Attr.compose(@attr, param, true) == %{
             bold: nil,
             color: "red"
           }
  end

  # TODO divergent behavior vs JS Delta
  test "compose remove to empty" do
    param = %{bold: nil, color: nil}
    assert Attr.compose(@attr, param) == false
  end

  test "compose remove missing" do
    param = %{italic: nil}
    assert Attr.compose(@attr, param) == @attr
  end
end
