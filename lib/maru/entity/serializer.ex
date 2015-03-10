defmodule Maru.Entity.Serializer do
  defmacro __using__(_) do
    quote do
      def serialize(record, options) when is_map(record) and is_map(options) do
        Enum.reduce exposures, %{}, fn({as, opt}, acc) ->
          attr_value = record[opt[:attr]]

          if opt[:with] do
            Map.put(acc, as, opt[:with].serialize(attr_value, options))
          else
            Map.put(acc, as, attr_value)
          end
        end
      end

      def serialize(records, options) when is_list(records) and is_map(options) do
        Enum.map records, fn(record) ->
          serialize(record, options)
        end
      end

      def serialize(record) when is_map(record) do
        serialize(record, %{})
      end

      def serialize(records) when is_list(records) do
        serialize(records, %{})
      end
    end
  end
end
