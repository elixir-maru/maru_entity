alias Maru.Entity.Struct.Batch
alias Maru.Entity.Struct.Instance
alias Maru.Entity.Struct.Serializer
alias Maru.Entity.Struct.Exposure

defmodule Maru.Entity.Runtime do
  @moduledoc """
  Serialize an instance concurrently.
  """

  @type id :: reference
  @type state :: %{
          data: :ets.tab(),
          old_link: :ets.tab(),
          new_link: :ets.tab(),
          old_batch: :ets.tab(),
          new_batch: :ets.tab(),
          max_concurrency: pos_integer
        }

  @doc false
  @spec serialize(Serializer.t(), Maru.Entity.instance(), Entity.options()) ::
          Maru.Entity.object()
  def serialize(serializer, instance, options) do
    state = init(options)
    id = save_link(serializer, instance, state.old_link)
    state = do_loop(state, serializer.options)
    terminate(id, serializer.type, serializer.options, state)
  end

  @spec init(Keyword.t()) :: state
  defp init(options) do
    max_concurrency =
      Keyword.get(options, :max_concurrency) ||
        Application.get_env(:maru_entity, :default_max_concurrency) ||
        System.schedulers_online() * 4

    exposure_filter_funcs =
      for {entity_module, options} <- Keyword.drop(options, [:max_concurrency]) do
        only = Keyword.get(options, :only, nil)
        except = Keyword.get(options, :except, nil)
        attr_groups = flat_attrs(only || except || [], [])

        filter_func =
          cond do
            not is_nil(only) and not is_nil(except) ->
              raise ":only and :except are in conflict!"

            not is_nil(only) ->
              fn exposure ->
                Enum.any?(
                  attr_groups,
                  &(start_with?(exposure.attr_group, &1) in [true, :exactly])
                )
              end

            not is_nil(except) ->
              fn exposure ->
                Enum.all?(
                  attr_groups,
                  &(start_with?(exposure.attr_group, &1) in [false, :exactly])
                )
              end

            true ->
              fn _ -> true end
          end

        {entity_module, filter_func}
      end

    %{
      data: create_ets(:duplicate_bag),
      old_link: create_ets(:duplicate_bag),
      new_link: create_ets(:duplicate_bag),
      old_batch: create_ets(:set),
      new_batch: create_ets(:set),
      max_concurrency: max_concurrency,
      exposure_filter_funcs: exposure_filter_funcs
    }
  end

  defp flat_attrs([], result), do: result

  defp flat_attrs([{key, nested} | t], result) do
    new_result =
      for nested_result <- flat_attrs(nested, []) do
        [key | nested_result]
      end

    flat_attrs(t, new_result ++ [[key]] ++ result)
  end

  defp flat_attrs([h | t], result) do
    flat_attrs(t, [[h, :*] | result])
  end

  defp start_with?([], []), do: :exactly
  defp start_with?(_, [:*]), do: true
  defp start_with?([h | t1], [h | t2]), do: start_with?(t1, t2)
  defp start_with?(_, _), do: false

  @spec terminate(id, Maru.Entity.one_or_many(), Entity.options(), state) :: Maru.Entity.object()
  defp terminate(id, type, options, state) do
    :ets.delete(state.old_link)
    :ets.delete(state.new_link)
    :ets.delete(state.old_batch)
    :ets.delete(state.new_batch)
    data = do_build(id, type, options, state.data)
    :ets.delete(state.data)
    data
  end

  @spec create_ets(:set | :duplicate_bag) :: :ets.tab()
  defp create_ets(type) when type in [:set, :duplicate_bag] do
    :ets.new(:maru_entity_serializer, [
      type,
      :public,
      heir: :none,
      write_concurrency: true,
      read_concurrency: true
    ])
  end

  @spec save_link(Serializer.t(), Maru.Entity.instance(), :ets.tab()) :: id
  defp save_link(%Serializer{type: :one} = s, instance, ets) do
    id = make_ref()
    :ets.insert(ets, {id, s, instance, nil})
    id
  end

  defp save_link(%Serializer{type: :many} = s, instances, ets) do
    id = make_ref()

    instances
    |> Stream.with_index()
    |> Enum.each(fn {i, idx} ->
      :ets.insert(ets, {id, s, i, idx})
    end)

    id
  end

  @spec do_build(id, Maru.Entity.one_or_many(), Entity.options(), :ets.tab()) ::
          Maru.Entity.object() | [Maru.Entity.object()]
  defp do_build(id, :one, options, ets) do
    [{_id, i, nil}] = :ets.lookup(ets, id)
    do_build_one(i, options, ets)
  end

  defp do_build(id, :many, options, ets) do
    :ets.lookup(ets, id)
    |> Enum.sort(fn {_, _, idx1}, {_, _, idx2} ->
      idx1 < idx2
    end)
    |> Enum.map(fn {_id, i, _idx} ->
      do_build_one(i, options, ets)
    end)
  end

  @spec do_build_one(Instance.t(), Entity.options(), :ets.tab()) :: Maru.Entity.object()
  defp do_build_one(%Instance{data: data, links: links, module: module}, options, ets) do
    links
    |> Enum.reduce(data, fn {attr_group, type, id}, acc ->
      put_in(acc, attr_group, do_build(id, type, options, ets))
    end)
    |> case do
      result when is_nil(module) ->
        result

      result ->
        module.before_finish(result, options)
    end
  end

  @spec do_loop(state, Entity.options()) :: state
  defp do_loop(state, options) do
    unless :ets.info(state.old_link)[:size] == 0 do
      do_loop_link_monitor(state)
    end

    unless :ets.info(state.old_batch)[:size] == 0 do
      :ets.delete_all_objects(state.old_link)
      do_loop_batch(state, options)
      do_loop_link_monitor(state)
    end

    case :ets.info(state.new_link)[:size] + :ets.info(state.new_batch)[:size] do
      0 ->
        state

      _ ->
        :ets.delete_all_objects(state.old_link)
        :ets.delete_all_objects(state.old_batch)

        %{
          state
          | old_link: state.new_link,
            new_link: state.old_link,
            old_batch: state.new_batch,
            new_batch: state.old_batch
        }
        |> do_loop(options)
    end
  end

  @spec do_loop_link_monitor(state) :: :ok
  defp do_loop_link_monitor(state) do
    parent = self()
    {pid, ref} = Process.spawn(fn -> do_loop_link(parent, state) end, [:monitor])

    receive do
      {:DOWN, ^ref, :process, ^pid, :normal} ->
        :ok

      {:DOWN, ^ref, :process, ^pid, reason} ->
        {:error, exception, stack} = reason
        :erlang.raise(:error, exception, stack)
    end
  end

  @spec do_loop_link(pid, state) :: :ok
  defp do_loop_link(parent, state) do
    Process.flag(:trap_exit, true)
    parent_ref = Process.monitor(parent)

    sync = fn continue ->
      receive do
        {:EXIT, _pid, :normal} ->
          continue.()

        {:EXIT, _pid, reason} ->
          exit(reason)

        {:DOWN, ^parent_ref, :process, ^parent, _} ->
          exit(:kill)
      end
    end

    {_, rest} =
      :ets.foldl(
        fn
          term, {0, rest} ->
            sync.(fn -> Process.spawn(__MODULE__, :do_serialize, [term, state], [:link]) end)
            {0, rest}

          term, {num, rest} ->
            Process.spawn(__MODULE__, :do_serialize, [term, state], [:link])
            {num - 1, rest + 1}
        end,
        {state.max_concurrency, 0},
        state.old_link
      )

    for _ <- :lists.seq(1, rest) do
      sync.(fn -> :ok end)
    end

    :ok
  end

  @spec do_loop_batch(state, Entity.options()) :: :ok
  defp do_loop_batch(state, options) do
    data =
      :ets.foldl(
        fn {id, serializer, %Batch{module: module, key: key}}, acc ->
          case acc do
            %{^module => value} ->
              value = Map.put(value, key, {id, serializer})
              Map.put(acc, module, value)

            _ ->
              Map.put(acc, module, %{
                key => {id, serializer}
              })
          end
        end,
        %{},
        state.old_batch
      )
      |> Enum.map(fn
        {module, value} -> {module, Task.async(module, :resolve, [Map.keys(value), options])}
      end)
      |> Enum.map(fn
        {module, task} -> {module, Task.await(task, :infinity)}
      end)
      |> Enum.into(%{})

    :ets.foldl(
      fn
        {id, %Serializer{type: :many} = s, %Batch{module: module, key: key}}, _ ->
          data
          |> Map.get(module, %{})
          |> Map.get(key, [])
          |> Stream.with_index()
          |> Enum.each(fn {instance, idx} ->
            :ets.insert(state.old_link, {id, %{s | type: :one}, instance, idx})
          end)

          :ok

        {id, %Serializer{type: :one} = s, %Batch{module: module, key: key}}, _ ->
          instance = get_in(data, [module, key])
          :ets.insert(state.old_link, {id, s, instance, nil})
          :ok

        {id, nil, %Batch{module: module, key: key}}, _ ->
          instance = get_in(data, [module, key])
          :ets.insert(state.old_link, {id, nil, instance, nil})
          :ok
      end,
      :ok,
      state.old_batch
    )
  end

  @doc false
  @spec do_serialize({id, Serializer.t() | nil, Maru.Entity.instance(), integer}, state) :: :ok
  def do_serialize({id, nil, instance, idx}, state) do
    result = %Instance{data: instance, links: []}
    :ets.insert(state.data, {id, result, idx})
    :ok
  end

  def do_serialize({id, serializer, instance, idx}, state) do
    result =
      case serializer.module.before_serialize(instance, serializer.options) do
        {:halt, result} ->
          %Instance{module: serializer.module, data: result}

        {:ok, instance, options, data} ->
          exposure_filter_func =
            Keyword.get(
              state.exposure_filter_funcs,
              serializer.module,
              fn _ -> true end
            )

          exposures = Enum.filter(serializer.module.__exposures__, exposure_filter_func)

          do_serialize(
            exposures,
            %Instance{module: serializer.module, data: data},
            instance,
            options,
            state
          )

        {:ok, attrs, instance, options, data} ->
          exposure_filter_func =
            Keyword.get(
              state.exposure_filter_funcs,
              serializer.module,
              fn _ -> true end
            )

          exposures =
            serializer.module.__exposures__
            |> Enum.filter(exposure_filter_func)
            |> Enum.filter(fn exposure ->
              exposure.attr_group in Enum.map(attrs, &List.wrap/1)
            end)

          do_serialize(
            exposures,
            %Instance{module: serializer.module, data: data},
            instance,
            options,
            state
          )
      end

    :ets.insert(state.data, {id, result, idx})
    :ok
  rescue
    e -> exit({:error, e, System.stacktrace()})
  end

  @spec do_serialize(
          list(Exposure.Runtime.t()),
          Maru.Entity.object(),
          Maru.Entity.instance(),
          Maru.Entity.options(),
          state
        ) :: Maru.Entity.object()
  defp do_serialize([], result, _instance, _options, _state), do: result

  defp do_serialize([h | t], result, instance, options, state) do
    h.if_func.(instance, options)
    |> case do
      true ->
        try do
          value =
            get_in(result.data, h.attr_group) ||
              case h.do_func do
                f when is_function(f, 1) -> f.(instance)
                f when is_function(f, 2) -> f.(instance, options)
                f when is_function(f, 3) -> f.(instance, options, result.data)
              end

          {:ok, (is_nil(value) && h.default) || value}
        rescue
          e ->
            result.module.handle_error(h.attr_group, e, result.data)
        end

      false ->
        :skip
    end
    |> case do
      {:ok, value} ->
        result = do_update(h.serializer, value, h, result, options, state)
        do_serialize(t, result, instance, options, state)

      {:halt, data} ->
        %Instance{result | data: data, links: []}

      :skip ->
        do_serialize(t, result, instance, options, state)
    end
  end

  @spec do_update(
          Serializer.t() | nil,
          Batch.t() | Maru.Entity.instance(),
          Exposure.Runtime.t(),
          Maru.Entity.instance(),
          Maru.Entity.options(),
          state
        ) :: Maru.Entity.instance()
  defp do_update(nil, %Batch{} = batch, field, result, _options, state) do
    id = make_ref()
    :ets.insert(state.new_batch, {id, nil, batch})

    %Instance{
      result
      | data: put_in(result.data, field.attr_group, :unlinked),
        links: [{field.attr_group, :one, id} | result.links]
    }
  end

  defp do_update(serializer, %Batch{} = batch, field, result, options, state) do
    id = make_ref()
    s = %{serializer | options: options}
    :ets.insert(state.new_batch, {id, s, batch})

    %Instance{
      result
      | data: put_in(result.data, field.attr_group, :unlinked),
        links: [{field.attr_group, serializer.type, id} | result.links]
    }
  end

  defp do_update(nil, instance, field, result, _options, _state) do
    %{result | data: put_in(result.data, field.attr_group, instance)}
  end

  defp do_update(serializer, instance, field, result, options, state) do
    s = %{serializer | options: options}
    id = save_link(s, instance, state.new_link)

    %Instance{
      result
      | data: put_in(result.data, field.attr_group, :unlinked),
        links: [{field.attr_group, serializer.type, id} | result.links]
    }
  end
end
