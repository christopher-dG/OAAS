defmodule DBTest do
  use ExUnit.Case

  alias ReplayFarm.DB
  require DB

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

  test "query!/2" do
    DB.query!("INSERT INTO #{@table} VALUES (?1, ?2)", bind: [1, 2])
    DB.query!("INSERT INTO #{@table} VALUES (?1, ?2)", bind: [2, 3])

    assert DB.query!("SELECT foo FROM #{@table} WHERE id = ?1", bind: [1]) === [[foo: 2]]
  end

  test "transaction!/1" do
    assert_raise RuntimeError, fn ->
      DB.transaction! do
        DB.query!("INSERT INTO #{@table} VALUES (1, 2)")
        DB.query!("INSERT INTO #{@table} VALUES (1, 2, 3)")
      end
    end

    assert DB.query!("SELECT * FROM #{@table}") === []

    DB.transaction! do
      DB.query!("INSERT INTO #{@table} VALUES (1, 2)")
      DB.query!("INSERT INTO #{@table} VALUES (2, 3)")
    end

    assert DB.query!("SELECT * FROM #{@table}") === [[id: 1, foo: 2], [id: 2, foo: 3]]
  end
end
