defmodule OAAS.Queue do
  @moduledoc "Manages the job queue."

  use GenServer

  alias OAAS.Worker
  alias OAAS.Job
  alias OAAS.DB
  import OAAS.Utils
  require DB

  @interval 10 * 1000

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{})
  end

  @impl true
  def init(state) do
    schedule(@interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:work, state) do
    try do
      clear_stalled()
      process_pending()
      reschedule_failed()
    after
      schedule(@interval)
    end

    {:noreply, state}
  end

  # Schedule work to be done after the interval elapses.
  defp schedule(ms) do
    Process.send_after(self(), :work, ms)
  end

  # Unassign stalled jobs from workers.
  defp clear_stalled do
    case Job.get_stalled() do
      {:ok, js} ->
        Enum.each(js, fn j ->
          status = j.status

          case Job.fail(j, "stalled at status #{Job.status(j.status)}") do
            {:ok, j} ->
              notify("job `#{j.id}` failed (stalled at `#{Job.status(status)}`)")

            {:error, reason} ->
              notify(:warn, "failing job `#{j.id}` failed", reason)
          end
        end)

      {:error, reason} ->
        notify(:warn, "getting stalled jobs failed", reason)
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
                  notify("assigned job `#{j.id}` to worker `#{w.id}`")

                {:error, reason} ->
                  notify(:error, "assigning job `#{j.id}` to worker `#{w.id}` failed", reason)
              end

            {:error, reason} ->
              notify(:warn, "getting a worker to assign to job `#{j.id}` failed", reason)
          end
        end)

      {:error, reason} ->
        notify(:error, "getting pending jobs failed", reason)
    end
  end

  # Reschedule failed jobs.
  defp reschedule_failed do
    case Job.get_by_status(:failed) do
      {:ok, js} ->
        Enum.each(js, fn j ->
          case Job.reschedule(j) do
            {:ok, j} -> notify("rescheduled job `#{j.id}`")
            {:error, reason} -> notify(:error, "rescheduling job `#{j.id}` failed", reason)
          end
        end)

      {:error, reason} ->
        notify(:error, "getting failed jobs failed", reason)
    end
  end
end
