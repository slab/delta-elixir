defmodule Delta.Support.TestEmbed do
  @behaviour Delta.EmbedHandler

  @impl true
  def name, do: "delta"

  @impl true
  def compose(a, b, _keep_nil), do: Delta.compose(a, b)

  @impl true
  defdelegate transform(a, b, priority?), to: Delta

  @impl true
  defdelegate invert(a, b), to: Delta
end
