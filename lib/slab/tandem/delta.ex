defmodule Slab.Tandem.Delta do
  alias Slab.Tandem.Op

  def checksum(delta, initial \\ 0) do
    Enum.reduce(delta, initial, fn(op, sum) ->
      case op do
        %{"insert" => _} -> sum + Op.size(op)
        %{"delete" => delete} -> sum - delete
        _ -> sum
      end
    end)
  end

  def compose(left, right) do
    [] |> do_compose(left, right) |> chop() |> Enum.reverse()
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

  def push(delta, false), do: delta
  def push(delta, op) when length(delta) == 0 do
    case op do
      %{"retain" => 0} -> delta
      %{"delete" => 0} -> delta
      _ -> [op]
    end
  end

  # Adds op to the beginning of delta (we expect a reverse)
  def push(delta, op) do
    [last_op | partial_delta] = delta
    merged_op = do_push(last_op, op)
    if is_nil(merged_op) do
      [op | delta]
    else
      [merged_op | partial_delta]
    end
  end

  def size(delta) do
    Enum.reduce(delta, 0, fn(op, sum) ->
      sum + Op.size(op)
    end)
  end

  def slice(delta, index, len) do
    {_left, right} = split(delta, index)
    {middle, _rest} = split(right, len)
    middle
  end

  def split(delta, index) when is_integer(index) do
    do_split([], delta, fn(op, index) ->
      op_size = Op.size(op)
      if index <= op_size do
        index
      else
        {:cont, index - op_size}
      end
    end, index)
  end
  def split(delta, func) when is_function(func) do
    do_split([], delta, func)
  end

  def text(delta, embed \\ "|") do
    delta
    |> Enum.map(fn(op) ->
        case op do
          %{"insert" => text} when is_bitstring(text) -> text
          %{"insert" => _} -> embed
          _ -> ""
        end
      end)
    |> Enum.join("")
  end

  def transform(_, _, priority \\ false)
  def transform(index, delta, priority) when is_integer(index) do
    do_transform(0, index, delta, priority)
  end
  def transform(left, right, priority) do
    delta = do_transform([], left, right, priority)
    delta |> chop() |> Enum.reverse()
  end

  defp chop([%{"retain" => _} = op | delta]) when map_size(op) == 1, do: delta
  defp chop(delta), do: delta

  defp do_compose(result, [], []), do: result
  defp do_compose(result, [], [op | delta]) do
    Enum.reverse(delta) ++ push(result, op)
  end
  defp do_compose(result, [op | delta], []) do
    Enum.reverse(delta) ++ push(result, op)
  end
  defp do_compose(result, [op1 | delta1], [op2 | delta2]) do
    {op, delta1, delta2} =
      cond do
        Op.insert?(op2) -> {op2, [op1 | delta1], delta2}
        Op.delete?(op1) -> {op1, delta1, [op2 | delta2]}
        true ->
          {composed, op1, op2} = Op.compose(op1, op2)
          delta1 = delta1 |> push(op1)
          delta2 = delta2 |> push(op2)
          {composed, delta1, delta2}
      end
    result
    |> push(op)
    |> do_compose(delta1, delta2)
  end

  defp do_push(op, %{"delete" => 0}), do: op

  defp do_push(%{"delete" => left}, %{"delete" => right}) do
    Op.delete(left + right)
  end

  defp do_push(op, %{"retain" => 0}), do: op

  defp do_push(%{"retain" => left, "attributes" => attr},
               %{"retain" => right, "attributes" => attr}) do
    Op.retain(left + right, attr)
  end

  defp do_push(%{"retain" => left} = last_op, %{"retain" => right} = op)
               when map_size(last_op) == 1 and map_size(op) == 1 do
    Op.retain(left + right)
  end

  defp do_push(%{"insert" => left, "attributes" => attr},
               %{"insert" => right, "attributes" => attr})
               when is_bitstring(left) and is_bitstring(right) do
    Op.insert(left <> right, attr)
  end

  defp do_push(%{"insert" => left} = last_op, %{"insert" => right} = op)
               when is_bitstring(left) and is_bitstring(right) and
                    map_size(last_op) == 1 and map_size(op) == 1 do
    Op.insert(left <> right)
  end

  defp do_push(_, _), do: nil

  defp do_split(passed, remaining, func, context \\ nil)
  defp do_split(passed, [], _, _), do: {passed, []}
  defp do_split(passed, remaining, func, context) when is_function(func, 1) do
    do_split(passed, remaining, fn(op, _) -> func.(op) end, context)
  end
  defp do_split(passed, remaining, func, context) when is_function(func, 2) do
    [first | remaining] = remaining
    case func.(first, context) do
      :cont ->
        do_split([first | passed], remaining, func, context)
      {:cont, context} ->
        do_split([first | passed], remaining, func, context)
      index ->
        case Op.take(first, index) do
          {false, right} ->
            {Enum.reverse(passed), [right | remaining]}
          {left, false} ->
            {Enum.reverse([left | passed]), remaining}
          {left, right} ->
            {Enum.reverse([left | passed]), [right | remaining]}
        end
    end
  end

  defp do_transform(offset, index, _, _) when is_integer(index) and offset > index, do: index
  defp do_transform(_, index, [], _) when is_integer(index), do: index
  defp do_transform(offset, index, [%{"delete" => length} | delta], priority) when is_integer(index) do
    do_transform(offset, index - min(length, index - offset), delta, priority)
  end
  defp do_transform(offset, index, [op | delta], priority) when is_integer(index) do
    {offset, index} = Op.transform(offset, index, op, priority)
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
    {op, delta1, delta2} =
      cond do
        Op.insert?(op1) and (priority or not Op.insert?(op2)) ->
          {Op.retain(op1), delta1, [op2 | delta2]}
        Op.insert?(op2) ->
          {op2, [op1 | delta1], delta2}
        true ->
          {transformed, op1, op2} = Op.transform(op1, op2, priority)
          delta1 = delta1 |> push(op1)
          delta2 = delta2 |> push(op2)
          {transformed, delta1, delta2}
      end
    result
    |> push(op)
    |> do_transform(delta1, delta2, priority)
  end

  defp is_block_embed(%{"image" => _}), do: true
  defp is_block_embed(_), do: false

  defp next_line(delta) do
    [%{"insert" => insert} = op | rest] = delta
    cond do
      is_bitstring(insert) && String.contains?(insert, "\n") ->
        [left, right] = String.split(insert, "\n", parts: 2)
        left = if String.length(left) > 0, do: [Op.insert(left)], else: []
        attr = op["attributes"] || %{}
        rest = if String.length(right) > 0, do: [Op.insert(right, op["attributes"]) | rest], else: rest
        {left, attr, rest}
      is_block_embed(insert) ->
        {[op], %{}, rest}
      length(rest) > 0 ->
        {next, attr, rest} = next_line(rest)
        {[op | next], attr, rest}
      true ->
        {[op], %{}, []}
    end
  end
end
