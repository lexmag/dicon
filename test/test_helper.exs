ExUnit.start

defmodule PathHelpers do
  def fixtures_path() do
    Path.expand("fixtures", __DIR__)
  end

  def fixture_path(extra) do
    Path.join(fixtures_path, extra)
  end
end

defmodule DiconTest.Case do
  use ExUnit.CaseTemplate

  @behaviour Dicon.Executor

  setup_all do
    Application.put_env(:dicon, :executor, __MODULE__)
    on_exit(fn ->
      Application.delete_env(:dicon, :executor)
    end)
  end

  setup do
    Application.put_env(:dicon, __MODULE__, self())
    on_exit(fn ->
      Application.delete_env(:dicon, __MODULE__)
    end)
  end

  def connect(authority) do
    ref = make_ref()
    notify_test({:dicon, ref, :connect, [authority]})
    {:ok, ref}
  end

  def exec(ref, command) do
    command = List.to_string(command)
    notify_test({:dicon, ref, :exec, [command]})
    :ok
  end

  def copy(ref, source, target) do
    source = List.to_string(source)
    target = List.to_string(target)
    notify_test({:dicon, ref, :copy, [source, target]})
    :ok
  end

  defp notify_test(message) do
    test_pid = Application.fetch_env!(:dicon, __MODULE__)
    send(test_pid, message)
  end
end
