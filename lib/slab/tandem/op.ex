defmodule Slab.Tandem.Op do
  alias Slab.Tandem.Attr

  def delete(length) do
    %{ "delete" => length }
  end

  def insert(ins, attr \\ false)
  def insert(ins, attr = %{}) when map_size(attr) > 0 do
    %{ "insert" => ins, "attributes" => attr }
  end
  def insert(ins, _) do
    %{ "insert" => ins }
  end

  def retain(length, attr \\ false)
  def retain(op, attr) when is_map(op) do
    retain(op_len(op), attr)
  end
  def retain(length, attr = %{}) when map_size(attr) > 0 do
    %{ "retain" => length, "attributes" => attr }
  end
  def retain(length, _) do
    %{ "retain" => length }
  end

  def delete?(%{ "delete" => _ }), do: true
  def delete?(_), do: false
  def insert?(%{ "insert" => _ }), do: true
  def insert?(_), do: false
  def retain?(%{ "retain" => _ }), do: true
  def retain?(_), do: false

  def compose(a, b) do
    { op1, a, op2, b } = next(a, b)
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
    { composed, a, b }
  end

  def transform(offset, index, op, priority) when is_integer(index) do
    length = op_len(op)
    cond do
      insert?(op) and (offset < index or not priority) ->
        { offset + length, index + length }
      true ->
        { offset + length, index }
    end
  end

  def transform(a, b, priority) do
    { op1, a, op2, b } = next(a, b)
    transformed =
      cond do
        delete?(op1) -> false
        delete?(op2) -> op2
        true ->
          attr = Attr.transform(op1["attributes"], op2["attributes"], priority)
          retain(op1, attr)
      end
    { transformed, a, b }
  end

  defp next(a, b) do
    size = min(op_len(a), op_len(b))
    { op1, a } = take(a, size)
    { op2, b } = take(b, size)
    { op1, a, op2, b }
  end

  defp take(op = %{ "insert" => embed }, _length) when not is_bitstring(embed) do
    { op, false }
  end

  defp take(op, length) do
    case op_len(op) - length do
      0 -> { op, false }
      _ -> take_partial(op, length)
    end
  end

  defp take_partial(op = %{ "insert" => text }, length) do
    { left, right } = String.split_at(text, length)
    { insert(left, op["attributes"]), insert(right, op["attributes"]) }
  end
  defp take_partial(%{ "delete" => full }, length) do
    { delete(length), delete(full - length) }
  end
  defp take_partial(op = %{ "retain" => full }, length) do
    { retain(length, op["attributes"]), retain(full - length, op["attributes"]) }
  end

  defp op_len(%{ "insert" => text }) when is_bitstring(text), do: String.length(text)
  defp op_len(%{ "insert" => _ }), do: 1
  defp op_len(%{ "retain" => len }), do: len
  defp op_len(%{ "delete" => len }), do: len
end