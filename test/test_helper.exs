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
      import unquote(__MODULE__), only: [flush_reply: 1, on_exec: 2, put_dicon_env: 1]
    end
  end

  setup_all do
    Application.put_env(:dicon, :executor, __MODULE__)

    on_exit(fn ->
      Application.delete_env(:dicon, :executor)
    end)
  end

  setup do
    Application.put_env(:dicon, __MODULE__, test_pid: self())

    on_exit(fn ->
      Application.delete_env(:dicon, __MODULE__)
    end)
  end

  def connect(authority) do
    conn = make_ref()
    notify_test({:dicon, conn, :connect, [authority]})
    {:ok, conn}
  end

  def exec(conn, command, device) do
    command = List.to_string(command)
    run_callback(command, device)
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
    :dicon
    |> Application.fetch_env!(__MODULE__)
    |> Keyword.fetch!(:test_pid)
    |> send(message)
  end

  def on_exec(command, callback) do
    env =
      :dicon
      |> Application.fetch_env!(__MODULE__)
      |> Keyword.update(:exec_callbacks, %{command => callback}, &Map.put(&1, command, callback))

    Application.put_env(:dicon, __MODULE__, env)
  end

  def flush_reply(conn) do
    receive do
      {:dicon, ^conn, _, _} ->
        flush_reply(conn)
    after
      50 -> :ok
    end
  end

  def put_dicon_env(config) do
    # TODO: Use Application.put_all_env/2 when we
    # dropped support for Elixir versions older than 1.9.
    for {key, value} <- config, do: Application.put_env(:dicon, key, value)
  end

  defp run_callback(command, device) do
    env = Application.fetch_env!(:dicon, __MODULE__)
    {callback, env} = pop_in(env, [:exec_callbacks, command])

    if callback do
      callback.(device)
      Application.put_env(:dicon, __MODULE__, env)
    end

    :ok
  end
end
