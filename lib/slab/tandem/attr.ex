defmodule Slab.Tandem.Attr do
  defstruct insert: nil, delete: nil, retain: nil, attributes: nil

  def compose(a, b, keepNil \\ false) do
    attr = do_compose(a, b, keepNil)
    cond do
      is_nil(attr) -> false
      attr == %{} -> false
      true -> attr
    end
  end

  defp do_compose(a, nil, keepNil) do
    do_compose(a, %{}, keepNil)
  end

  defp do_compose(nil, b, keepNil) do
    do_compose(%{}, b, keepNil)
  end

  defp do_compose(a, b, false) do
    merged = Map.merge(a, b)
    keys = merged
      |> Map.keys()
      |> Enum.filter(fn(k) -> is_nil(merged[k]) end)
    merged |> Map.drop(keys)
  end

  defp do_compose(a, b, true) do
    Map.merge(a, b)
  end
end
