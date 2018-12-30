defmodule OAAS.Queue do
  @moduledoc "Manages the job queue."

  alias OAAS.Job
  alias OAAS.Worker
  import OAAS.Utils
  use GenServer

  @interval_ms 60_000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule(@interval_ms)
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    try do
      clear_stalled()
      process_pending()
      reschedule_failed()
    after
      schedule(@interval_ms)
    end

    {:noreply, state}
  end

  # Schedule work to be done after the interval elapses.
  defp schedule(ms) do
    Process.send_after(__MODULE__, :work, ms)
  end

  # Unassign stalled jobs from workers.
  defp clear_stalled do
    case Job.get_stalled() do
      {:ok, js} ->
        Enum.each(js, fn j ->
          status = j.status

          case Job.fail(j, "Stalled at status #{Job.status(j.status)}.") do
            {:ok, j} ->
              notify("Job `#{j.id}` failed (stalled at `#{Job.status(status)}`).")

            {:error, reason} ->
              notify(:error, "Failing job `#{j.id}` failed.", reason)
          end
        end)

      {:error, reason} ->
        notify(:error, "Getting stalled jobs failed.", reason)
    end
  end

  # Assign pending jobs to available workers.
  defp process_pending do
    case Job.get_by_status(:pending) do
      {:ok, js} ->
        js
        |> Enum.sort_by(&Map.get(&1, :created_at))
        |> Enum.each(fn j ->
          case Worker.get_lru() do
            {:ok, nil} ->
              :noop

            {:ok, w} ->
              case Job.assign(j, w) do
                {:ok, j} ->
                  notify("Assigned job `#{j.id}` to worker `#{w.id}`.")

                {:error, reason} ->
                  notify(:error, "Assigning job `#{j.id}` to worker `#{w.id}` failed.", reason)
              end

            {:error, reason} ->
              notify(:error, "Getting a worker to assign to job `#{j.id}` failed.", reason)
          end
        end)

      {:error, reason} ->
        notify(:error, "Getting pending jobs failed.", reason)
    end
  end

  # Reschedule failed jobs.
  defp reschedule_failed do
    case Job.get_by_status(:failed) do
      {:ok, js} ->
        Enum.each(js, fn j ->
          case Job.update(j, status: Job.status(:pending)) do
            {:ok, j} -> notify("Rescheduled job `#{j.id}`.")
            {:error, reason} -> notify(:error, "Rescheduling job `#{j.id}` failed.", reason)
          end
        end)

      {:error, reason} ->
        notify(:error, "Getting failed jobs failed.", reason)
    end
  end
end
