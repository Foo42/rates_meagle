defmodule RatesMeagle.ServiceInstanceMonitor do
  use GenServer
  require Logger
  alias RatesMeagle.StatusStore

  def start_link(args \\ []) do
    Logger.info "in RatesMeagle.ServiceInstanceMonitor #{inspect args}"
    GenServer.start_link(__MODULE__,%{supervisor: self(), target: "http://rates-query-int.laterooms.com/status"})
  end

  defp schedule_status_check(seconds) do
    :erlang.send_after(seconds * 1000, self(), :check_status_timeout_elapsed)
  end

  #Server Implementation
  def init(args) do
    Logger.info "starting status checker #{inspect self()}"
    GenServer.cast self(), {:begin_checking} 
    {:ok, args}
  end

  def handle_cast({:begin_checking}, state) do
    schedule_status_check 1
    {:noreply, state}
  end

  def handle_info(:check_status_timeout_elapsed, state) do
    Logger.info "in handle info, checking status..."
    result = try_check_status(state)
    StatusStore.store_status :service_instance, state[:target], result
    Logger.info "result is #{inspect result}"
    schedule_status_check 10
    {:noreply, state |> Dict.put(:last_status, result)}
  end

  def handle_info(message, state) do
    Logger.info "recieved other info message: #{inspect message}"
  end

  defp try_check_status(state) do
    try do
      %{status_code: status_code} = HTTPotion.get state[:target]
      status_code
    rescue
      e in HTTPotion.HTTPError -> :http_error
    end
  end
end
