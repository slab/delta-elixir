defmodule Slab.Tandem.Delta do
  alias Slab.Tandem.Op

  def compose(left, right) do
    do_compose([], left, right)
      |> chop()
      |> Enum.reverse()
  end

  def concat(left, right) when length(right) == 0, do: left
  def concat(left, right) when length(left) == 0, do: right
  def concat(left, [first | right]) do
    left = left
      |> Enum.reverse()
      |> push(first)
      |> Enum.reverse()
    left ++ right
  end

  def size(delta) do
    Enum.reduce(delta, 0, fn(op, sum) ->
      sum + Op.size(op)
    end)
  end

  def transform(_, _, priority \\ false)
  def transform(index, delta, priority) when is_integer(index) do
    do_transform(0, index, delta, priority)
  end
  def transform(left, right, priority) do
    do_transform([], left, right, priority)
      |> chop()
      |> Enum.reverse()
  end

  defp push(delta, false), do: delta
  defp push(delta, op) when length(delta) == 0, do: [op]

  # Adds op to the beginning of delta (we expect a reverse)
  defp push(delta, op) do
    [lastOp | partial_delta] = delta
    case { lastOp, op } do
      { %{ "delete" => left }, %{ "delete" => right } } ->
        [ Op.delete(left + right) | partial_delta ]
      { %{ "retain" => left, "attributes" => attr }, %{ "retain" => right, "attributes" => attr } } ->
        [ Op.retain(left + right, attr) | partial_delta ]
      { %{ "retain" => left }, %{ "retain" => right } } when map_size(lastOp) == 1 and map_size(op) == 1 ->
        [ Op.retain(left + right) | partial_delta ]
      { %{ "insert" => left, "attributes" => attr },
        %{ "insert" => right, "attributes" => attr }
      } when is_bitstring(left) and is_bitstring(right) ->
        [ Op.insert(left <> right, attr) | partial_delta ]
      { %{ "insert" => left }, %{ "insert" => right }
      } when is_bitstring(left) and is_bitstring(right) and map_size(lastOp) == 1 and map_size(op) == 1 ->
        [ Op.insert(left <> right) | partial_delta ]
      _ ->
        [op | delta]
    end
  end

  def text(delta, embed \\ "|") do
    delta
    |> Enum.map(fn(op) ->
        case op do
          %{ "insert" => text } when is_bitstring(text) -> text
          %{ "insert" => _ } -> embed
          _ -> ""
        end
      )
    |> Enum.join("")
  end

  defp chop([op = %{ "retain" => _ } | delta]) when map_size(op) == 1, do: delta
  defp chop(delta), do: delta

  defp do_compose(result, [], []), do: result
  defp do_compose(result, [], [op | delta]), do: Enum.reverse(delta) ++ push(result, op)
  defp do_compose(result, [op | delta], []), do: Enum.reverse(delta) ++ push(result, op)
  defp do_compose(result, [op1 | delta1], [op2 | delta2]) do
    { op, delta1, delta2 } =
      cond do
        Op.insert?(op2) -> { op2, [op1 | delta1], delta2 }
        Op.delete?(op1) -> { op1, delta1, [op2 | delta2] }
        true ->
          { composed, op1, op2 } = Op.compose(op1, op2)
          delta1 = delta1 |> push(op1)
          delta2 = delta2 |> push(op2)
          { composed, delta1, delta2 }
      end
    result
    |> push(op)
    |> do_compose(delta1, delta2)
  end

  defp do_transform(offset, index, _, _) when is_integer(index) and offset > index, do: index
  defp do_transform(_, index, [], _) when is_integer(index), do: index
  defp do_transform(offset, index, [%{ "delete" => length } | delta], priority) when is_integer(index) do
    do_transform(offset, index - min(length, index-offset), delta, priority)
  end
  defp do_transform(offset, index, [op | delta], priority) when is_integer(index) do
    { offset, index } = Op.transform(offset, index, op, priority)
    do_transform(offset, index, delta, priority)
  end

  defp do_transform(result, [], [], _), do: result
  defp do_transform(result, [], [op | delta], priority) do
    do_transform(result, [Op.retain(op)], [op | delta], priority)
  end
  defp do_transform(result, [op | delta], [], priority) do
    do_transform(result, [op | delta], [Op.retain(op)], priority)
  end
  defp do_transform(result, [op1 | delta1], [op2 | delta2], priority) do
    { op, delta1, delta2 } =
      cond do
        Op.insert?(op1) and (priority or not Op.insert?(op2)) ->
          { Op.retain(op1), delta1, [op2 | delta2] }
        Op.insert?(op2) ->
          { op2, [op1 | delta1 ], delta2 }
        true ->
          { transformed, op1, op2 } = Op.transform(op1, op2, priority)
          delta1 = delta1 |> push(op1)
          delta2 = delta2 |> push(op2)
          { transformed, delta1, delta2 }
      end
    result
    |> push(op)
    |> do_transform(delta1, delta2, priority)
  end


  # defp do_transform(_a, index, _priority) when is_integer(index) do
  #   index
  # end
end
