defmodule Slab.Tandem.Attr do
  def compose(a, b, keepNil \\ false) do
    attr = merge(a || %{}, b || %{}, keepNil)
    case map_size(attr) do
      0 -> false
      _ -> attr
    end
  end

  def transform(a, b, _) when not is_map(a), do: b
  def transform(_, b, _) when not is_map(b), do: false
  def transform(_, b, false), do: b
  def transform(a, b, _) do
    attr = b
      |> Map.keys()
      |> Enum.reduce([], fn(k, list) ->
        case Map.has_key?(a, k) do
          true -> list
          false -> [{k, b[k]} | list]
        end
      end)
      |> Map.new
    case map_size(attr) do
      0 -> false
      _ -> attr
    end
  end

  defp merge(a, b, false) do
    merged = Map.merge(a, b)
    keys = merged
      |> Map.keys()
      |> Enum.filter(fn(k) -> is_nil(merged[k]) end)
    merged |> Map.drop(keys)
  end

  defp merge(a, b, true) do
    Map.merge(a, b)
  end
end
