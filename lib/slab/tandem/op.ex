defmodule Slab.Tandem.Op do
  alias Slab.Tandem.Attr

  def delete(length) do
    %{"delete" => length}
  end

  def insert(ins, attr \\ false)
  def insert(ins, attr = %{}) when map_size(attr) > 0 do
    %{"insert" => ins, "attributes" => attr}
  end
  def insert(ins, _) do
    %{"insert" => ins}
  end

  def retain(length, attr \\ false)
  def retain(op, attr) when is_map(op) do
    op |> size() |> retain(attr)
  end
  def retain(length, %{} = attr) when map_size(attr) > 0 do
    %{"retain" => length, "attributes" => attr}
  end
  def retain(length, _) do
    %{"retain" => length}
  end

  def delete?(%{"delete" => _}), do: true
  def delete?(_), do: false
  def insert?(%{"insert" => _}), do: true
  def insert?(_), do: false
  def retain?(%{"retain" => _}), do: true
  def retain?(_), do: false

  def size(%{"insert" => text}) when is_bitstring(text) do
    text
    |> String.graphemes()
    |> Enum.reduce(0, fn(grapheme, sum) ->
        sum + if byte_size(grapheme) >= 4, do: 2, else: 1 # Deal with JS UTF-16 encoding
      end)
  end

  def size(%{"insert" => _}), do: 1
  def size(%{"retain" => len}), do: len
  def size(%{"delete" => len}), do: len


  def take(op, 0), do: {false, op}

  def take(op = %{"insert" => embed}, _length) when not is_bitstring(embed) do
    {op, false}
  end

  def take(op, length) do
    case size(op) - length do
      0 -> {op, false}
      _ -> take_partial(op, length)
    end
  end

  def compose(a, b) do
    {op1, a, op2, b} = next(a, b)
    composed =
      cond do
        retain?(op1) and retain?(op2) ->
          attr = Attr.compose(op1["attributes"], op2["attributes"], true)
          retain(op1["retain"], attr)
        insert?(op1) and retain?(op2) ->
          attr = Attr.compose(op1["attributes"], op2["attributes"])
          insert(op1["insert"], attr)
        retain?(op1) and delete?(op2) ->
          op2
        true ->
          false
      end
    {composed, a, b}
  end

  def transform(offset, index, op, priority) when is_integer(index) do
    length = size(op)
    if insert?(op) and (offset < index or not priority) do
      {offset + length, index + length}
    else
      {offset + length, index}
    end
  end

  def transform(a, b, priority) do
    {op1, a, op2, b} = next(a, b)
    transformed =
      cond do
        delete?(op1) -> false
        delete?(op2) -> op2
        true ->
          attr = Attr.transform(op1["attributes"], op2["attributes"], priority)
          retain(op1, attr)
      end
    {transformed, a, b}
  end

  defp next(a, b) do
    size = min(size(a), size(b))
    {op1, a} = take(a, size)
    {op2, b} = take(b, size)
    {op1, a, op2, b}
  end

  defp take_partial(%{"insert" => text} = op, length) do
    graphemes = String.graphemes(text)
    {split, _} = Enum.reduce_while(graphemes, {0, length}, fn(grapheme, {split, remaining}) ->
      # Deal with JS UTF-16 encoding
      remaining = remaining - if byte_size(grapheme) >= 4, do: 2, else: 1
      split = split + byte_size(grapheme)
      halt = if remaining > 0, do: :cont, else: :halt
      {halt, {split, remaining}}
    end)
    left = Kernel.binary_part(text, 0, split)
    right = Kernel.binary_part(text, split, byte_size(text) - split)
    {insert(left, op["attributes"]), insert(right, op["attributes"])}
  end
  defp take_partial(%{"delete" => full}, length) do
    {delete(length), delete(full - length)}
  end
  defp take_partial(%{"retain" => full} = op, length) do
    {retain(length, op["attributes"]), retain(full - length, op["attributes"])}
  end
end
