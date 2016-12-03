defmodule Slab.Tandem.Attr do
  defstruct insert: nil, delete: nil, retain: nil, attributes: nil

  def compose(a, b, keepNil \\ false)
  def compose(a, nil, _), do: a
  def compose(nil, b, _), do: b

  def compose(a, b, false) do
    keys = b
      |> Map.keys()
      |> Enum.filter(fn(k) -> is_nil(b[k]) end)
    Map.merge(a, b)
    |> Map.drop(keys)
  end

  def compose(a, b, true) do
    Map.merge(a, b)
  end
end
