defmodule ReplayFarm.Queue do
  @moduledoc "Manages the job queue."

  use GenServer
  require Logger

  alias ReplayFarm.Worker
  alias ReplayFarm.Job
  alias ReplayFarm.DB
  require DB

  @interval 10 * 1000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule(@interval)
    {:ok, state}
  end

  def handle_info(:work, state) do
    # Logger.info("Processing job queue")

    try do
      clear_stalled()
      process_pending()
    after
      schedule(@interval)
    end

    {:noreply, state}
  end

  # Schedule work to be done after the interval elapses.
  defp schedule(interval) when is_integer(interval) and interval > 0 do
    Process.send_after(self(), :work, interval)
  end

  # Unassign stalled jobs from workers.
  defp clear_stalled do
    Job.get_stalled!()
    |> Enum.each(fn j ->
      w = Worker.get!(j.worker_id)

      DB.transaction! do
        Worker.update!(w, current_job_id: nil)

        Job.update!(
          j,
          worker_id: nil,
          status: Job.status(:failed),
          comment: "stalled with status #{Job.status(j.status)}"
        )
      end

      Logger.info(
        "unassigned job `#{j.id}` from worker `#{w.id}` (stalled at `#{Job.status(j.status)}`)"
      )
    end)
  end

  # Assign pending jobs to available workers.
  defp process_pending do
    Job.get_pending!()
    |> Enum.sort_by(fn j -> j.created_at end)
    |> Enum.each(fn j ->
      case Worker.get_lru!() do
        nil ->
          :noop

        w ->
          DB.transaction! do
            Worker.update!(w, current_job_id: j.id, last_job: System.system_time(:millisecond))
            Job.update!(j, worker_id: w.id, status: Job.status(:assigned))
          end

          Logger.info("Assigned job `#{j.id}` to worker `#{w.id}`.")
      end
    end)
  end
end
