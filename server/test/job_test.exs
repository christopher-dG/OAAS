defmodule JobTest do
  use ExUnit.Case

  alias ReplayFarm.Job

  setup_all do
    Application.ensure_all_started(:httpoison)
    {:ok, []}
  end

  setup do
    {:ok, _} = Sqlitex.Server.query(ReplayFarm.DB, "DELETE FROM jobs")
    {:ok, []}
  end

  defp put!(s \\ :pending, u \\ System.system_time(:millisecond)) do
    Job.put!(player: %{}, beatmap: %{}, mode: 0, replay: "", status: Job.status(s), updated_at: u)
  end

  test "put!/1 (autoincrementing ID)" do
    %Job{id: id} = put!()
    next_id = id + 1
    put!()

    assert [%{id: ^id}, %{id: ^next_id}] = Job.get!()
  end

  test "finished/1" do
    assert not Job.finished(0)
    assert not Job.finished(1)
    assert not Job.finished(2)
    assert not Job.finished(3)
    assert Job.finished(4)
    assert Job.finished(5)
  end

  @tag :capture_log
  @tag :net
  test "skin/1" do
    assert is_nil(Job.skin(%{username: ""}))
    assert is_nil(Job.skin(%{username: "i"}))

    assert %{name: _n, url: "https://" <> _u} = Job.skin(%{username: "cookiezi"})
  end

  test "get_stalled!/0" do
    now = System.system_time(:millisecond)

    put!(:pending, 0)
    put!(:assigned, now - 60 * 1000)
    put!(:recording, now - 9 * 60 * 1000)
    put!(:uploading, now - 5 - 10 * 60 * 1000)
    put!(:successful, 0)
    put!(:failed, 0)

    s = Job.status(:uploading)

    assert [%Job{status: ^s}] = Job.get_stalled!()
  end

  test "get_pending!/0" do
    put!(:pending, 1)
    put!(:pending, 1)
    put!(:assigned)
    put!(:recording)
    put!(:uploading)

    s = Job.status(:pending)

    assert [%Job{status: ^s, updated_at: 1}, %Job{status: ^s, updated_at: 1}] = Job.get_pending!()
  end
end
