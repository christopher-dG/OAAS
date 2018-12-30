defmodule OAAS.Key do
  @moduledoc "An API key used by a worker."

  @table "keys"

  @enforce_keys [:id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{id: String.t()}

  @json_columns []

  use OAAS.Model
end
