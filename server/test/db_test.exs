defmodule DBTest do
  use ExUnit.Case

  import OAAS.DB
  alias OAAS.DB

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
    assert {:ok, _} = query("INSERT INTO #{@table} VALUES (?1, ?2)", bind: [1, 2])
    assert {:ok, _} = query("INSERT INTO #{@table} VALUES (?1, ?2)", bind: [2, 3])

    assert {:ok, [[foo: 2]]} = query("SELECT foo FROM #{@table} WHERE id = ?1", bind: [1])
  end

  test "transaction/1" do
    assert {:error, _reason} =
             DB.transaction(fn ->
               with {:ok, _} <- query("INSERT INTO #{@table} VALUES (1, 2)"),
                    {:ok, _} <- query("INSERT INTO #{@table} VALUES (1, 2, 3)") do
                 nil
               else
                 {:error, reason} -> throw(reason)
               end
             end)

    assert {:ok, []} = query("SELECT * FROM #{@table}")

    assert {:ok, nil} =
             DB.transaction(fn ->
               with {:ok, _} <- query("INSERT INTO #{@table} VALUES (1, 2)"),
                    {:ok, _} <- query("INSERT INTO #{@table} VALUES (2, 3)") do
                 nil
               else
                 {:error, reason} -> throw(reason)
               end
             end)

    assert {:ok, [[id: 1, foo: 2], [id: 2, foo: 3]]} = query("SELECT * FROM #{@table}")

    assert {:error, :foo} = DB.transaction(fn -> throw(:foo) end)
  end
end
