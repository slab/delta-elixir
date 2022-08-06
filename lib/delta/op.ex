defmodule Delta.Op do
  alias Delta.Attr
  alias Delta.Utils
  alias Delta.EmbedHandler

  @type t :: insert_op | retain_op | delete_op

  @typedoc """
  Stand-in type while operators are keyed with String.t() instead of Atom.t()

  `%{insert: bitstring() | EmbedHandler.embed(), ...}`
  """
  @type insert_op :: %{required(insert_key) => insert_val, optional(attributes) => attributes_val}
  @typep insert_key :: String.t()
  @typep insert_val :: bitstring() | EmbedHandler.embed()

  @typedoc """
  Stand-in type while operators are keyed with String.t() instead of Atom.t()

  `%{retain: pos_integer() | EmbedHandler.embed()}`
  """
  @type retain_op :: %{required(retain_key) => retain_val, optional(attributes) => attributes_val}
  @typep retain_key :: String.t()
  @typep retain_val :: pos_integer() | EmbedHandler.embed()


  @typedoc """
  Stand-in type while operators are keyed with String.t() instead of Atom.t()

  `%{delete: pos_integer()}`
  """
  @type delete_op :: %{required(delete_key) => pos_integer}
  @typep delete_key :: String.t()
  @typep delete_val :: pos_integer()

  @typedoc """
  Stand-in type while operators are keyed with String.t() instead of Atom.t()
  """
  @type operation :: insert_key | retain_key | delete_key
  @typep operation_val :: insert_val | retain_val | delete_val

  @typedoc """
  Stand-in type while attributes is keyed with String.t() instead of Atom.t()
  """
  @type attributes :: %{required(String.t()) => attributes_val}
  @typep attributes_val :: map() | false

  @spec new(action :: operation, value :: operation_val, attr :: attributes_val) :: t
  def new(action, value, attr \\ false)

  def new(action, value, %{} = attr) when map_size(attr) > 0 do
    %{action => value, "attributes" => attr}
  end

  def new(action, value, _attr), do: %{action => value}

  @spec insert(value :: insert_val, attr :: attributes_val) :: insert_op
  def insert(value, attr \\ false), do: new("insert", value, attr)

  @spec retain(value :: retain_val, attr :: attributes_val) :: retain_op
  def retain(value, attr \\ false), do: new("retain", value, attr)

  @spec delete(value :: delete_val, attr :: attributes_val) :: delete_op
  def delete(value, attr \\ false), do: new("delete", value, attr)

  @spec has_attributes?(any) :: boolean
  def has_attributes?(%{"attributes" => %{}}), do: true
  def has_attributes?(_), do: false

  @spec type?(op :: t, action :: any, value_type :: any) :: boolean
  def type?(op, action, value_type \\ nil)
  def type?(%{} = op, action, nil) when is_map_key(op, action), do: true
  def type?(%{} = op, action, :map), do: is_map(op[action])
  def type?(%{} = op, action, :string), do: is_binary(op[action])
  def type?(%{} = op, action, :number), do: is_integer(op[action])
  def type?(%{}, _action, _value_type), do: false

  @spec insert?(op :: t, type :: any) :: boolean
  def insert?(op, type \\ nil), do: type?(op, "insert", type)

  @spec delete?(op :: t, type :: any) :: boolean
  def delete?(op, type \\ nil), do: type?(op, "delete", type)

  @spec retain?(op :: t, type :: any) :: boolean
  def retain?(op, type \\ nil), do: type?(op, "retain", type)

  @spec text_size(text :: binary) :: non_neg_integer
  def text_size(text) do
    text
    |> :unicode.characters_to_binary(:utf8, :utf16)
    |> byte_size()
    |> div(2)
  end

  @spec size(t) :: non_neg_integer
  def size(%{"insert" => text}) when is_binary(text), do: text_size(text)
  def size(%{"delete" => len}) when is_integer(len), do: len
  def size(%{"retain" => len}) when is_integer(len), do: len
  def size(_op), do: 1

  @spec take(op :: t, length :: non_neg_integer, opts :: Keyword.t()) :: {t, t | boolean}
  def take(op, length, opts \\ [])

  def take(op = %{"insert" => embed}, _length, _opts) when not is_bitstring(embed) do
    {op, false}
  end

  def take(op, length, opts) do
    case size(op) - length do
      0 -> {op, false}
      _ -> take_partial(op, length, opts)
    end
  end

  @spec get_embed_data!(map, map) :: {any, any, any}
  def get_embed_data!(a, b) do
    cond do
      not is_map(a) ->
        raise("cannot retain #{inspect(a)}")

      not is_map(b) ->
        raise("cannot retain #{inspect(b)}")

      map_size(a) != 1 and Map.keys(a) != Map.keys(b) ->
        raise("embeds not matched: #{inspect(a: a, b: b)}")

      true ->
        [type] = Map.keys(a)
        {type, a[type], b[type]}
    end
  end

  @spec compose(a :: t, b :: t) :: {t | false, t, t}
  def compose(a, b) do
    {op1, a, op2, b} = next(a, b)

    composed =
      case {info(op1), info(op2)} do
        {{"retain", _type}, {"delete", :number}} ->
          op2

        {{"retain", :map}, {"retain", :number}} ->
          attr = Attr.compose(op1["attributes"], op2["attributes"])
          retain(op1["retain"], attr)

        {{"retain", :number}, {"retain", _type}} ->
          attr = Attr.compose(op1["attributes"], op2["attributes"], true)
          retain(op2["retain"], attr)

        {{"insert", _type}, {"retain", :number}} ->
          attr = Attr.compose(op1["attributes"], op2["attributes"])
          insert(op1["insert"], attr)

        {{action, type}, {"retain", :map}} ->
          {embed_type, embed1, embed2} = get_embed_data!(op1[action], op2["retain"])
          handler = Delta.get_handler!(embed_type)

          composed_embed = %{embed_type => handler.compose(embed1, embed2, action == "retain")}
          keep_nil? = action == "retain" && type == :number
          attr = Attr.compose(op1["attributes"], op2["attributes"], keep_nil?)

          new(action, composed_embed, attr)

        _other ->
          false
      end

    {composed, a, b}
  end

  @spec transform(non_neg_integer, non_neg_integer, t, boolean) :: {non_neg_integer, non_neg_integer}
  def transform(offset, index, op, priority) when is_integer(index) do
    length = size(op)

    if insert?(op) and (offset < index or not priority) do
      {offset + length, index + length}
    else
      {offset + length, index}
    end
  end

  @spec transform(a :: t, b :: t, priority :: boolean) :: {t | false, t, t}
  def transform(a, b, priority) do
    {op1, a, op2, b} = next(a, b)

    transformed =
      cond do
        delete?(op1) ->
          false

        delete?(op2) ->
          op2

        # Delegate to embed handler if both are retain ops are
        # embeds of the same type
        retain?(op1, :map) && retain?(op2, :map) &&
            Map.keys(op1["retain"]) == Map.keys(op2["retain"]) ->
          {embed_type, embed1, embed2} = get_embed_data!(op1["retain"], op2["retain"])
          handler = Delta.get_handler!(embed_type)

          embed = %{embed_type => handler.transform(embed1, embed2, priority)}
          attrs = Attr.transform(op1["attributes"], op2["attributes"], priority)
          retain(embed, attrs)

        retain?(op1, :number) && retain?(op2, :map) ->
          attrs = Attr.transform(op1["attributes"], op2["attributes"], priority)
          retain(op2["retain"], attrs)

        true ->
          attrs = Attr.transform(op1["attributes"], op2["attributes"], priority)
          retain(size(op1), attrs)
      end

    {transformed, a, b}
  end

  @spec next(t, t) :: {t, t, t, t}
  defp next(a, b) do
    size = min(size(a), size(b))
    {op1, a} = take(a, size)
    {op2, b} = take(b, size)
    {op1, a, op2, b}
  end

  @spec take_partial(t, non_neg_integer, Keyword.t) :: {t, t}
  defp take_partial(op, 0, _opts), do: {insert("", op["attributes"]), op}

  defp take_partial(%{"insert" => text} = op, len, opts) do
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

    case {is_binary(left), is_binary(right), Keyword.get(opts, :align, false)} do
      {true, true, false} ->
        {insert(left, op["attributes"]), insert(right, op["attributes"])}

      {true, true, true} ->
        if Utils.slices_likely_cut_emoji?(left, right) do
          take_partial(op, len - 1, opts)
        else
          {insert(left, op["attributes"]), insert(right, op["attributes"])}
        end

      {_, _, true} ->
        take_partial(op, len - 1, opts)

      _ ->
        raise "Encoding failed in take_partial #{inspect({text, op, len, left, right})}"
    end
  end

  defp take_partial(%{"delete" => full}, length, _opts) do
    {delete(length), delete(full - length)}
  end

  defp take_partial(%{"retain" => full} = op, length, _opts) do
    {retain(length, op["attributes"]), retain(full - length, op["attributes"])}
  end

  @spec info(t) :: {String.t(), :number | :string | :map}
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
