defmodule Delta.EmbedHandler do
  @moduledoc """
  A module implementing `EmbedHandler` behaviour is required to make `compose`, `transform` and `invert` operations possible for custom embeds.

  Suppose we want to have a custom `image` embed handler, that will always prefer image urls that start with `https://`

      defmodule ImageEmbed do
        @behaviour Delta.EmbedHandler

        @impl Delta.EmbedHandler
        def name, do: "image"

        @impl Delta.EmbedHandler
        def compose(url1, url2, _keep_nil?) do
          choose_https(url1, url2)
        end

        @impl Delta.EmbedHandler
        def transform(url1, url2, _priority? \\ false) do
          choose_https(url1, url2)
        end

        @impl Delta.EmbedHandler
        def invert(change, base) do
          choose_https(change, base)
        end

        defp choose_https(url1, url2) do
          case {url1, url2} do
            {"https" <> _ , _} -> url1

            {_, "https" <> _} -> url2

            {_, _} -> url1
          end
        end
      end

  Now we just need to add our module to config:

      config :delta, custom_embeds: [ImageEmbed]

  ## Examples
      iex> base = Op.insert(%{"image" => "update me"})
      iex> a = Op.retain(%{"image" => "http://quilljs.com/assets/images/icon.png"})
      iex> b = Op.retain(%{"image" => "https://quilljs.com/assets/images/icon.png"})
      iex> Delta.transform([base, a], [base, b])
      [
        %{"insert" => %{"image" => "update me"}},
        %{"retain" => 1},
        %{"retain" => %{"image" => "https://quilljs.com/assets/images/icon.png"}}
      ]
  """
  @type t :: module()
  @type embed :: map()

  @callback name() :: binary()
  @callback compose(any(), any(), keep_nil? :: boolean()) :: embed()
  @callback transform(any(), any(), priority? :: boolean()) :: embed()
  @callback invert(any(), any()) :: embed()
  @callback diff(any(), any()) :: embed()
end
