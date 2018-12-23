defmodule JobTest do
  use ExUnit.Case

  alias ReplayFarm.Job
  import ReplayFarm.Job

  setup_all do
    Application.ensure_all_started(:httpoison)
    {:ok, []}
  end

  setup do
    {:ok, _} = Sqlitex.Server.query(ReplayFarm.DB, "DELETE FROM jobs")
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
    {:ok, %Job{id: id}} = quickput()
    next_id = id + 1
    {:ok, _} = quickput()

    {:ok, [%{id: ^id}, %{id: ^next_id}]} = get()
  end

  test "finished/1" do
    assert not finished(0)
    assert not finished(1)
    assert not finished(2)
    assert not finished(3)
    assert finished(4)
    assert finished(5)
  end

  @tag :capture_log
  @tag :net
  test "skin/1" do
    nil = skin("")
    nil = skin("i")

    %{name: _n, url: "https://" <> _u} = skin("cookiezi")
  end

  test "get_stalled/0" do
    now = System.system_time(:millisecond)

    {:ok, _} = quickput(:pending, 0)
    {:ok, _} = quickput(:assigned, now - 60 * 1000)
    {:ok, _} = quickput(:recording, now - 9 * 60 * 1000)
    {:ok, _} = quickput(:uploading, now - 5 - 10 * 60 * 1000)
    {:ok, _} = quickput(:successful, 0)
    {:ok, _} = quickput(:failed, 0)

    s = status(:uploading)

    {:ok, [%Job{status: ^s}]} = get_stalled()
  end

  test "get_by_status/1" do
    {:ok, _} = quickput(:pending, 1)
    {:ok, _} = quickput(:pending, 1)
    {:ok, _} = quickput(:assigned, 1)
    {:ok, _} = quickput(:recording)
    {:ok, _} = quickput(:uploading)

    p = status(:pending)
    a = status(:assigned)

    {:ok, [%Job{status: ^p, updated_at: 1}, %Job{status: ^p, updated_at: 1}]} =
      get_by_status(:pending)

    {:ok, [%Job{status: ^a, updated_at: 1}]} = get_by_status(:assigned)
  end
end
