defmodule WorkerTest do
  use ExUnit.Case

  import ReplayFarm.Worker
  alias ReplayFarm.DB
  alias ReplayFarm.Worker
  alias ReplayFarm.Job

  setup do
    {:ok, _} = DB.query("DELETE FROM workers")
    {:ok, []}
  end

  # We're going to use functions from Model freely here because they're tested elsewhere.

  test "get_available/0" do
    now = System.system_time(:millisecond)

    {:ok, _} = put(id: "a", last_poll: now)
    {:ok, _} = put(id: "b", last_poll: now - 15_000)
    {:ok, _} = put(id: "c", last_poll: now - 29_900)
    {:ok, _} = put(id: "d", last_poll: now - 35_000)
    {:ok, _} = put(id: "e", last_poll: now - 29_900, current_job_id: 1)

    {:ok, [%Worker{id: "a"}, %Worker{id: "b"}, %Worker{id: "c"}]} = get_available()

    Process.sleep(300)

    {:ok, [%Worker{id: "a"}, %Worker{id: "b"}]} = get_available()
  end

  test "get_assigned/1" do
    {:ok, w} = put(id: "i")

    {:ok, j} =
      Job.put(player: %{}, beatmap: %{}, replay: "", youtube: %{}, status: Job.status(:pending))

    {:ok, nil} = get_assigned(w)

    {:ok, w} = update(w, current_job_id: j.id)
    {:ok, j} = Job.update(j, worker_id: w.id)

    {:ok, nil} = get_assigned(w)

    {:ok, j} = Job.update(j, status: Job.status(:assigned))

    {:ok, ^j} = get_assigned(w)
  end

  @tag :capture_log
  test "get_or_put/1" do
    {:ok, w} = get_or_put("i")

    Process.sleep(5)

    {:ok, ^w} = get_or_put("i")
  end

  test "get_lru/0" do
    now = System.system_time(:millisecond)

    {:ok, _} = put(id: "a", last_poll: now, last_job: now - 15_000)
    {:ok, _} = put(id: "b", last_job: now - 35_000)
    {:ok, _} = put(id: "c", last_poll: now, last_job: now - 29_900)
    {:ok, _} = put(id: "d", last_job: now)

    {:ok, %Worker{id: "c"}} = get_lru()
  end
end
