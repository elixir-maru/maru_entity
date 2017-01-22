alias Maru.Entity.Struct.Batch
alias Maru.Entity.Struct.Instance
alias Maru.Entity.Struct.Serializer

defmodule Maru.Entity.Runtime do
  def serialize(serializer, instance) do
    state = init()
    id = save_link(serializer, instance, state)
    do_loop(state)
    terminate(id, serializer.type, state)
  end


  defp init do
    %{ data:      create_ets(:duplicate_bag),
       old_link:  create_ets(:duplicate_bag),
       new_link:  create_ets(:duplicate_bag),
       old_batch: create_ets(:set),
       new_batch: create_ets(:set),
       max_concurrency: 4,
    }
  end


  defp terminate(id, type, state) do
    :ets.delete(state.old_link)
    :ets.delete(state.new_link)
    :ets.delete(state.old_batch)
    :ets.delete(state.new_batch)

    data = do_build(id, type, state.data)
    :ets.delete(state.data)
    data
  end


  defp create_ets(type) when type in [:set, :duplicate_bag] do
    :ets.new(:maru_entity_serializer, [
      type, :public, heir: :none, write_concurrency: true, read_concurrency: true
    ])
  end


  defp save_link(%Serializer{type: :one}=s, instance, state) do
    id = make_ref()
    :ets.insert(state.old_link, {id, s, instance})
    id
  end


  defp save_link(%Serializer{type: :list}=s, instances, state) do
    id = make_ref()
    Enum.each(instances, fn i ->
      :ets.insert(state.old_link, {id, s, i})
    end)
    id
  end


  defp do_build(id, :one, ets) do
    case :ets.lookup(ets, id) do
      []         -> IO.puts "miss #{inspect id}" # TODO handle error
      [{_id, i}] -> do_build_one(i, ets)
    end
  end

  defp do_build(id, :list, ets) do
    :ets.lookup(ets, id)
    |> Enum.map(fn {_id, i} ->
      do_build_one(i, ets)
    end)
  end


  defp do_build_one(%Instance{data: data, links: []}, _ets), do: data
  defp do_build_one(%Instance{data: data, links: links}, ets) do
    Enum.reduce(links, data, fn {attr_name, type, id}, acc ->
        put_in(acc, attr_name, do_build(id, type, ets))
    end)
  end


  defp do_loop(state) do
    unless :ets.info(state.old_link)[:size] == 0 do
      do_loop_link(state)
    end

    unless :ets.info(state.old_batch)[:size] == 0 do
      :ets.delete_all_objects(state.old_link)
      do_loop_batch(state)
      do_loop_link(state)
    end

    case :ets.info(state.new_link)[:size] + :ets.info(state.new_batch)[:size] do
      0 -> state
      _ ->
        :ets.delete_all_objects(state.old_link)
        :ets.delete_all_objects(state.old_batch)
        %{ state |
           old_link:  state.new_link,
           new_link:  state.old_link,
           old_batch: state.new_batch,
           new_batch: state.old_batch,
        } |> do_loop
    end
  end


  defp do_loop_link(state) do
    {_, rest} = :ets.foldl(fn
      term, {0, rest} ->
        receive do
          {:DOWN, _ref, :process, _pid, :normal} ->
            Process.spawn(__MODULE__, :do_serialize, [term, state], [:monitor])
        end
        {0, rest}
      term, {num, rest} ->
        Process.spawn(__MODULE__, :do_serialize, [term, state], [:monitor])
        {num - 1, rest + 1}
    end, {state.max_concurrency, 0}, state.old_link)

    for _ <- 1..rest do
      receive do
        {:DOWN, _ref, :process, _pid, :normal} -> :ok
      end
    end
  end


  defp do_loop_batch(state) do
    data =
      :ets.foldl(fn {id, serializer, %Batch{module: module, key: key}}, acc ->
        case acc do
          %{^module => value} ->
            value = Map.put(value, key, {id, serializer})
            Map.put(acc, module, value)
          _ ->
            Map.put(acc, module, %{
              key => {id, serializer}
            })
        end
      end, %{}, state.old_batch)
      |> Enum.map(fn {module, value} ->
        {module, Task.async(module, :resolve, [Map.keys(value)])}
      end)
      |> Enum.map(fn {module, task} ->
        {module, Task.await(task)}
      end)
      |> Enum.into(%{})

    :ets.foldl(fn
      {id, %Serializer{type: :list}=s, %Batch{module: module, key: key}}, _ ->
        data |> get_in([module, key]) |> Enum.each(fn instance ->
          :ets.insert(state.old_link, {id, %{s | type: :one}, instance})
        end)
        :ok
      {id, s, %Batch{module: module, key: key}}, _ ->
        instance = get_in(data, [module, key])
        :ets.insert(state.old_link, {id, %{s | type: :one}, instance})
        :ok
    end, :ok, state.old_batch)
  end


  def do_serialize({id, serializer, instance}, state) do
    exposures = serializer.module.__exposures__
    result = do_serialize(exposures, %Instance{}, instance, serializer.options, state)
    :ets.insert(state.data, {id, result})
  end

  defp do_serialize([], result, _instance, _options, _state), do: result
  defp do_serialize([h | t], result, instance, options, state) do
    result =
      if h.if_func.(instance, options) do
        do_update(h.serializer, h.do_func.(instance, options), h, result, options, state)
      else
        result
      end
    do_serialize(t, result, instance, options, state)
  end


  defp do_update(nil, %Batch{}=batch, field, result, _options, state) do
    id = make_ref()
    :ets.insert(state.new_batch, {id, nil, batch})
    %Instance{
      data: put_in(result.data, field.attr_name, nil),
      links: [{field.attr_name, :one, id} | result.links],
    }
  end

  defp do_update(%Serializer{type: :one}=s, %Batch{}=batch, field, result, options, state) do
    id = make_ref()
    s = %{s | options: options}
    :ets.insert(state.new_batch, {id, s, batch})
    %Instance{
      data: put_in(result.data, field.attr_name, nil),
      links: [{field.attr_name, :one, id} | result.links],
    }
  end

  defp do_update(%Serializer{type: :list}=s, %Batch{}=batch, field, result, options, state) do
    id = make_ref()
    s = %{s | options: options}
    :ets.insert(state.new_batch, {id, s, batch})
    %Instance{
      data: put_in(result.data, field.attr_name, nil),
      links: [{field.attr_name, :list, id} | result.links],
    }
  end

  defp do_update(nil, instance, field, result, _options, _state) do
    %{ result |
       data: put_in(result.data, field.attr_name, instance),
    }
  end

  defp do_update(%Serializer{type: :one}=s, instance, field, result, options, state) do
    id = make_ref()
    s = %{s | options: options}
    :ets.insert(state.new_link, {id, s, instance})
    %Instance{
      data: put_in(result.data, field.attr_name, nil),
      links: [{field.attr_name, :one, id} | result.links],
    }
  end

  defp do_update(%Serializer{type: :list}=s, instances, field, result, options, state) do
    id = make_ref()
    s = %{s | options: options}
    Enum.each(instances, fn i ->
      :ets.insert(state.new_link, {id, s, i})
    end)
    %Instance{
      data: put_in(result.data, field.attr_name, nil),
      links: [{field.attr_name, :list, id} | result.links],
    }
  end

end
