defmodule DBTest do
  use ExUnit.Case

  import ReplayFarm.DB
  alias ReplayFarm.DB

  @table "db_test"

  setup_all do
    {:ok, _} =
      Sqlitex.Server.query(
        DB,
        """
        CREATE TABLE IF NOT EXISTS #{@table}(
          id INTEGER PRIMARY KEY,
          foo INTEGER
        )
        """
      )

    on_exit(fn -> Sqlitex.Server.query(DB, "DROP TABLE #{@table}") end)

    {:ok, []}
  end

  setup do
    {:ok, _} = Sqlitex.Server.query(DB, "DELETE FROM #{@table}")
    {:ok, []}
  end

  test "query/2" do
    {:ok, _} = query("INSERT INTO #{@table} VALUES (?1, ?2)", bind: [1, 2])
    {:ok, _} = query("INSERT INTO #{@table} VALUES (?1, ?2)", bind: [2, 3])

    {:ok, [[foo: 2]]} = query("SELECT foo FROM #{@table} WHERE id = ?1", bind: [1])
  end

  test "transaction/1" do
    {:error, _} =
      DB.transaction do
        with {:ok, _} <- query("INSERT INTO #{@table} VALUES (1, 2)"),
             {:ok, _} <- query("INSERT INTO #{@table} VALUES (1, 2, 3)") do
          {:ok, nil}
        else
          {:error, err} -> {:error, err}
        end
      end

    {:ok, []} = query("SELECT * FROM #{@table}")

    {:ok, _} =
      transaction do
        with {:ok, _} <- query("INSERT INTO #{@table} VALUES (1, 2)"),
             {:ok, _} <- query("INSERT INTO #{@table} VALUES (2, 3)") do
          {:ok, nil}
        else
          {:error, err} -> {:error, err}
        end
      end

    assert query("SELECT * FROM #{@table}") === {:ok, [[id: 1, foo: 2], [id: 2, foo: 3]]}
  end
end
