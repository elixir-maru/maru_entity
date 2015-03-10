defmodule Maru.Entity do
  defmacro __using__(_) do
    quote do
      use Maru.Entity.DSL
      use Maru.Entity.Serializer
    end
  end
end
