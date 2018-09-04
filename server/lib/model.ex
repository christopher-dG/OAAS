defmodule ReplayFarm.Model do
  defmacro __using__(_) do
    quote do
      alias ReplayFarm.DB

      @model String.slice(@table, 0, String.length(@table) - 1)

      @doc "Gets all models, or a single model by ID."
      def get(_)

      @spec get :: {:ok, [t]} | {:error, term}
      def get do
        sql = "SELECT * FROM #{@table}"

        case DB.query(sql, decode: @json_columns) do
          {:ok, ms} -> Enum.map(ms, &struct(__MODULE__, &1))
          {:error, err} -> {:error, err}
          _ -> {:error, :unknown}
        end
      end

      @spec get(term) :: {:ok, t} | {:error, term}
      def get(id) do
        sql = "SELECT * FROM #{@table} WHERE id = ?1"
        bind = [id]

        case DB.query(sql, bind: bind, decode: @json_columns) do
          {:ok, []} -> {:error, :"#{@model}_not_found"}
          {:ok, [m]} -> {:ok, struct(__MODULE__, m)}
          {:error, err} -> {:error, err}
          _ -> {:error, :unknown}
        end
      end

      @doc "Insert a new model."
      @spec put(keyword) :: {:ok, t} | {:error, term}
      def put(cols) when is_list(cols) do
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

        case DB.query(sql, bind: bind) do
          {:ok, _} ->
            if is_nil(id) do
              case DB.query("SELECT LAST_INSERT_ROWID()") do
                {:ok, [%{"LAST_INSERT_ROWID()": id}]} -> get(id)
                {:error, err} -> {:error, err}
              end
            else
              get(id)
            end

          {:error, err} ->
            {:error, err}
        end
      end

      @doc "Updates a model."
      @spec update(t, keyword) :: {:ok, t} | {:error, term}
      def update(%__MODULE__{} = m, cols) when is_list(cols) do
        cols = Keyword.put_new(cols, :updated_at, System.system_time(:millisecond))

        sql =
          "UPDATE #{@table} SET " <>
            (cols
             |> Enum.with_index(1)
             |> Enum.map_join(", ", fn {{k, _v}, i} -> "#{to_string(k)} = ?#{i}" end)) <>
            "WHERE id = ?#{length(cols) + 1}"

        binds = Keyword.values(cols) ++ [m.id]

        case DB.query(sql, bind: binds) do
          {:ok, _} -> get(m.id)
          {:error, err} -> {:error, err}
        end
      end
    end
  end
end
