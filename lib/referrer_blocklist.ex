defmodule ReferrerBlocklist do
  use GenServer

  @resource_url "https://raw.githubusercontent.com/matomo-org/referrer-spam-list/master/spammers.txt"
  # one week
  @update_interval_milliseconds 7 * 24 * 60 * 60 * 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    filepath = Keyword.get(opts, :filepath, blocklist_filepath())
    resource_url = Keyword.get(opts, :resource_url, @resource_url)

    timer = Process.send_after(self(), {:update_list, resource_url}, 10)

    {:ok, %{timer: timer, blocklist: read_blocklist_from_file(filepath)}}
  end

  def is_spammer?(domain, pid \\ __MODULE__) do
    GenServer.call(pid, {:is_spammer, domain})
  end

  def handle_call({:is_spammer, domain}, _from, state) do
    is_spammer = MapSet.member?(state.blocklist, domain)
    {:reply, is_spammer, state}
  end

  def handle_info({:update_list, resource_url}, state) do
    updated_blocklist = attempt_blocklist_update(resource_url, state.blocklist)

    Process.cancel_timer(state[:timer])
    new_timer = Process.send_after(self(), :update_list, @update_interval_milliseconds)

    {:noreply, %{state | blocklist: updated_blocklist, timer: new_timer}}
  end

  defp read_blocklist_from_file(filepath) do
    File.read!(filepath)
    |> String.split("\n")
    |> MapSet.new()
  end

  defp attempt_blocklist_update(resource_url, current_blocklist) do
    case HTTPoison.get(resource_url) do
      {:ok, response} when response.status_code == 200 ->
        String.split(response.body, "\n")
        |> MapSet.new()

      {:error, _} ->
        current_blocklist
    end
  end

  defp blocklist_filepath() do
    Application.app_dir(:referrer_blocklist, "/priv/spammers.txt")
  end
end
