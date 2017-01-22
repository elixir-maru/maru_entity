defmodule Maru.Entity.Struct.Exposure do
  @moduledoc false

  defstruct information: nil,
            runtime: nil
end

defmodule Maru.Entity.Struct.Exposure.Information do
  @moduledoc false

  defstruct todo: nil
  # TODO
end

defmodule Maru.Entity.Struct.Exposure.Runtime do
  @moduledoc false

  defstruct attr_name:  nil,
            if_func:    nil,
            do_func:    nil,
            serializer: nil

end


defmodule Maru.Entity.Struct.Serializer do
  @moduledoc false

  defstruct module:  nil,
            type:    nil,
            options: nil
end

defmodule Maru.Entity.Struct.Instance do
  defstruct data: %{},
            links: []

end

defmodule Maru.Entity.Struct.Batch do
  defstruct module: nil,
            key:    nil
end
