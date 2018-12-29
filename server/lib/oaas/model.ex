defmodule OAAS.Model do
  @moduledoc "A generic database model with some CRUD ops."

  defmacro __using__(_) do
    quote do
      alias OAAS.DB
      import OAAS.Utils

      @model String.slice(@table, 0, String.length(@table) - 1)

      @doc "Gets all #{@table}, or a single #{@model} by ID."
      def get(_)

      @spec get :: {:ok, [t]} | {:error, term}
      def get do
        query("SELECT * FROM #{@table}")
      end

      @spec get(nil) :: {:error, :no_id}
      def get(nil) do
        {:error, :no_id}
      end

      @spec get(integer | String.t()) :: {:ok, t} | {:error, term}
      def get(id) do
        case query("SELECT * FROM #{@table} WHERE id = ?1", id: id) do
          {:ok, [m]} -> {:ok, m}
          {:ok, []} -> {:error, :no_such_entity}
          {:error, reason} -> {:error, reason}
        end
      end

      @doc "Insert a new #{@model}."
      @spec put(keyword) :: {:ok, t} | {:error, term}
      def put(cols) do
        now = System.system_time(:millisecond)
        cols = Keyword.merge([created_at: now, updated_at: now], cols)

        # Construct a SQL query: "INSERT INTO t (x, y, z) VALUES (?1, ?2, ?3)".
        sql =
          "INSERT INTO #{@table} (" <>
            (cols
             |> Keyword.keys()
             |> Enum.join(", ")) <>
            ") VALUES (" <> Enum.map_join(1..length(cols), ", ", fn i -> "?#{i}" end) <> ")"

        case query(sql, cols) do
          {:ok, _} ->
            cols
            |> Keyword.get_lazy(:id, fn ->
              case DB.query("SELECT LAST_INSERT_ROWID()") do
                {:ok, [["LAST_INSERT_ROWID()": i]]} -> i
                {:ok, _other} -> nil
                {:error, _reason} -> nil
              end
            end)
            |> get()

          {:error, reason} ->
            {:error, reason}
        end
      end

      @doc "Updates a #{@model}."
      @spec update(t, keyword) :: {:ok, t} | {:error, term}
      def update(m, cols) do
        cols = Keyword.put_new(cols, :updated_at, System.system_time(:millisecond))

        # Construct a SQL query: "UPDATE t SET x = ?1, y = ?2, z = ?3 WHERE id = ?4".
        sql =
          "UPDATE #{@table} SET " <>
            (cols
             |> Enum.with_index(1)
             |> Enum.map_join(", ", fn {{k, _v}, i} -> "#{to_string(k)} = ?#{i}" end)) <>
            "WHERE id = ?#{length(cols) + 1}"

        with {:ok, _} <- query(sql, cols ++ [id: m.id]),
             {:ok, m} <- get(m.id) do
          {:ok, m}
        else
          {:error, reason} -> {:error, reason}
        end
      end

      @doc "Deletes a #{@model} by ID."
      @spec delete(term) :: :ok | {:error, term}
      def delete(id) do
        sql = "DELETE FROM #{@table} WHERE id = ?1"

        case query(sql, x: id) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
      end

      # Execute a database query.
      @spec query(String.t(), keyword) :: {:ok, list} | {:error, term}
      defp query(sql, bind \\ []) do
        op =
          sql
          |> String.trim_leading()
          |> String.split()
          |> hd()
          |> String.upcase()

        bind =
          if op === "INSERT" or op === "UPDATE" do
            Enum.map(bind, fn {k, v} ->
              if k in @json_columns do
                case Jason.encode(v) do
                  {:ok, val} ->
                    val

                  {:error, reason} ->
                    notify(:warn, "encoding column `#{k}` failed", reason)
                    v
                end
              else
                v
              end
            end)
          else
            Keyword.values(bind)
          end

        case DB.query(sql, bind: bind) do
          {:ok, results} ->
            {:ok,
             if op === "SELECT" do
               Enum.map(results, fn row ->
                 Enum.map(row, fn {k, v} ->
                   if k in @json_columns do
                     case Jason.decode(v || "null") do
                       {:ok, val} ->
                         {k, val}

                       {:error, reason} ->
                         notify(:warn, "decoding column `#{k}` failed", reason)
                         {k, v}
                     end
                   else
                     {k, v}
                   end
                 end)
                 |> atom_map()
               end)
               |> Enum.map(&struct(__MODULE__, &1))
             else
               results
             end}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end
  end
end
