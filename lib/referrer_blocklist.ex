defmodule ReferrerBlocklist do
  use GenServer

  @resource_url "https://raw.githubusercontent.com/matomo-org/referrer-spam-list/master/spammers.txt"
  # one week
  @update_interval_milliseconds 7 * 24 * 60 * 60 * 1000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    timer = Process.send_after(self(), :update_list, @update_interval_milliseconds)
    filepath = Keyword.get(opts, :filepath, default_filepath())
    resource_url = Keyword.get(opts, :resource_url, @resource_url)
    blocklist = get_blocklist(filepath, resource_url, init: true)

    {:ok, %{timer: timer, filepath: filepath, blocklist: MapSet.new(blocklist)}}
  end

  def is_spammer?(domain, pid \\ __MODULE__) do
    GenServer.call(pid, {:is_spammer, domain})
  end

  def handle_call({:is_spammer, domain}, _from, state) do
    is_spammer = MapSet.member?(state.blocklist, domain)
    {:reply, is_spammer, state}
  end

  def handle_info(:update_list, state) do
    updated_blocklist = get_blocklist(state.filepath, @resource_url)

    Process.cancel_timer(state[:timer])
    new_timer = Process.send_after(self(), :update_list, @update_interval_milliseconds)

    {:noreply, %{state | blocklist: updated_blocklist, timer: new_timer}}
  end

  defp get_blocklist(filepath, resource_url, opts \\ []) do
    case HTTPoison.get(resource_url) do
      {:ok, response} when response.status_code == 200 ->
        if opts[:init], do: File.write!(filepath, response.body)
        String.split(response.body, "\n")

      {:error, _reason} ->
        File.read!(filepath) |> String.split("\n")
    end
  end

  defp default_filepath() do
    Application.app_dir(:referrer_blocklist, "/priv/spammers.txt")
  end
end
