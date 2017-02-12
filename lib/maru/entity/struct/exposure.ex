defmodule Maru.Entity.Struct.Exposure do
  @moduledoc false

  @type t :: %__MODULE__{
    runtime: Maru.Entity.Struct.Exposure.Runtime.t
  }

  defstruct runtime: nil
end

defmodule Maru.Entity.Struct.Exposure.Runtime do
  @moduledoc false

  @type t :: %__MODULE__{
    attr_group: list(atom | String.t),
    if_func:    (Maru.Entity.instance, Keyword.t -> boolean),
    do_func:    (Maru.Entity.instance, Keyword.t -> any),
    serializer: Maru.Entity.Struct.Serializer.t | nil,
  }

  defstruct attr_group: nil,
            if_func:    nil,
            do_func:    nil,
            serializer: nil

end


defmodule Maru.Entity.Struct.Serializer do
  @moduledoc false

  @type t :: %__MODULE__{
    module:  module,
    type:    Maru.Entity.one_or_list,
    options: Keyword.t,
  }

  defstruct module:  nil,
            type:    nil,
            options: nil
end

defmodule Maru.Entity.Struct.Instance do
  @moduledoc false

  @type t :: %__MODULE__{
    data:  Maru.Entity.object,
    links: list({atom | String.t, Maru.Entity.one_or_list, Maru.Entity.Runtime.id}),
  }

  defstruct data: %{},
            links: []

end

defmodule Maru.Entity.Struct.Batch do
  @moduledoc false

  @type t :: %__MODULE__{
    module:  module,
    key:     atom | String.t,
  }

  defstruct module: nil,
            key:    nil
end
