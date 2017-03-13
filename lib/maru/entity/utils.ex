defmodule Maru.Entity.Utils do
  @moduledoc false

  @doc """
  Check whether the given attribute match for extended.
  """
  @spec attr_match?(list(atom), Keyword.t) :: boolean
  def attr_match?([], _), do: false
  def attr_match?([h | _], [h | _]), do: true
  def attr_match?([h], [{h, _} | _]), do: true
  def attr_match?([h | t], [{h, nested} | _]), do: attr_match?(t, nested)
  def attr_match?(attr_group, [_| t]), do: attr_match?(attr_group, t)
  def attr_match?(_, _), do: false
end
