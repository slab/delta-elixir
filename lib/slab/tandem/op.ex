defmodule Slab.Tandem.Op do
  alias Slab.Tandem.{Attr, Delta}

  def new(action, value, attr \\ false)
  def new("delete", length, _attr), do: %{"delete" => length}

  def new(action, value, %{} = attr) when map_size(attr) > 0 do
    %{action => value, "attributes" => attr}
  end

  def new(action, value, _attr), do: %{action => value}

  def insert(value, attr \\ false), do: new("insert", value, attr)
  def retain(value, attr \\ false), do: new("retain", value, attr)
  def delete(value), do: new("delete", value)

  # def retain(op, attr) when is_map(op) do
  #   op |> size() |> retain(attr)
  # end

  def has_attribute?(%{"attributes" => %{}}), do: true
  def has_attribute?(_), do: false

  def delete?(%{"delete" => _}), do: true
  def delete?(_), do: false
  def insert?(%{"insert" => _}), do: true
  def insert?(_), do: false
  def retain?(%{"retain" => _}), do: true
  def retain?(_), do: false

  def text_size(text) do
    text
    |> :unicode.characters_to_binary(:utf8, :utf16)
    |> byte_size()
    |> div(2)
  end

  def size(%{"insert" => text}) when is_binary(text), do: text_size(text)
  def size(%{"delete" => len}) when is_integer(len), do: len
  def size(%{"retain" => len}) when is_integer(len), do: len
  def size(_op), do: 1

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
      case {info(op1), info(op2)} do
        # Return second "delete" op as-is when composing a
        # basic retain with a basic delete
        {{"retain", :number}, {"delete", :number}} ->
          # OLD
          op2

        # Return second op with composed attributes when composing
        # a basic retain with another (basic or embed) retain
        {{"retain", :number}, {"retain", _type}} ->
          # A
          attr = Attr.compose(op1["attributes"], op2["attributes"], true)
          retain(op2["retain"], attr)

        {{"retain", :map}, {"retain", :number}} ->
          # B
          attr = Attr.compose(op1["attributes"], op2["attributes"])
          retain(op1["retain"], attr)

        {{"insert", _type}, {"retain", :number}} ->
          # C
          attr = Attr.compose(op1["attributes"], op2["attributes"])
          insert(op1["insert"], attr)

        {{action, type}, {"retain", :map}} ->
          # D
          {embed_type, embed1, embed2} = get_embed_data!(op1[action], op2["retain"])
          handler = Delta.get_handler!(embed_type)

          composed_embed = %{embed_type => handler.compose(embed1, embed2, action == "retain")}
          keep_nil? = action == :retain && type == :number
          attr = Attr.compose(op1["attributes"], op2["attributes"], keep_nil?)

          new(action, composed_embed, attr)

        _other ->
          false
      end

    {composed, a, b}
  end

  # def compose(a, b) do
  #   retain?(op2) ->
  #     retain?(op1) and is_num(op1) -> # {"retain", :number}, {"retain", _}
  #       # A: composed.retain = op2.retain

  #     else ->
  #       is_num(op2) -> # already retain
  #         retain?(op1) -> # op1 is_map # {"retain", :map}, {"retain", :number}
  #           # B: composed.retain = op1.retain

  #         !retain?(op1) -> # {"insert", _}, {"retain", :number}
  #           # C: composed.insert = op1.insert

  #       is_map(op2) -> # already retain # {action, _}, {"retain", :map}
  #         # D:
  #         # composed[action] = %{embed_type => composed_embed}

  #   delete?(op2) and is_num(op2) and retain?(op1) and is_num(op1) ->
  #   # OLD: delete?(op2) and retain?(op1) ->
  #     op2

  #   true ->
  #     false
  # end

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
        delete?(op1) ->
          false

        delete?(op2) ->
          op2

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

  defp take_partial(%{"insert" => text} = op, len) do
    binary = :unicode.characters_to_binary(text, :utf8, :utf16)
    binary_length = byte_size(binary)

    left =
      binary
      |> Kernel.binary_part(0, len * 2)
      |> :unicode.characters_to_binary(:utf16, :utf8)

    right =
      binary
      |> Kernel.binary_part(len * 2, binary_length - len * 2)
      |> :unicode.characters_to_binary(:utf16, :utf8)

    case {is_binary(left), is_binary(right)} do
      {true, true} ->
        {insert(left, op["attributes"]), insert(right, op["attributes"])}

      _ ->
        raise "Encoding failed in take_partial #{inspect({text, op, len, left, right})}"
    end
  end

  defp take_partial(%{"delete" => full}, length) do
    {delete(length), delete(full - length)}
  end

  defp take_partial(%{"retain" => full} = op, length) do
    {retain(length, op["attributes"]), retain(full - length, op["attributes"])}
  end

  defp get_embed_data!(a, b) do
    cond do
      !is_map(a) ->
        raise("cannot retain #{inspect(a)}")

      !is_map(b) ->
        raise("cannot retain #{inspect(b)}")

      map_size(a) != 1 && Map.keys(a) != Map.keys(b) ->
        raise("embeds not matched: #{inspect(a: a, b: b)}")

      true ->
        [type] = Map.keys(a)
        {type, a[type], b[type]}
    end
  end

  defp info(op) do
    action =
      case op do
        %{"insert" => _} -> "insert"
        %{"retain" => _} -> "retain"
        %{"delete" => _} -> "delete"
      end

    type =
      case op[action] do
        value when is_integer(value) -> :number
        value when is_binary(value) -> :string
        value when is_map(value) -> :map
      end

    {action, type}
  end
end
