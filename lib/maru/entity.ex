alias Maru.Entity.Struct.Batch
alias Maru.Entity.Struct.Serializer
alias Maru.Entity.Struct.Exposure.Runtime

defmodule Maru.Entity do
  @moduledoc ~S"""

  ## Defining Entities

  ### Basic Exposure

      expose :id

  expose with `Map.get(instance, :id)`

  `%{id: 1}` => `%{id: 1}`

  ### Exposing with a Presenter

  expose field with another entity and another key:

      expose :response, source: :reply, using: Reply.Entity

  `%{reply: reply}` => `%{response: Reply.Entity.serializer(reploy)}`

  expose list-type field with another entity:

      expose :replies, using: List[Reply.Entity]

  `%{replies: [reply1, reply2]}` => `%{replies: [Reply.Entity.serializer(reply1), Reply.Entity.serializer(reply2)]}`

  ### Conditional Exposure

  Use `:if` or `:unless` to expose fields conditionally.

      expose :username, if: fn(user, _options) -> user[:public?] end

  `%{username: "user1", public?: true}` => `%{username: "user1"}`

  `%{username: "user1", public?: false}` => `%{}`

  ### Custom Present Function

      expose :username, [], fn user, _options ->
        "#{user[:first_name]} #{user[:last_name]}"
      end

  `%{first_name: "X", last_name: "Y"}` => `%{username: "X Y"}`
  """

  @type instance    :: map
  @type object      :: map
  @type options     :: map
  @type one_or_list :: :one | :list

  @doc false
  defmacro __using__(_) do
    quote do
      Module.register_attribute __MODULE__, :exposures, accumulate: true

      import          unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Expose a field with Map.get.
  """
  defmacro expose(attr_name) when is_atom(attr_name) do
    quote do
      @exposures(parse([attr_name: unquote(attr_name)]))
    end
  end

  @doc """
  Expose a field with Map.get and options.
  """
  defmacro expose(attr_name, options) when is_atom(attr_name) and is_list(options) do
    options = Macro.escape(options)
    quote do
      @exposures(unquote(options)
      |> Keyword.put(:attr_name, unquote(attr_name))
      |> parse)
    end
  end

  @doc """
  Expose a field with custom function and options.
  """
  defmacro expose(attr_name, options, do_func) when is_atom(attr_name) and is_list(options) do
    options = Macro.escape(options)
    quote do
      @exposures(unquote(options)
      |> Keyword.put(:attr_name, unquote(attr_name))
      |> Keyword.put(:do_func, unquote(Macro.escape(do_func)))
      |> parse)
    end
  end

  @spec parse(Keyword.t) :: Maru.Entity.Struct.Exposure.t
  def parse(options) do
    pipeline = [
      :attr_name, :serializer, :if_func, :do_func
    ]
    accumulator = %{
      options:     options,
      runtime:     quote do %Runtime{} end,
    }
    Enum.reduce(pipeline, accumulator, &do_parse/2) |> Map.drop([:options])
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
      @doc """
      Return list of exposures.
      """
      @spec __exposures__ :: list(Runtime.t)
      def __exposures__ do
        unquote(exposures)
      end

      @doc """
      Serialize given instance into an object.
      """
      @spec serialize(Entity.instance, Entity.options, Keyword.t) :: Maru.Entity.object
      def serialize(instance, options \\ %{}, entity_options \\ []) do
        %Serializer{
          module:  __MODULE__,
          type:    is_list(instance) && :list || :one,
          options: options,
        } |> Maru.Entity.Runtime.serialize(instance, entity_options)
      end
    end
  end

end
