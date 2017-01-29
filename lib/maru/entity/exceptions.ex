defmodule Maru.Entity.Exceptions.SerializeError do
  defexception [:exception, :stack]

  def message(e) do
    e.exception.message
  end
end
