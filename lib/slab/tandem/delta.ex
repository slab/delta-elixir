defmodule Slab.Tandem.Delta do
  alias Slab.Tandem.Op

  def compose(a, b) do
    do_compose([], a, b)
      |> chop()
      |> Enum.reverse()
  end

  def transform(a, b, priority \\ false) do
    do_transform(a, b, priority)
      |> Enum.reverse()
  end

  defp push(delta, false), do: delta
  defp push(delta, op) when length(delta) == 0, do: [op]

  defp push(delta, op) do
    [lastOp | partial_delta] = delta
    case { lastOp, op } do
      { %{ :delete => left }, %{ :delete => right } } ->
        [ Op.delete(left + right) | partial_delta ]
      { %{ :retain => left, :attributes => attr }, %{ :retain => right, :attributes => attr } } ->
        [ Op.retain(left + right, attr) | partial_delta ]
      { %{ :retain => left }, %{ :retain => right } } when map_size(lastOp) == 1 and map_size(op) == 1 ->
        [ Op.retain(left + right) | partial_delta ]
      { %{ :insert => left, :attributes => attr },
        %{ :insert => right, :attributes => attr }
      } when is_bitstring(left) and is_bitstring(right) ->
        [ Op.insert(left <> right, attr) | partial_delta ]
      { %{ :insert => left }, %{ :insert => right }
      } when is_bitstring(left) and is_bitstring(right) and map_size(lastOp) == 1 and map_size(op) == 1 ->
        [ Op.insert(left <> right) | partial_delta ]
      _ ->
        [op | delta]
    end
  end

  defp chop([op = %{ :retain => _ } | delta]) when map_size(op) == 1, do: delta
  defp chop(delta), do: delta

  defp do_compose(result, [], []), do: result

  defp do_compose(result, [], [op | b]) do
    Enum.reverse(b) ++ push(result, op)
  end

  defp do_compose(result, [op | a], []) do
    Enum.reverse(a) ++ push(result, op)
  end

  defp do_compose(result, a, [op = %{ :insert => _ } | b]) do
    result
    |> push(op)
    |> do_compose(a, b)
  end

  defp do_compose(result, [op = %{ :delete => _ } | a], b) do
    result
    |> push(op)
    |> do_compose(a, b)
  end

  defp do_compose(result, [op1 | d1], [op2 | d2]) do
    { composed, op1, op2 } = Op.compose(op1, op2)
    d1 = push(d1, op1)
    d2 = push(d2, op2)
    result
      |> push(composed)
      |> do_compose(d1, d2)
  end

  def do_transform(_a, index, _priority) when is_integer(index) do
    index
  end

  def do_transform(a, _b, _priority) do
    a
  end
end
