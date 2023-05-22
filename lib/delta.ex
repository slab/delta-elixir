defmodule Delta do
  alias Delta.{Attr, Op}

  @type t :: list(Op.t())

  @spec get_handler(atom) :: module | nil
  def get_handler(embed_type) do
    :delta
    |> Application.get_env(:custom_embeds, [])
    |> Enum.find(&(&1.name == embed_type))
  end

  @spec get_handler!(atom) :: module
  def get_handler!(embed_type) do
    case get_handler(embed_type) do
      nil -> raise("no embed handler configured for #{inspect(embed_type)}")
      handler -> handler
    end
  end

  @doc ~S"""
  Returns a new Delta that is equivalent to applying the operations of one Delta, followed by another Delta

  ## Examples
      iex> a = [Op.insert("abc")]
      iex> b = [Op.retain(1), Op.delete(1)]
      iex> Delta.compose(a, b)
      [%{"insert" => "ac"}]
  """
  @spec compose(t, t) :: t
  def compose(left, right) do
    [] |> do_compose(left, right) |> chop() |> Enum.reverse()
  end

  @doc ~S"""
  Returns a new Delta that is equivalent to applying Deltas one by one

  ## Examples
      iex> a = [Op.insert("ac")]
      iex> b = [Op.retain(1), Op.insert("b")]
      iex> c = [Op.delete(1)]
      iex> Delta.compose_all([a, b, c])
      [%{"insert" => "bc"}]
  """
  @spec compose_all([t]) :: t
  def compose_all(deltas) do
    Enum.reduce(deltas, [], &compose(&2, &1))
  end

  defp do_compose(result, [], []), do: result

  defp do_compose(result, [], [op | delta]) do
    Enum.reverse(delta, push(result, op))
  end

  defp do_compose(result, [op | delta], []) do
    Enum.reverse(delta, push(result, op))
  end

  defp do_compose(result, [op1 | delta1], [op2 | delta2]) do
    {op, delta1, delta2} =
      cond do
        Op.insert?(op2) ->
          {op2, [op1 | delta1], delta2}

        Op.delete?(op1) ->
          {op1, delta1, [op2 | delta2]}

        true ->
          {composed, op1, op2} = Op.compose(op1, op2)
          delta1 = push(delta1, op1)
          delta2 = push(delta2, op2)
          {composed, delta1, delta2}
      end

    result
    |> push(op)
    |> do_compose(delta1, delta2)
  end

  @spec chop(t) :: t
  defp chop([%{"retain" => n} = op | delta]) when is_number(n) and map_size(op) == 1, do: delta
  defp chop(delta), do: delta

  @doc ~S"""
  Compacts Delta to satisfy [compactness](https://quilljs.com/guides/designing-the-delta-format/#compact) requirement.

  ## Examples
      iex> delta = [Op.insert("Hel"), Op.insert("lo"), Op.insert("World", %{"bold" => true})]
      iex> Delta.compact(delta)
      [%{"insert" => "Hello"}, %{"insert" => "World", "attributes" => %{"bold" => true}}]
  """
  @spec compact(t) :: t
  def compact(delta) do
    delta
    |> Enum.reduce([], &push(&2, &1))
    |> Enum.reverse()
  end

  @doc ~S"""
  Concatenates two Deltas.

  ## Examples
      iex> a = [Op.insert("Hel")]
      iex> b = [Op.insert("lo")]
      iex> Delta.concat(a, b)
      [%{"insert" => "Hello"}]
  """
  @spec concat(t, t) :: t
  def concat(left, []), do: left
  def concat([], right), do: right

  def concat(left, [first | right]) do
    left =
      left
      |> Enum.reverse()
      |> push(first)
      |> Enum.reverse()

    left ++ right
  end

  @doc ~S"""
  Pushes an operation to a reversed Delta honouring semantics.

  Note: that reversed delta does not represent a reversed text, but rather a list
  of operations that was naively reversed during programmatic manipulations.
  This function is normally only used by other functions which reverse the list
  back in the end.

  ## Examples
      iex> delta = [Op.insert("World", %{"italic" => true}), Op.insert("Hello", %{"bold" => true})]
      iex> op = Op.insert("!")
      iex> Delta.push(delta, op)
      [%{"insert" => "!"}, %{"insert" => "World", "attributes" => %{"italic" => true}}, %{"insert" => "Hello", "attributes" => %{"bold" => true}}]

      iex> delta = [Op.insert("World"), Op.insert("Hello", %{"bold" => true})]
      iex> op = Op.insert("!")
      iex> Delta.push(delta, op)
      [%{"insert" => "World!"}, %{"insert" => "Hello", "attributes" => %{"bold" => true}}]
  """
  @spec push(t, false) :: t
  @spec push(t, Op.t()) :: t
  def push(delta, false), do: delta

  def push([], op) do
    if Op.size(op) > 0, do: [op], else: []
  end

  # Adds op to the beginning of delta (we expect a reverse)
  # TODO: Handle inserts after delete (should move insert before delete)
  def push(delta, op) do
    [last_op | partial_delta] = delta
    merged_op = do_push(last_op, op)

    if is_nil(merged_op) do
      [op | delta]
    else
      [merged_op | partial_delta]
    end
  end

  defp do_push(op, %{"delete" => 0}), do: op
  defp do_push(op, %{"insert" => ""}), do: op
  defp do_push(op, %{"retain" => 0}), do: op

  defp do_push(%{"delete" => left, "attributes" => attr}, %{
         "delete" => right,
         "attributes" => attr
       }) do
    Op.delete(left + right, attr)
  end

  defp do_push(%{"delete" => left} = last_op, %{"delete" => right} = op)
       when map_size(last_op) == 1 and map_size(op) == 1 do
    Op.delete(left + right)
  end

  defp do_push(%{"retain" => left, "attributes" => attr}, %{
         "retain" => right,
         "attributes" => attr
       })
       when is_integer(left) and is_integer(right) do
    Op.retain(left + right, attr)
  end

  defp do_push(%{"retain" => left} = last_op, %{"retain" => right} = op)
       when map_size(last_op) == 1 and map_size(op) == 1 and
              is_integer(left) and is_integer(right) do
    Op.retain(left + right)
  end

  defp do_push(%{"insert" => left, "attributes" => attr}, %{
         "insert" => right,
         "attributes" => attr
       })
       when is_bitstring(left) and is_bitstring(right) do
    Op.insert(left <> right, attr)
  end

  defp do_push(%{"insert" => left} = last_op, %{"insert" => right} = op)
       when is_bitstring(left) and is_bitstring(right) and map_size(last_op) == 1 and
              map_size(op) == 1 do
    Op.insert(left <> right)
  end

  defp do_push(_, _), do: nil

  @doc ~S"""
  Returns the size of delta.

  ## Examples
      iex> delta = [Op.insert("abc"), Op.retain(2), Op.delete(1)]
      iex> Delta.size(delta)
      6
  """
  @spec size(t) :: non_neg_integer
  def size(delta) do
    Enum.reduce(delta, 0, fn op, sum ->
      sum + Op.size(op)
    end)
  end

  @doc ~S"""
  Attempts to take `len` characters starting from `index`.

  Note: note that due to the way it's implemented this operation can potentially
  raise if the resulting text isn't a valid UTF-8 encoded string

  ## Examples
      iex> delta = [Op.insert("Hello World")]
      iex> Delta.slice(delta, 6, 3)
      [%{"insert" => "Wor"}]

      iex> delta = [Op.insert("01🙋45")]
      iex> Delta.slice(delta, 1, 2)
      ** (RuntimeError) Encoding failed in take_partial {"1🙋45", %{"insert" => "1🙋45"}, 2, {:incomplete, "1", <<216, 61>>}, {:error, "", <<222, 75, 0, 52, 0, 53>>}}
  """
  @spec slice(t, non_neg_integer, non_neg_integer) :: t
  def slice(delta, index, len) do
    {_left, right} = split(delta, index)
    {middle, _rest} = split(right, len)
    middle
  end

  @doc ~S"""
  Takes `len` or fewer characters from `index` position. Variable `len` allows
  to not cut things like emojis in half.

  ## Examples
      iex> delta = [Op.insert("Hello World")]
      iex> Delta.slice_max(delta, 6, 3)
      [%{"insert" => "Wor"}]

      iex> delta = [Op.insert("01🙋45")]
      iex> Delta.slice_max(delta, 1, 2)
      [%{"insert" => "1"}]
  """
  @spec slice_max(t, non_neg_integer, non_neg_integer) :: t
  def slice_max(delta, index, len) do
    {_left, right} = split(delta, index, align: true)
    {middle, _rest} = split(right, len, align: true)
    middle
  end

  @doc ~S"""
  Splits delta at the given index.

  ## Options

    * `:align` - when `true`, allow moving index left if
      we're likely to split a grapheme otherwise.

  ## Examples
      iex> delta = [Op.insert("Hello World")]
      iex> Delta.split(delta, 5)
      {[%{"insert" => "Hello"}], [%{"insert" => " World"}]}

      iex> delta = [Op.insert("01🙋45")]
      iex> Delta.split(delta, 3, align: true)
      {[%{"insert" => "01"}], [%{"insert" => "🙋45"}]}
  """
  @spec split(t, non_neg_integer | fun, Keyword.t()) :: {t, t}
  def split(delta, index, opts \\ [])

  def split(delta, 0, _), do: {[], delta}

  def split(delta, index, opts) when is_integer(index) do
    do_split(
      [],
      delta,
      fn op, index ->
        op_size = Op.size(op)

        if index <= op_size do
          index
        else
          {:cont, index - op_size}
        end
      end,
      index,
      opts
    )
  end

  def split(delta, func, opts) when is_function(func) do
    do_split([], delta, func, nil, opts)
  end

  defp do_split(passed, [], _, _, _), do: {passed, []}

  defp do_split(passed, remaining, func, context, opts) when is_function(func, 1) do
    do_split(passed, remaining, fn op, _ -> func.(op) end, context, opts)
  end

  defp do_split(passed, remaining, func, context, opts) when is_function(func, 2) do
    [first | remaining] = remaining

    case func.(first, context) do
      :cont ->
        do_split([first | passed], remaining, func, context, opts)

      {:cont, context} ->
        do_split([first | passed], remaining, func, context, opts)

      index ->
        case Op.take(first, index, opts) do
          {left, false} ->
            {Enum.reverse([left | passed]), remaining}

          {left, right} ->
            {Enum.reverse([left | passed]), [right | remaining]}
        end
    end
  end

  @doc ~S"""
  Transforms given delta against another's operations.

  This accepts an optional priority argument (default: false), used to break ties.
  If true, the first delta takes priority over other, that is, its actions are considered to happen "first."

  ## Examples
      iex> a = [Op.insert("a")]
      iex> b = [Op.insert("b"), Op.retain(5), Op.insert("c")]
      iex> Delta.transform(a, b, true)
      [
        %{"retain" => 1},
        %{"insert" => "b"},
        %{"retain" => 5},
        %{"insert" => "c"},
      ]
      iex> Delta.transform(a, b)
      [
        %{"insert" => "b"},
        %{"retain" => 6},
        %{"insert" => "c"},
      ]
  """
  @spec transform(t, t, boolean) :: t
  def transform(_, _, priority \\ false)

  def transform(index, delta, priority) when is_integer(index) do
    do_transform(0, index, delta, priority)
  end

  def transform(left, right, priority) do
    delta = do_transform([], left, right, priority)
    delta |> chop() |> Enum.reverse()
  end

  defp do_transform(offset, index, _, _) when is_integer(index) and offset > index, do: index
  defp do_transform(_, index, [], _) when is_integer(index), do: index

  defp do_transform(offset, index, [%{"delete" => length} | delta], priority)
       when is_integer(index) do
    do_transform(offset, index - min(length, index - offset), delta, priority)
  end

  defp do_transform(offset, index, [op | delta], priority) when is_integer(index) do
    {offset, index} = Op.transform(offset, index, op, priority)
    do_transform(offset, index, delta, priority)
  end

  defp do_transform(result, [], [], _), do: result

  defp do_transform(result, [], [op | delta], priority) do
    do_transform(result, [Op.retain(Op.size(op))], [op | delta], priority)
  end

  defp do_transform(result, [op | delta], [], priority) do
    do_transform(result, [op | delta], [Op.retain(Op.size(op))], priority)
  end

  defp do_transform(result, [op1 | delta1], [op2 | delta2], priority) do
    {op, delta1, delta2} =
      cond do
        Op.insert?(op1) and (priority or not Op.insert?(op2)) ->
          {Op.retain(Op.size(op1)), delta1, [op2 | delta2]}

        Op.insert?(op2) ->
          {op2, [op1 | delta1], delta2}

        true ->
          {transformed, op1, op2} = Op.transform(op1, op2, priority)
          delta1 = push(delta1, op1)
          delta2 = push(delta2, op2)
          {transformed, delta1, delta2}
      end

    result
    |> push(op)
    |> do_transform(delta1, delta2, priority)
  end

  @doc ~S"""
  Returns an inverted delta that has the opposite effect of against a base document delta.

  That is base |> Delta.compose(change) |> Delta.compose(inverted) == base.

  ## Examples
      iex> base = [Op.insert("Hello\nWorld")]
      iex> change = [
      ...>   Op.retain(6, %{"bold" => true}),
      ...>   Op.delete(5),
      ...>   Op.insert("!"),
      ...> ]
      iex> inverted = Delta.invert(change, base)
      [
        %{"retain" => 6, "attributes" => %{"bold" => nil}},
        %{"insert" => "World"},
        %{"delete" => 1},
      ]
      iex> base |> Delta.compose(change) |> Delta.compose(inverted) == base
      true
  """
  @spec invert(t, t) :: t
  def invert(change, base) do
    change
    |> Enum.reduce({[], 0}, fn op, {inverted, base_index} ->
      length = Op.size(op)

      cond do
        Op.insert?(op) ->
          inverted = push(inverted, Op.delete(length))
          {inverted, base_index}

        Op.retain?(op, :number) && !Op.has_attributes?(op) ->
          inverted = push(inverted, Op.retain(length))
          {inverted, base_index + length}

        Op.retain?(op, :number) || Op.delete?(op) ->
          inverted =
            base
            |> slice(base_index, length)
            |> Enum.reduce(inverted, &do_invert_slice(op, &1, &2))

          {inverted, base_index + length}

        # Delegate to the embed handler when change op is an embed
        Op.retain?(op, :map) ->
          base_op =
            base
            |> slice(base_index, length)
            |> hd

          {embed_type, embed1, embed2} = Op.get_embed_data!(op["retain"], base_op["insert"])
          handler = get_handler!(embed_type)

          embed = %{embed_type => handler.invert(embed1, embed2)}
          attrs = Attr.invert(op["attributes"], base_op["attributes"])
          inverted = push(inverted, Op.retain(embed, attrs))

          {inverted, base_index + 1}

        true ->
          {inverted, base_index}
      end
    end)
    |> elem(0)
    |> chop()
    |> Enum.reverse()
  end

  defp do_invert_slice(op, base_op, inverted) do
    cond do
      Op.delete?(op) ->
        push(inverted, base_op)

      Op.retain?(op) && Op.has_attributes?(op) ->
        attrs = Attr.invert(op["attributes"], base_op["attributes"])
        retain_op = base_op |> Op.size() |> Op.retain(attrs)
        push(inverted, retain_op)

      true ->
        inverted
    end
  end

  @doc ~S"""
  Returns a delta representing the difference between two documents.

  ## Examples
      iex> a = [Op.insert("Hello")]
      iex> b = [Op.insert("Hello!")]
      iex> diff = Delta.diff(a, b)
      [
        %{"retain" => 5},
        %{"insert" => "!"}
      ]
      iex> Delta.compose(a, diff) == b
      true
  """
  @spec diff(t, t) :: t
  def diff(base, other)

  def diff(base, other) when base == other, do: []

  def diff(base, other) do
    base_string = diffable_string(base)
    other_string = diffable_string(other)

    diff =
      base_string
      |> Dmp.Diff.main(other_string)
      |> Dmp.Diff.cleanup_semantic()

    do_diff(base, other, diff, [], nil, 0)
  end

  defp diffable_string(delta) do
    delta
    |> Enum.map(fn
      %{"insert" => str} when is_binary(str) ->
        str

      %{"insert" => data} when not is_nil(data) ->
        <<0>>

      _ ->
        raise "Delta.diff called with non-document"
    end)
    |> Enum.join()
  end

  defp do_diff(_, _, [], delta, _, 0) do
    delta
    |> chop()
    |> Enum.reverse()
  end

  defp do_diff(base, other, [{action, str} | rest_diffs], delta, _cur_action, 0) do
    do_diff(base, other, rest_diffs, delta, action, Op.text_size(str))
  end

  defp do_diff(base, [first | rest], diffs, delta, :insert, len) do
    op_len = min(Op.size(first), len)
    {op, remaining} = Op.take(first, op_len)

    do_diff(base, push(rest, remaining), diffs, push(delta, op), :insert, len - op_len)
  end

  defp do_diff([first | rest], other, diffs, delta, :delete, len) do
    op_len = min(Op.size(first), len)
    {_op, remaining} = Op.take(first, op_len)

    do_diff(
      push(rest, remaining),
      other,
      diffs,
      push(delta, Op.delete(op_len)),
      :delete,
      len - op_len
    )
  end

  defp do_diff([base_first | base_rest], [other_first | other_rest], diffs, delta, :equal, len) do
    op_len = Enum.min([Op.size(base_first), Op.size(other_first), len])
    {base_op, base_remaining} = Op.take(base_first, op_len)
    {other_op, other_remaining} = Op.take(other_first, op_len)

    base = push(base_rest, base_remaining)
    other = push(other_rest, other_remaining)

    delta =
      case {base_op, other_op} do
        {%{"insert" => ins}, %{"insert" => ins}} ->
          attrs = Delta.Attr.diff(base_op["attributes"], other_op["attributes"])
          push(delta, Op.retain(op_len, attrs))

        {%{"insert" => base_insert}, %{"insert" => other_insert}}
        when is_map(base_insert) and is_map(other_insert) ->
          {embed_type, base_embed, other_embed} = Op.get_embed_data!(base_insert, other_insert)

          case get_handler(embed_type) do
            nil ->
              delta
              |> push(Op.delete(op_len))
              |> push(other_op)

            handler ->
              diff = handler.diff(base_embed, other_embed)
              attrs = Delta.Attr.diff(base_op["attributes"], other_op["attributes"])
              push(delta, Op.retain(%{embed_type => diff}, attrs))
          end
      end

    do_diff(base, other, diffs, delta, :equal, len - op_len)
  end
end
