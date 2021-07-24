defmodule Delta.Support.Case do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Delta
      alias Delta.{Op, Attr}
      alias Delta.Support.TestEmbed
    end
  end

  setup tags do
    setup_embeds(tags[:custom_embeds])
    :ok
  end

  defp setup_embeds(embeds) when is_list(embeds) do
    previous = Application.get_env(:delta, :custom_embeds, [])
    Application.put_env(:delta, :custom_embeds, embeds)
    on_exit(fn -> Application.put_env(:delta, :custom_embeds, previous) end)
  end

  defp setup_embeds(_other), do: :ok
end
