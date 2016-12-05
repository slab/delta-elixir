defmodule Slab.Tandem.Delta do
  alias Slab.Tandem.Op

  def compose(left, right) do
    do_compose([], left, right)
      |> chop()
      |> Enum.reverse()
  end

  def transform(left, right, priority \\ false) do
    do_transform([], left, right, priority)
      |> chop()
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
  defp do_compose(result, [], [op | delta]), do: Enum.reverse(delta) ++ push(result, op)
  defp do_compose(result, [op | delta], []), do: Enum.reverse(delta) ++ push(result, op)

  defp do_compose(result, [op1 | delta1], [op2 | delta2]) do
    { delta1, delta2, op } =
      cond do
        Op.insert?(op2) -> { [op1 | delta1], delta2, op2 }
        Op.delete?(op1) -> { delta1, [op2 | delta2], op1 }
        true ->
          { composed, op1, op2 } = Op.compose(op1, op2)
          delta1 = delta1 |> push(op1)
          delta2 = delta2 |> push(op2)
          { delta1, delta2, composed }
      end
    result
    |> push(op)
    |> do_compose(delta1, delta2)
  end

  # defp do_transform(result, [], [], _), do: result
  # defp do_transform(result, [], [op | delta], _), do: Enum.reverse(delta) ++ push(result, op)
  # defp do_transform(result, [op | delta], []), _, do: Enum.reverse(delta) ++ push(result, op)

  # defp do_transform(result, [op1 | delta], [op2 | delta], priority) do

  # end

  # defp do_transform(result, a = [%{ :insert => _ } | _], b, false) do
  #   do_transform_retain(result, a, b, false)
  # end
  # defp do_transform(result, a = [%{ :insert => _ } | _], b = [%{ :retain => _ } | _], priority) do
  #   do_transform_retain(result, a, b, priority)
  # end
  # defp do_transform(result, a = [%{ :insert => _ } | _], b = [%{ :delete => _ } | _], priority) do
  #   do_transform_retain(result, a, b, priority)
  # end
  # defp do_transform_retain(result, [op | a], b, priority) do
  #   result
  #   |> retain(Op.op_length(op))
  #   |> do_transform(a, b, priority)
  # end

  defp do_transform(result, a, _b, _priority) do
    a
  end


  # defp do_transform(_a, index, _priority) when is_integer(index) do
  #   index
  # end

end
