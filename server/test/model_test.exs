defmodule TestModel do
  alias ReplayFarm.DB

  @table "model_test"

  @enforce_keys [:id]
  defstruct [:id, :foo, :bar]

  @type t :: %__MODULE__{
          id: binary,
          foo: map,
          bar: integer
        }

  @json_columns [:foo]

  use ReplayFarm.Model

  def test_get!(id) do
    {:ok, rs} =
      Sqlitex.Server.query(
        DB,
        "SELECT * FROM #{@table} WHERE id = ?1",
        bind: [id],
        into: %{}
      )

    case rs do
      [] -> nil
      [r] -> r
    end
  end

  def test_put!(id, foo \\ nil, bar \\ nil) do
    now = System.system_time(:millisecond)

    {:ok, _} =
      Sqlitex.Server.query(
        DB,
        "INSERT INTO #{@table} VALUES (?1, ?2, ?3, ?4, ?5)",
        bind: [id, foo, bar, now, now]
      )
  end
end

defmodule ModelTest do
  use ExUnit.Case

  alias ReplayFarm.DB

  @table "model_test"

  setup_all do
    {:ok, _} =
      Sqlitex.Server.query(
        DB,
        """
        CREATE TABLE IF NOT EXISTS #{@table}(
          id TEXT PRIMARY KEY,
          foo TEXT,
          bar INTEGER,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
        """
      )

    on_exit(fn -> Sqlitex.Server.query(DB, "DROP TABLE #{@table}") end)

    {:ok, []}
  end

  setup do
    {:ok, _} = Sqlitex.Server.query(DB, "DELETE FROM #{@table}")
  end

  test "get!/0" do
    assert TestModel.get!() === []

    TestModel.test_put!("i", Jason.encode!(%{a: "b"}), 1)
    assert [%TestModel{id: "i", foo: %{"a" => "b"}, bar: 1}] = TestModel.get!()

    TestModel.test_put!("i2", Jason.encode!(%{a2: "b2"}), 12)

    assert [
             %TestModel{id: "i", foo: %{"a" => "b"}, bar: 1},
             %TestModel{id: "i2", foo: %{"a2" => "b2"}, bar: 12}
           ] = TestModel.get!()
  end

  test "get!/1" do
    assert is_nil(TestModel.get!("i"))

    TestModel.test_put!("i")
    assert %TestModel{id: "i", foo: nil, bar: nil} = TestModel.get!("i")

    TestModel.test_put!("i2")
    assert %TestModel{id: "i", foo: nil, bar: nil} = TestModel.get!("i")
  end

  test "put!/1" do
    assert %TestModel{id: "i", foo: nil, bar: nil} = TestModel.put!(id: "i")
    assert %{id: "i", foo: nil, bar: nil} = TestModel.test_get!("i")

    assert %TestModel{id: "i2", foo: %{"a" => 1}, bar: 2} =
             TestModel.put!(id: "i2", foo: %{a: 1}, bar: 2)

    assert %{id: "i2", foo: "{\"a\":1}", bar: 2} = TestModel.test_get!("i2")

    assert_raise RuntimeError, fn -> TestModel.put!(id: "i") end
  end

  test "update!/2" do
    TestModel.test_put!("i")

    m = TestModel.get!("i")
    assert %TestModel{id: "i", foo: %{"a" => 1}, bar: nil} = TestModel.update!(m, foo: %{a: 1})

    m = TestModel.get!("i")
    assert %TestModel{id: "i", foo: %{"a" => 1}, bar: 1} = TestModel.update!(m, bar: 1)

    assert is_nil(TestModel.update!(%TestModel{id: "i2"}, bar: 1))
  end

  test "query!/2" do
    TestModel.test_put!("i")
    TestModel.test_put!("i2", nil, 1)
    TestModel.test_put!("i3", nil, 2)

    assert [%{id: "i2", bar: 1}, %{id: "i3", bar: 2}] ===
             TestModel.query!("SELECT id, bar FROM #{@table} WHERE bar NOT NULL")

    assert [%{bar: 2}] === TestModel.query!("SELECT bar FROM #{@table} WHERE bar > ?1", x: 1)
  end
end
