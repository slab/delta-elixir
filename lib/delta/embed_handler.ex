defmodule Delta.EmbedHandler do
  @type t :: module()
  @type embed :: map()

  @callback name() :: binary()
  @callback compose(embed(), embed(), keep_nil? :: boolean()) :: embed()
  @callback transform(embed(), embed(), priority? :: boolean()) :: embed()
  @callback invert(embed(), embed()) :: embed()
end
