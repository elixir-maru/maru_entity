defmodule Maru.Entity.DSL.Compiler do
  def compile(exposures) do
    exp = Enum.reduce exposures, %{}, fn(exp, acc) ->
      attr = exp[:as]
      acc |> Map.put(attr, exp)
    end

    exp |> Map.to_list
  end
end
