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

  def test_get(id) do
    case DB.query("SELECT * FROM #{@table} WHERE id = ?1", bind: [id], into: %{}) do
      {:ok, []} -> {:ok, nil}
      {:ok, [r]} -> {:ok, r}
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

  alias ReplayFarm.DB
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
    {:ok, []} = get()

    {:ok, _} = test_put("i", Jason.encode!(%{a: "b"}), 1)
    {:ok, [%TestModel{id: "i", foo: %{"a" => "b"}, bar: 1}]} = get()

    {:ok, _} = test_put("i2", Jason.encode!(%{a2: "b2"}), 12)

    {:ok,
     [
       %TestModel{id: "i", foo: %{"a" => "b"}, bar: 1},
       %TestModel{id: "i2", foo: %{"a2" => "b2"}, bar: 12}
     ]} = get()
  end

  test "get/1" do
    {:ok, nil} = get("i")

    {:ok, _} = test_put("i")
    {:ok, %TestModel{id: "i", foo: nil, bar: nil}} = get("i")

    {:ok, _} = test_put("i2")
    {:ok, %TestModel{id: "i", foo: nil, bar: nil}} = get("i")
  end

  test "put/1" do
    {:ok, %TestModel{id: "i", foo: nil, bar: nil}} = put(id: "i")
    {:ok, %{id: "i", foo: nil, bar: nil}} = test_get("i")

    {:ok, %TestModel{id: "i2", foo: %{"a" => 1}, bar: 2}} = put(id: "i2", foo: %{a: 1}, bar: 2)

    {:ok, %{id: "i2", foo: "{\"a\":1}", bar: 2}} = test_get("i2")

    {:error, _} = put(id: "i")
  end

  test "update/2" do
    {:ok, _} = test_put("i")

    {:ok, m} = get("i")
    {:ok, %TestModel{id: "i", foo: %{"a" => 1}, bar: nil}} = update(m, foo: %{a: 1})

    {:ok, m} = get("i")
    {:ok, %TestModel{id: "i", foo: %{"a" => 1}, bar: 1}} = update(m, bar: 1)

    {:ok, nil} = update(%TestModel{id: "i2"}, bar: 1)
  end
end
