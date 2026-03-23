defmodule Delta.Support.MapEmbed do
  @moduledoc false
  @behaviour Delta.EmbedHandler

  @impl true
  def name, do: "map"

  @impl true
  def compose(_a, b, _keep_nil), do: b

  @impl true
  def transform(a, b, priority?) do
    if priority?, do: b, else: a
  end

  @impl true
  def invert(_change, base), do: base

  @impl true
  def diff(base, other) do
    attr_diff = Delta.Attr.diff(base["attributes"], other["attributes"])

    diff =
      case {base["insert"], other["insert"]} do
        {img, img} -> 1
        {_base, other_img} -> other_img
      end

    [Delta.Op.retain(diff, attr_diff)]
  end
end
