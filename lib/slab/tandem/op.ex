defmodule Slab.Tandem.Op do
  def delete(length) do
    %{ :delete => length }
  end

  def insert(ins, attr \\ false)
  def insert(ins, attr = %{}) when map_size(attr) > 0 do
    %{ :insert => ins, :attributes => attr }
  end
  def insert(ins, _) do
    %{ :insert => ins }
  end

  def retain(length, attr \\ false)
  def retain(length, attr = %{}) when map_size(attr) > 0 do
    %{ :retain => length, :attributes => attr }
  end
  def retain(length, _) do
    %{ :retain => length }
  end

  def compose(a, b) do
    size = min(op_len(a), op_len(b))
    { op1, a } = take(a, size)
    { op2, b } = take(b, size)
    { compose_atomic(op1, op2), a, b }
  end

  defp compose_atomic(a = %{ :retain => length }, b = %{ :retain => _ }) do
    attr = Slab.Tandem.Attr.compose(a[:attributes], b[:attributes], true)
    retain(length, attr)
  end

  defp compose_atomic(a = %{ :insert => ins }, b = %{ :retain => _ }) do
    attr = Slab.Tandem.Attr.compose(a[:attributes], b[:attributes])
    insert(ins, attr)
  end

  defp compose_atomic(%{ :retain => _ }, b = %{ :delete => _ }), do: b
  defp compose_atomic(_, _), do: false

  defp take(op = %{ :insert => text }, length) when is_bitstring(text) do
    case String.length(text) - length do
      0 -> { op, false }
      _ ->
        { left, right } = String.split_at(text, length)
        { insert(left, op[:attributes]), insert(right, op[:attributes]) }
    end
  end

  defp take(op = %{ :insert => _ }, _length) do
    { op, false }
  end

  defp take(op = %{ :retain => op_length }, take_length) do
    case op_length - take_length do
      0 -> { op, false }
      rest -> { retain(take_length, op[:attributes]), retain(rest, op[:attributes]) }
    end
  end

  defp take(op = %{ :delete => op_length }, take_length) do
    case op_length - take_length do
      0 -> { op, false }
      rest -> { delete(take_length), delete(rest) }
    end
  end

  defp op_len(%{ :insert => text }) when is_bitstring(text), do: String.length(text)
  defp op_len(%{ :insert => _ }), do: 1
  defp op_len(%{ :retain => len }), do: len
  defp op_len(%{ :delete => len }), do: len
end
