defmodule Slab.Tandem.Delta do
  alias Slab.Tandem.Op

#   # def insert(delta, insert) do
#   #   [%{ :insert => insert } | delta]
#   # end

#   # def retain(delta, length) do
#   #   [%{ :retain => length } | delta]
#   # end

#   # # def retain(delta, length, format) do

#   # # end

#   # def delete(delta, length) do
#   #   [%{ :delete => length } | delta]
#   # end

  def compact(delta) do
    { delta, lastOp } = Enum.reduce(delta, { [], nil }, fn(curOp, { delta, lastOp }) ->
      if is_nil(lastOp) do
        { delta, curOp }
      else
        case Op.merge(lastOp, curOp) do
          false ->
            { [lastOp | delta], curOp }
          mergedOp ->
            { delta, mergedOp }
        end
      end
    end)
    delta =
      case lastOp do
        nil -> delta
        %{ :retain => _, :attributes => _ } -> [lastOp | delta]
        %{ :delete => _ } -> [lastOp | delta]
        %{ :insert => _ } -> [lastOp | delta]
        _ -> delta
      end
    delta |> Enum.reverse
  end

  def compose(a, b) do
    do_compose([], a, b) |> compact()
  end

  defp do_compose(result, [], []), do: result
  defp do_compose(result, [], b), do: result ++ b
  defp do_compose(result, a, []), do: result ++ a

  # TODO optimize concatenation
  defp do_compose(result, a, [op = %{ :insert => _ } | b]) do
    do_compose(result ++ [op], a, b)
  end

  defp do_compose(result, [op = %{ :delete => _ } | a], b) do
    do_compose(result ++ [op], a, b)
  end

  defp do_compose(result, [op1 | d1], [op2 | d2]) do
    case Op.compose(op1, op2) do
      { false, r1, r2 } -> do_compose(result, r1 ++ d1, r2 ++ d2)
      { op, r1, r2 } -> do_compose(result ++ [op], r1 ++ d1, r2 ++ d2)
    end
  end

  def transform(a, index, priority \\ false) when is_integer(index) do
    index
  end

  def transform(a, b, priority \\ false) do
    a
  end
end
