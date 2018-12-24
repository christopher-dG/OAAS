defmodule TestModel do
  alias OAAS.DB

  @table "model_test"

  @enforce_keys [:id]
  defstruct [:id, :foo, :bar]

  @type t :: %__MODULE__{
          id: binary,
          foo: map,
          bar: integer
        }

  @json_columns [:foo]

  use OAAS.Model

  def test_get(id) do
    case DB.query("SELECT * FROM #{@table} WHERE id = ?1", bind: [id], into: %{}) do
      {:ok, [r]} -> {:ok, r}
      {:ok, []} -> {:error, :no_such_entity}
      {:error, err} -> {:error, err}
    end
  end

  def test_put(id, foo \\ nil, bar \\ nil) do
    now = System.system_time(:millisecond)

    {:ok, _} =
      DB.query("INSERT INTO #{@table} VALUES (?1, ?2, ?3, ?4, ?5)", bind: [id, foo, bar, now, now])
  end
end

defmodule ModelTest do
  use ExUnit.Case

  alias OAAS.DB
  import TestModel

  @table "model_test"

  setup_all do
    {:ok, _} =
      DB.query("""
      CREATE TABLE IF NOT EXISTS #{@table}(
        id TEXT PRIMARY KEY,
        foo TEXT,
        bar INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
      """)

    on_exit(fn -> DB.query("DROP TABLE #{@table}") end)

    {:ok, []}
  end

  setup do
    {:ok, _} = DB.query("DELETE FROM #{@table}")
  end

  test "get/0" do
    assert {:ok, []} = get()

    assert {:ok, _} = test_put("i", Jason.encode!(%{a: "b"}), 1)
    assert {:ok, [%TestModel{id: "i", foo: %{a: "b"}, bar: 1}]} = get()

    assert {:ok, _} = test_put("i2", Jason.encode!(%{a2: "b2"}), 12)

    assert {:ok,
            [
              %TestModel{id: "i", foo: %{a: "b"}, bar: 1},
              %TestModel{id: "i2", foo: %{a2: "b2"}, bar: 12}
            ]} = get()
  end

  test "get/1" do
    assert {:error, :no_such_entity} = get("i")

    assert {:ok, _} = test_put("i")
    assert {:ok, %TestModel{id: "i", foo: nil, bar: nil}} = get("i")

    assert {:ok, _} = test_put("i2")
    assert {:ok, %TestModel{id: "i", foo: nil, bar: nil}} = get("i")
  end

  test "put/1" do
    assert {:ok, %TestModel{id: "i", foo: nil, bar: nil}} = put(id: "i")
    assert {:ok, %{id: "i", foo: nil, bar: nil}} = test_get("i")

    assert {:ok, %TestModel{id: "i2", foo: %{a: 1}, bar: 2}} = put(id: "i2", foo: %{a: 1}, bar: 2)

    assert {:ok, %{id: "i2", foo: "{\"a\":1}", bar: 2}} = test_get("i2")

    assert {:error, _} = put(id: "i")
  end

  test "update/2" do
    assert {:ok, _} = test_put("i")

    assert {:ok, m} = get("i")
    assert {:ok, %TestModel{id: "i", foo: %{a: 1}, bar: nil}} = update(m, foo: %{a: 1})

    assert {:ok, m} = TestModel.get("i")
    assert {:ok, %TestModel{id: "i", foo: %{a: 1}, bar: 1}} = update(m, bar: 1)

    assert {:error, :no_such_entity} = update(%TestModel{id: "i2"}, bar: 1)
  end
end
