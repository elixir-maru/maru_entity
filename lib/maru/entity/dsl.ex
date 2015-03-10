defmodule Maru.Entity.DSL do
  defmacro __using__(_) do
    quote do
      Module.register_attribute __MODULE__, :exposures, accumulate: true

      import          unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro expose(attr) when is_atom(attr) do
    expose_options(attr: attr, as: attr)
  end

  defmacro expose(attr, options) when is_atom(attr) and is_list(options) do
    if !options[:as] do
      options = Keyword.put(options, :as, attr)
    end

    options |> Keyword.put(:attr, attr)
            |> expose_options
  end

  defmacro expose(attr, options, block) when is_atom(attr) and is_list(options) do
    if !options[:as] do
      options = Keyword.put(:as, attr)
    end

    options |> Keyword.put(:attr, attr)
            |> expose_options(block: block)
  end

  def expose_options(options, callbacks \\ []) do
    options = extract_callbacks(options, callbacks)
    callbacks = options[:callbacks]

    cb_names = Enum.map callbacks, fn({cb_name, cb}) ->
      {cb_name, "_cb_#{options[:as]}_#{cb_name}" |> String.to_atom }
    end

    quote do
      @exposures unquote(options)

      if unquote(callbacks[:block]) do
        def unquote(cb_names[:block])(record, options) do
          unquote(callbacks[:block]).(record, options)
        end
      end

      if unquote(callbacks[:if]) do
        def unquote(cb_names[:if])(record, options) do
          unquote(callbacks[:if]).(record, options)
        end
      end

      if unquote(callbacks[:unless]) do
        def unquote(cb_names[:unless])(record, options) do
          unquote(callbacks[:unless]).(record, options)
        end
      end
    end
  end

  defmacro __before_compile__(_) do
    quote unquote: false do
      def exposures do
        unquote(Maru.Entity.DSL.Compiler.compile(@exposures))
      end
    end
  end

  defp extract_callbacks(options, callbacks) do
    if options[:if] do
      callbacks = Keyword.put(callbacks, :if, options[:if])
      options = Keyword.delete(options, :if)
    end

    if options[:unless] do
      callbacks = Keyword.put(callbacks, :unless, options[:unless])
      options = Keyword.delete(options, :unless)
    end

    Keyword.put(options, :callbacks, callbacks)
  end
end
