defmodule Maru.Entity.DSL do
  defmacro __using__(_) do
    quote do
      Module.register_attribute __MODULE__, :exposures, accumulate: true

      import          unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro expose(attr) when is_atom(attr) do
    quote do
      @exposures [attr: unquote(attr), as: unquote(attr)]
    end
  end

  defmacro expose(attr, options) when is_atom(attr) and is_list(options) do
    if options[:as] do
      options = Keyword.put(options, :attr, attr)
      quote do
        @exposures unquote(options)
      end
    else
      options = Keyword.put(options, :attr, attr)
             |> Keyword.put(:as, attr)
      quote do
        @exposures unquote(options)
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
end
