defmodule ReplayFarm.Model do
  @moduledoc "A generic database model with some CRUD ops."

  defmacro __using__(_) do
    quote do
      require Logger

      alias ReplayFarm.DB

      @model String.slice(@table, 0, String.length(@table) - 1)

      @doc "Gets all #{@table}, or a single #{@model} by ID."
      def get!(_)

      @spec get! :: [t]
      def get! do
        query!("SELECT * FROM #{@table}") |> Enum.map(&struct(__MODULE__, &1))
      end

      @spec get!(term) :: t | nil
      def get!(id) do
        case query!("SELECT * FROM #{@table} WHERE id = ?1", id: id) do
          [] -> nil
          [m] -> struct(__MODULE__, m)
        end
      end

      @doc "Insert a new #{@model}."
      @spec put!(keyword) :: t
      def put!(cols) when is_list(cols) do
        now = System.system_time(:millisecond)
        cols = Keyword.merge([created_at: now, updated_at: now], cols)

        # Construct a SQL query: "INSERT INTO t (x, y, z) VALUES (?1, ?2, ?3)".
        sql =
          "INSERT INTO #{@table} (" <>
            (cols
             |> Keyword.keys()
             |> Enum.join(", ")) <>
            ") VALUES (" <> Enum.map_join(1..length(cols), ", ", fn i -> "?#{i}" end) <> ")"

        query!(sql, cols)

        cols
        |> Keyword.get_lazy(:id, fn ->
          query!("SELECT LAST_INSERT_ROWID()") |> hd() |> Map.get(:"LAST_INSERT_ROWID()")
        end)
        |> get!()
      end

      @doc "Updates a #{@model}."
      @spec update!(t, keyword) :: t
      def update!(%__MODULE__{} = m, cols) when is_list(cols) do
        cols = Keyword.put_new(cols, :updated_at, System.system_time(:millisecond))

        # Construct a SQL query: "UPDATE t SET x = ?1, y = ?2, z = ?3 WHERE id = ?4".
        sql =
          "UPDATE #{@table} SET " <>
            (cols
             |> Enum.with_index(1)
             |> Enum.map_join(", ", fn {{k, _v}, i} -> "#{to_string(k)} = ?#{i}" end)) <>
            "WHERE id = ?#{length(cols) + 1}"

        query!(sql, cols ++ [id: m.id])
        get!(m.id)
      end

      # Execute a database query.
      # The binding list MUST be in the same order as they are to be inserted in the query!
      @spec query!(binary, keyword) :: list
      def query!(sql, bind \\ []) do
        op = sql |> String.trim_leading() |> String.split() |> hd() |> String.upcase()

        bind =
          if op === "INSERT" or op === "UPDATE" do
            Enum.map(bind, fn {k, v} ->
              if k in @json_columns do
                case Jason.encode(v) do
                  {:ok, val} ->
                    val

                  {:error, err} ->
                    Logger.warn("Encoding column #{k} failed: #{inspect(err)}")
                    v
                end
              else
                v
              end
            end)
          else
            Keyword.values(bind)
          end

        results = DB.query!(sql, bind: bind)

        if op === "SELECT" do
          Enum.map(results, fn row ->
            Enum.map(row, fn {k, v} ->
              if k in @json_columns do
                case Jason.decode(v || "null") do
                  {:ok, val} ->
                    {k, val}

                  {:error, err} ->
                    Logger.warn("Decoding column #{k} failed: #{inspect(err)}") && {k, v}
                end
              else
                {k, v}
              end
            end)
            |> Map.new()
          end)
        else
          results
        end
      end
    end
  end
end
