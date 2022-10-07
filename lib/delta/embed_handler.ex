defmodule Delta.EmbedHandler do
  @type t :: module()
  @type embed :: map()

  @callback name() :: binary()
  @callback compose(any(), any(), keep_nil? :: boolean()) :: embed()
  @callback transform(any(), any(), priority? :: boolean()) :: embed()
  @callback invert(any(), any()) :: embed()
end
