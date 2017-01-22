defmodule Maru.Entity do
  alias Maru.Entity.Struct.Batch
  alias Maru.Entity.Struct.Serializer
  alias Maru.Entity.Struct.Exposure.Information
  alias Maru.Entity.Struct.Exposure.Runtime

  defmacro __using__(_) do
    quote do
      Module.register_attribute __MODULE__, :exposures, accumulate: true

      import          unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro expose(attr_name) when is_atom(attr_name) do
    quote do
      @exposures(parse([attr_name: unquote(attr_name)]))
    end
  end

  defmacro expose(attr_name, options) when is_atom(attr_name) and is_list(options) do
    options = Macro.escape(options)
    quote do
      @exposures(unquote(options)
      |> Keyword.put(:attr_name, unquote(attr_name))
      |> parse)
    end
  end

  defmacro expose(attr_name, options, do_func) when is_atom(attr_name) and is_list(options) do
    options = Macro.escape(options)
    quote do
      @exposures(unquote(options)
      |> Keyword.put(:attr_name, unquote(attr_name))
      |> Keyword.put(:do_func, unquote(Macro.escape(do_func)))
      |> parse)
    end
  end

  def parse(options) do
    pipeline = [
      :attr_name, :serializer, :if_func, :do_func
    ]
    accumulator = %{
      options:     options,
      information: %Information{}, # TODO
      runtime:     quote do %Runtime{} end,
    }
    Enum.reduce(pipeline, accumulator, &do_parse/2)
  end

  defp do_parse(:attr_name, %{options: options, runtime: runtime}) do
    attr_name = options |> Keyword.fetch!(:attr_name)
    param_key = options |> Keyword.get(:source, attr_name)
    options   = options |> Keyword.drop([:attr_name, :source]) |> Keyword.put(:param_key, param_key)
    %{ options: options,
       runtime: quote do
         %{ unquote(runtime) |
            attr_name: [unquote(attr_name)], # TODO: use attr_group
          }
       end
    }
  end

  defp do_parse(:if_func, %{options: options, runtime: runtime}) do
    if_func     = options |> Keyword.get(:if)
    unless_func = options |> Keyword.get(:unless)
    options     = options |> Keyword.drop([:if, :unless])
    is_nil(if_func) or is_nil(unless_func) ||  raise ":if and :unless conflict"
    func =
      case {if_func, unless_func} do
        {nil, nil} -> quote do
            fn(_, _) -> true end
          end
        {nil, {:fn, _, _}=f} ->
          quote do
            fn(instance, options) ->
              case unquote(f).(instance, options) do
                x when x in [false, nil] -> true
                _                        -> false
              end
            end
          end
        {{:fn, _, _}=f, nil} ->
          quote do
            fn(instance, options) ->
              case unquote(f).(instance, options) do
                x when x in [false, nil] -> false
                _                        -> true
              end
            end
          end
      end
    %{ options: options,
       runtime: quote do
         %{ unquote(runtime) |
            if_func: unquote(func)
          }
       end
    }
  end

  defp do_parse(:serializer, %{options: options, runtime: runtime}) do
    serializer =
      case Keyword.get(options, :using, nil) do
      nil -> nil
      {:__aliases__, _, module} ->
        %Serializer{module: Module.safe_concat(module), type: :one}
      {{:., _, [Access, :get]}, _, [{:__aliases__, _, [:List]}, {:__aliases__, _, module},]} ->
        %Serializer{module: Module.safe_concat(module), type: :list}
    end
    %{ options: options |> Keyword.drop([:using]),
       runtime: quote do
         %{ unquote(runtime) |
            serializer: unquote(Macro.escape(serializer))
         }
       end
     }
  end

  defp do_parse(:do_func, %{options: options, runtime: runtime}) do
    do_func    = options |> Keyword.get(:do_func)
    param_key  = options |> Keyword.fetch!(:param_key)
    batch      = Keyword.get(options, :batch)
    options    = options |> Keyword.drop([:do_func, :param_key, :batch])
    func =
      cond do
        not is_nil(batch) ->
          quote do
            fn(instance, options) ->
              %Batch{
                module: unquote(batch),
                key: unquote(batch).key(instance, options),
              }
            end
          end

        is_nil(do_func) ->
          quote do
            fn(instance, _options) ->
              Map.get(instance, unquote(param_key))
            end
          end

        true ->
          do_func

      end
    %{ options: options,
       runtime: quote do
         %{ unquote(runtime) |
            do_func: unquote(func)
          }
       end
    }
  end


  defmacro __before_compile__(env) do
    exposures =
      Module.get_attribute(env.module, :exposures)
      |> Enum.map(fn(e) ->
        e.runtime
      end)
    quote do
      def __exposures__ do
        unquote(exposures)
      end

      def serialize(instance, options \\ %{}) do
        %Serializer{
          module:  __MODULE__,
          type:    is_list(instance) && :list || :one,
          options: options,
        } |> Maru.Entity.Runtime.serialize(instance)
      end
    end
  end

end
