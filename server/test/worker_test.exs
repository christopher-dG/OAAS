defmodule WorkerTest do
  use ExUnit.Case

  alias ReplayFarm.Worker
  alias ReplayFarm.Job

  setup do
    {:ok, _} = Sqlitex.Server.query(ReplayFarm.DB, "DELETE FROM workers")
    {:ok, []}
  end

  # We're going to use functions from Model freely here because they're tested elsewhere.

  test "get_online!/0" do
    now = System.system_time(:millisecond)

    Worker.put!(id: "a", last_poll: now)
    Worker.put!(id: "b", last_poll: now - 15_000)
    Worker.put!(id: "c", last_poll: now - 29_900)
    Worker.put!(id: "d", last_poll: now - 35_000)

    assert [%Worker{id: "a"}, %Worker{id: "b"}, %Worker{id: "c"}] = Worker.get_online!()

    :timer.sleep(150)

    assert [%Worker{id: "a"}, %Worker{id: "b"}] = Worker.get_online!()
  end

  test "get_assigned!/1" do
    w = Worker.put!(id: "i")
    j = Job.put!(player: %{}, beatmap: %{}, mode: 0, replay: "", status: Job.status(:pending))

    assert is_nil(Worker.get_assigned!(w))

    w = Worker.update!(w, current_job_id: j.id)
    j = Job.update!(j, worker_id: w.id)

    assert is_nil(Worker.get_assigned!(w))

    j = Job.update!(j, status: Job.status(:assigned))

    assert j === Worker.get_assigned!(w)
  end

  @tag :capture_log
  test "get_or_put!/1" do
    w = Worker.get_or_put!("i")

    :timer.sleep(5)

    assert w === Worker.get_or_put!("i")
  end

  test "get_lru!/0" do
    now = System.system_time(:millisecond)

    Worker.put!(id: "a", last_poll: now, last_job: now - 15_000)
    Worker.put!(id: "b", last_job: now - 35_000)
    Worker.put!(id: "c", last_poll: now, last_job: now - 29_900)
    Worker.put!(id: "d", last_job: now)

    assert %Worker{id: "c"} = Worker.get_lru!()
  end
end
