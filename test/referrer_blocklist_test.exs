defmodule ReferrerBlocklistTest do
  use ExUnit.Case

  setup do
    filepath = System.tmp_dir!() |> Path.join("test-blocklist.txt")
    File.write!(filepath, "pre-existing.blocklist\n")

    on_exit(fn -> File.rm!(filepath) end)

    {:ok, %{filepath: filepath}}
  end

  test "updates list on init", %{filepath: filepath} do
    ReferrerBlocklist.start_link(filepath: filepath)

    assert !ReferrerBlocklist.is_spammer?("pre-existing.blocklist")
    assert ReferrerBlocklist.is_spammer?("0-0.fr")
  end

  test "overwrites default list file on init", %{filepath: filepath} do
    ReferrerBlocklist.start_link(filepath: filepath)

    assert String.length(File.read!(filepath)) > 1000
  end

  test "uses default list from file when request fails on init", %{filepath: filepath} do
    ReferrerBlocklist.start_link(
      filepath: filepath,
      resource_url: "https://no-list-here.com/request/will/fail.txt"
    )

    assert ReferrerBlocklist.is_spammer?("pre-existing.blocklist")
  end
end
