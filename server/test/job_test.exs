defmodule JobTest do
  use ExUnit.Case

  alias OAAS.Job
  import OAAS.Job

  setup_all do
    Application.ensure_all_started(:httpoison)
    {:ok, []}
  end

  setup do
    {:ok, _} = Sqlitex.Server.query(OAAS.DB, "DELETE FROM jobs")
    {:ok, []}
  end

  defp quickput(s \\ :pending, u \\ System.system_time(:millisecond)) do
    {:ok, _} =
      put(
        player: %{},
        beatmap: %{},
        replay: %{},
        youtube: %{},
        status: status(s),
        updated_at: u
      )
  end

  test "put/1 (autoincrementing ID)" do
    assert {:ok, %Job{id: id}} = quickput()
    next_id = id + 1
    assert {:ok, _} = quickput()

    assert {:ok, [%{id: ^id}, %{id: ^next_id}]} = get()
  end

  test "get_stalled/0" do
    now = System.system_time(:millisecond)

    assert {:ok, _} = quickput(:pending, 0)
    assert {:ok, _} = quickput(:assigned, now - 60 * 1000)
    assert {:ok, _} = quickput(:recording, now - 9 * 60 * 1000)
    assert {:ok, _} = quickput(:uploading, now - 5 - 10 * 60 * 1000)
    assert {:ok, _} = quickput(:successful, 0)
    assert {:ok, _} = quickput(:failed, 0)

    s = status(:uploading)

    assert {:ok, [%Job{status: ^s}]} = get_stalled()
  end

  test "get_by_status/1" do
    assert {:ok, _} = quickput(:pending, 1)
    assert {:ok, _} = quickput(:pending, 1)
    assert {:ok, _} = quickput(:assigned, 1)
    assert {:ok, _} = quickput(:recording)
    assert {:ok, _} = quickput(:uploading)

    p = status(:pending)
    a = status(:assigned)

    assert {:ok, [%Job{status: ^p, updated_at: 1}, %Job{status: ^p, updated_at: 1}]} =
             get_by_status(:pending)

    assert {:ok, [%Job{status: ^a, updated_at: 1}]} = get_by_status(:assigned)
  end
end
