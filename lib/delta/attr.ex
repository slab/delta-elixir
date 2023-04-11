defmodule Delta.Attr do
  @typep maybe_map :: map | nil

  @spec compose(a :: maybe_map, b :: maybe_map) :: boolean | map
  @spec compose(a :: maybe_map, b :: maybe_map, keepNil :: boolean) :: boolean | map
  def compose(a, b, keepNil \\ false) do
    attr = merge(a || %{}, b || %{}, keepNil)

    case map_size(attr) do
      0 -> false
      _ -> attr
    end
  end

  @spec transform(a :: maybe_map, b :: maybe_map, priority :: boolean) :: boolean | map
  def transform(a, b, _) when not is_map(a), do: b
  def transform(_, b, _) when not is_map(b), do: false
  def transform(_, b, false), do: b

  def transform(a, b, _) do
    attr =
      b
      |> Map.keys()
      |> Enum.reduce([], fn k, list ->
        case Map.has_key?(a, k) do
          true -> list
          false -> [{k, b[k]} | list]
        end
      end)
      |> Map.new()

    case map_size(attr) do
      0 -> false
      _ -> attr
    end
  end

  @spec invert(attr :: maybe_map, base :: maybe_map) :: map
  def invert(attr, base) do
    attr = attr || %{}
    base = base || %{}

    inverted =
      Enum.reduce(base, %{}, fn {key, value}, inverted ->
        case attr do
          %{^key => v} when v != value -> Map.put(inverted, key, value)
          _other -> inverted
        end
      end)

    Enum.reduce(attr, inverted, fn {key, value}, inverted ->
      if Map.has_key?(base, key) || is_nil(value) do
        inverted
      else
        Map.put(inverted, key, nil)
      end
    end)
  end

  @spec merge(a :: map, b :: map, boolean) :: map
  defp merge(a, b, false) do
    merged = Map.merge(a, b)

    keys =
      merged
      |> Map.keys()
      |> Enum.filter(fn k -> is_nil(merged[k]) end)

    Map.drop(merged, keys)
  end

  defp merge(a, b, true) do
    Map.merge(a, b)
  end

  @spec diff(a :: maybe_map, b :: maybe_map) :: map
  def diff(a, b) do
    a = a || %{}
    b = b || %{}

    keys = MapSet.new(Map.keys(a) ++ Map.keys(b))

    Enum.reduce(keys, %{}, fn key, attrs ->
      if a[key] != b[key] do
        Map.put(attrs, key, b[key])
      else
        attrs
      end
    end)
  end
end
