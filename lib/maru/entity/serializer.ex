defmodule Maru.Entity.Serializer do
  defmacro __using__(_) do
    quote do
      def serialize(record, options) when is_map(record) and is_map(options) do
        Enum.reduce exposures, %{}, fn({as, opt}, acc) ->
          attr_value = record[opt[:attr]]

          if callbacks_permit?(record, options, opt) do
            if has_block?(opt) do
              Map.put(acc, as, eval_block(record, options, opt))
            else
              if opt[:with] do
                Map.put(acc, as, opt[:with].serialize(attr_value, options))
              else
                Map.put(acc, as, attr_value)
              end
            end
          else
            acc
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

      def serialize(nil) do
        nil
      end

      def serialize(nil, options) do
        nil
      end

      def callbacks_permit?(record, options, exp_options) do
        if exp_options[:callbacks][:if] do
          cb = get_callback_name(exp_options[:as], :if)

          apply(__MODULE__, cb, [record, options])
        else
          if exp_options[:callbacks][:unless] do
            cb = get_callback_name(exp_options[:as], :unless)

            !apply(__MODULE__, cb, [record, options])
          else
            true
          end
        end
      end

      def has_block?(exp_options) do
        exp_options[:callbacks][:block] == true
      end

      def eval_block(record, options, exp_options) do
        cb = get_callback_name(exp_options[:as], :block)

        apply(__MODULE__, cb, [record, options])
      end

      def get_callback_name(as, cb) do
        "_cb_#{as}_#{cb}" |> String.to_atom
      end
    end
  end
end
