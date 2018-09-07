defmodule ReplayFarm.Model do
  defmacro __using__(_) do
    quote do
      alias ReplayFarm.DB

      @model String.slice(@table, 0, String.length(@table) - 1)

      @doc "Gets all models, or a single model by ID."
      def get!(_)

      @spec get! :: [t]
      def get! do
        sql = "SELECT * FROM #{@table}"
        DB.query!(sql, decode: @json_columns) |> Enum.map(&struct(__MODULE__, &1))
      end

      @spec get!(term) :: t | nil
      def get!(id) do
        sql = "SELECT * FROM #{@table} WHERE id = ?1"
        bind = [id]

        case DB.query!(sql, bind: bind, decode: @json_columns) do
          [] -> nil
          [m] -> struct(__MODULE__, m)
        end
      end

      @doc "Insert a new model."
      @spec put!(keyword) :: t
      def put!(cols) when is_list(cols) do
        now = System.system_time(:millisecond)
        cols = Keyword.merge([created_at: now, updated_at: now], cols)

        sql =
          "INSERT INTO #{@table} (" <>
            (cols
             |> Keyword.keys()
             |> Enum.join(", ")) <>
            ") VALUES (" <> Enum.map_join(1..length(cols), ", ", fn i -> "?#{i}" end) <> ")"

        bind = Keyword.values(cols)
        id = Keyword.get(cols, :id)

        DB.query!(sql, bind: bind)

        id =
          if is_nil(id) do
            DB.query!("SELECT LAST_INSERT_ROWID()")[:"LAST_INSERT_ROWID()"]
          else
            id
          end

        get!(id)
      end

      @doc "Updates a model."
      @spec update!(t, keyword) :: t
      def update!(%__MODULE__{} = m, cols) when is_list(cols) do
        cols = Keyword.put_new(cols, :updated_at, System.system_time(:millisecond))

        sql =
          "UPDATE #{@table} SET " <>
            (cols
             |> Enum.with_index(1)
             |> Enum.map_join(", ", fn {{k, _v}, i} -> "#{to_string(k)} = ?#{i}" end)) <>
            "WHERE id = ?#{length(cols) + 1}"

        binds = Keyword.values(cols) ++ [m.id]

        DB.query!(sql, bind: binds)
        get!(m.id)
      end
    end
  end
end
