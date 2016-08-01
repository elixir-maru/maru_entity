defmodule Maru.Entity.DSL.Compiler do
  def compile(exposures) do
    exp = Enum.reduce exposures, %{}, fn(exp, acc) ->
      attr = exp[:as]
      exp = transform_callbacks(exp)
      acc |> Map.put(attr, exp)
    end

    exp |> Map.to_list
  end

  def transform_callbacks(exposure) do
    if exposure[:callbacks] do
      callbacks = Enum.reduce exposure[:callbacks], %{}, fn({cb_name, _}, acc) ->
        Map.put(acc, cb_name, true)
      end

      # Remove callback functions and set as true
      exposure |> Keyword.put(:callbacks, Map.to_list(callbacks))
    else
      exposure
    end
  end
end
