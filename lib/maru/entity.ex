alias Maru.Entity.Utils
alias Maru.Entity.Struct.{Batch, Serializer, Exposure}
alias Maru.Entity.Struct.Exposure.{Runtime, Information}

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

  `%{reply: reply}` => `%{response: Reply.Entity.serializer(reply)}`

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
  @type group       :: list(atom)
  @type one_or_many :: :one | :many

  @doc false
  defmacro __using__(_) do
    quote do
      Module.register_attribute __MODULE__, :exposures, persist: true
      @group []
      @exposures []

      import          unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Extend another entity.

  Example:

      defmodule UserData do
        use Maru.Entity
        expose :name
        expose :address do
          expose :address1
          expose :address2
          expose :address_state
          expose :address_city
        end
        expose :email
        expose :phone
      end

      defmodule MailingAddress do
        use Maru.Entity
        extend UserData, only: [
          address: [:address1, :address2]
        ]
      end

      defmodule BasicInfomation do
        use Maru.Entity
        extend UserData, except: [:address]
      end
  """
  defmacro extend(module, options \\ []) do
    func =
      case {options[:only], options[:except]} do
        {nil, nil}    -> quote do fn _ -> true end end
        {nil, except} -> quote do fn i -> not Utils.attr_match?(i.information.attr_group, unquote(except)) end end
        {only,  nil}  -> quote do fn i -> Utils.attr_match?(i.information.attr_group, unquote(only)) end end
        {_, _}        -> raise ":only and :except conflict"
      end
    quote do
      unquote(module).__info__(:attributes)
      |> Keyword.get(:exposures)
      |> Enum.filter(unquote(func))
      |> Enum.each(fn exposure ->
        @exposures @exposures ++ [exposure]
      end)
    end
  end

  @doc """
  Expose a field or a set of fields with Map.get.
  """
  defmacro expose(attr_or_attrs), do: do_expose(attr_or_attrs, __CALLER__)

  @doc """
  Nested Exposure.
  """
  defmacro expose(group, [do: block]) when is_atom(group) do
    quote do
      group = @group
      @group @group ++ [unquote(group)]
      @exposures @exposures ++ [%Exposure{
        runtime: default_runtime(:group, @group),
        information: %Information{attr_group: @group},
      }]
      unquote(block)
      @group group
    end
  end


  @doc """
  Expose a field or a set of fields with Map.get and options.
  """
  defmacro expose(attr_or_attrs, options) when is_list(options),
    do: do_expose(attr_or_attrs, options, __CALLER__)

  @doc """
  Expose a field or a set of fields with custom function and options.
  """
  defmacro expose(attr_or_attrs, options, do_func) when is_list(options),
    do: do_expose(attr_or_attrs, options, do_func, __CALLER__)

  defp do_expose(attr_or_attrs, caller) do
    quote bind_quoted: [
      attr_or_attrs: attr_or_attrs,
      caller:     Macro.escape(caller)
    ] do
      for attr_name <- to_attr_list(attr_or_attrs) do
        @exposures @exposures ++ [parse(
          [
            attr_name: attr_name,
            group: @group ++ [attr_name],
          ],
          caller
        )]
      end
    end
  end

  defp do_expose(attr_or_attrs, options, caller) when is_list(options) do
    options = Macro.escape(options)

    quote bind_quoted: [
      attr_or_attrs: attr_or_attrs,
      caller:        Macro.escape(caller),
      options:       options
    ] do
      for attr_name <- to_attr_list(attr_or_attrs) do
        @exposures @exposures ++ [
          options
          |> Keyword.put(:attr_name, attr_name)
          |> Keyword.put(:group, @group ++ [attr_name])
          |> parse(caller)
        ]
      end
    end
  end

  defp do_expose(attr_or_attrs, options, do_func, caller) when is_list(options) do
    options = Macro.escape(options)

    quote bind_quoted: [
      attr_or_attrs: attr_or_attrs,
      caller:        Macro.escape(caller),
      do_func:       Macro.escape(do_func),
      options:       options
    ] do
      for attr_name <- to_attr_list(attr_or_attrs) do
        @exposures @exposures ++ [
          options
          |> Keyword.put(:attr_name, attr_name)
          |> Keyword.put(:group, @group ++ [attr_name])
          |> Keyword.put(:do_func, do_func)
          |> parse(caller)
        ]
      end
    end
  end

  def to_attr_list(attrs) when is_list(attrs), do: attrs
  def to_attr_list(attr) when is_atom(attr), do: [attr]

  @spec parse(Keyword.t, Module.t) :: Maru.Entity.Struct.Exposure.t
  def parse(options, caller) do
    pipeline = [
      :attr_name, :serializer, :if_func, :do_func, :build_struct,
    ]
    accumulator = %{
      options:     options,
      runtime:     quote do %Runtime{} end,
      information: %Information{},
    }
    Enum.reduce(pipeline, accumulator, &(do_parse(&1, &2, caller)))
  end

  defp do_parse(:attr_name, %{options: options, runtime: runtime, information: information}, _caller) do
    group     = options |> Keyword.fetch!(:group)
    attr_name = options |> Keyword.fetch!(:attr_name)
    param_key = options |> Keyword.get(:source, attr_name)
    options   = options |> Keyword.drop([:attr_name, :group, :source]) |> Keyword.put(:param_key, param_key)
    %{ options: options,
       runtime: quote do
         %{ unquote(runtime) |
            attr_group: unquote(group),
          }
       end,
       information: %{information | attr_group: group},
    }
  end

  defp do_parse(:if_func, %{options: options, runtime: runtime, information: information}, _caller) do
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
       end,
       information: information,
    }
  end

  defp do_parse(:serializer, %{options: options, runtime: runtime, information: information}, caller) do
    serializer =
      case Keyword.get(options, :using, nil) do
        nil -> nil
        {:__aliases__, _, _} = module ->
          %Serializer{module: Macro.expand(module, caller), type: :one}
        {{:., _, [Access, :get]}, _, [{:__aliases__, _, [:List]}, {:__aliases__, _, _} = module,]} ->
          %Serializer{module: Macro.expand(module, caller), type: :many}
      end

    %{ options: options |> Keyword.drop([:using]),
       runtime: quote do
         %{ unquote(runtime) |
            serializer: unquote(Macro.escape(serializer))
         }
       end,
       information: information,
     }
  end

  defp do_parse(:do_func, %{options: options, runtime: runtime, information: information}, _caller) do
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
       end,
       information: information,
    }
  end

  defp do_parse(:build_struct, %{runtime: runtime, information: information}, _caller) do
    %Exposure{runtime: runtime, information: information}
  end

  @doc """
  Generate default runtime struct.
  """
  @spec default_runtime(atom(), group()) :: Macro.t
  def default_runtime(:group, group) do
    quote do
      %Runtime{
        attr_group: unquote(group),
        if_func: fn (_, _) -> true end,
        do_func: fn (_, _) -> %{} end,
      }
    end
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
          type:    is_list(instance) && :many || :one,
          options: options,
        } |> Maru.Entity.Runtime.serialize(instance, entity_options)
      end
    end
  end
end
