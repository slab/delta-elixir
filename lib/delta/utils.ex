defmodule Delta.Utils do
  @moduledoc false

  @spec slices_likely_cut_emoji?(String.t(), String.t()) :: boolean()
  def slices_likely_cut_emoji?(left, right) do
    left
    |> to_charlist()
    |> Enum.reverse()
    |> do_slices_likely_cut_emoji?(to_charlist(right))
  end

  @zero_width_joiner 0x200D
  defp do_slices_likely_cut_emoji?([l | _], [r | _])
       when r == @zero_width_joiner or l == @zero_width_joiner,
       do: true

  @variation_selector_16 0xFE0F
  defp do_slices_likely_cut_emoji?(_, [r | _]) when r == @variation_selector_16, do: true

  # we don't have to account for hair modifiers as they use ZWJ
  @skin_tone_modifiers 0x1F3FB..0x1F3FF
  defp do_slices_likely_cut_emoji?(_, [r | _]) when r in @skin_tone_modifiers, do: true

  @tags 0xE0001..0xE007F
  defp do_slices_likely_cut_emoji?(_, [r | _]) when r in @tags, do: true

  defp do_slices_likely_cut_emoji?(_, _), do: false
end
