defmodule OAAS.Key do
  @moduledoc "Keys are API keys used by workers."

  @table "keys"

  @enforce_keys [:id]
  defstruct @enforce_keys

  @type t :: %__MODULE__{id: String.t()}

  @json_columns []

  use OAAS.Model
end
