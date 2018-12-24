defmodule WorkerTest do
  use ExUnit.Case

  import OAAS.Worker
  alias OAAS.DB
  alias OAAS.Worker
  alias OAAS.Job

  setup do
    {:ok, _} = DB.query("DELETE FROM workers")
    {:ok, []}
  end

  # We're going to use functions from Model freely here because they're tested elsewhere.

  test "get_available/0" do
    now = System.system_time(:millisecond)

    assert {:ok, _} = put(id: "a", last_poll: now)
    assert {:ok, _} = put(id: "b", last_poll: now - 15_000)
    assert {:ok, _} = put(id: "c", last_poll: now - 29_900)
    assert {:ok, _} = put(id: "d", last_poll: now - 35_000)
    assert {:ok, _} = put(id: "e", last_poll: now - 29_900, current_job_id: 1)

    assert {:ok, [%Worker{id: "a"}, %Worker{id: "b"}, %Worker{id: "c"}]} = get_available()

    Process.sleep(300)

    assert {:ok, [%Worker{id: "a"}, %Worker{id: "b"}]} = get_available()
  end

  test "get_assigned/1" do
    assert {:ok, w} = put(id: "i")

    assert {:ok, j} =
             Job.put(
               player: %{},
               beatmap: %{},
               replay: "",
               youtube: %{},
               status: Job.status(:pending)
             )

    assert {:ok, nil} = get_assigned(w)

    assert {:ok, w} = update(w, current_job_id: j.id)
    assert {:ok, j} = Job.update(j, worker_id: w.id)

    assert {:ok, nil} = get_assigned(w)

    assert {:ok, j} = Job.update(j, status: Job.status(:assigned))

    assert {:ok, ^j} = get_assigned(w)
  end

  @tag :capture_log
  test "get_or_put/1" do
    assert {:ok, w} = get_or_put("i")

    Process.sleep(5)

    assert {:ok, ^w} = get_or_put("i")
  end

  test "get_lru/0" do
    now = System.system_time(:millisecond)

    assert {:ok, _} = put(id: "a", last_poll: now, last_job: now - 15_000)
    assert {:ok, _} = put(id: "b", last_job: now - 35_000)
    assert {:ok, _} = put(id: "c", last_poll: now, last_job: now - 29_900)
    assert {:ok, _} = put(id: "d", last_job: now)

    assert {:ok, %Worker{id: "c"}} = get_lru()
  end
end
