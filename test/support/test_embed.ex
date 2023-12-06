defmodule Delta.Support.TestEmbed do
  @moduledoc false
  @behaviour Delta.EmbedHandler

  @impl true
  def name, do: "delta"

  @impl true
  def compose(a, b, _keep_nil), do: Delta.compose(a, b)

  @impl true
  defdelegate transform(a, b, priority?), to: Delta

  @impl true
  defdelegate invert(a, b), to: Delta

  @impl true
  def diff(a, b) do
    attr_diff = Delta.Attr.diff(a["attributes"], b["attributes"])

    diff =
      case Delta.diff(a["insert"]["delta"], b["insert"]["delta"]) do
        [] -> 1
        delta -> %{"delta" => delta}
      end

    [Delta.Op.retain(diff, attr_diff)]
  end
end
