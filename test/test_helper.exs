ExUnit.start(refute_receive_timeout: 200)

Mix.shell(Mix.Shell.Process)

defmodule PathHelpers do
  def fixtures_path() do
    Path.expand("fixtures", __DIR__)
  end

  def fixture_path(extra) do
    Path.join(fixtures_path(), extra)
  end
end

defmodule DiconTest.Case do
  use ExUnit.CaseTemplate

  @behaviour Dicon.Executor

  using _ do
    quote do
      import unquote(__MODULE__), only: [flush_reply: 1]
    end
  end

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
    conn = make_ref()
    notify_test({:dicon, conn, :connect, [authority]})
    {:ok, conn}
  end

  def exec(conn, command, _device) do
    command = List.to_string(command)
    notify_test({:dicon, conn, :exec, [command]})
    :ok
  end

  def write_file(conn, target, content, mode) do
    content = IO.iodata_to_binary(content)
    target = List.to_string(target)
    notify_test({:dicon, conn, :write_file, [target, content, mode]})
    :ok
  end

  def copy(conn, source, target) do
    source = List.to_string(source)
    target = List.to_string(target)
    notify_test({:dicon, conn, :copy, [source, target]})
    :ok
  end

  defp notify_test(message) do
    test_pid = Application.fetch_env!(:dicon, __MODULE__)
    send(test_pid, message)
  end

  def flush_reply(conn) do
    receive do
      {:dicon, ^conn, _, _} ->
        flush_reply(conn)
    after
      50 -> :ok
    end
  end
end
