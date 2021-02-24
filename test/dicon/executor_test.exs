defmodule Dicon.ExecutorTest do
  use ExUnit.Case

  alias Dicon.Executor

  defmodule FakeExecutor do
    @behaviour Executor

    def connect("fail"), do: {:error, "connect failed"}
    def connect(term), do: {:ok, term}

    def exec(_conn, _silent, 'fail', _device), do: {:error, "exec failed"}
    def exec(_conn, _silent, _command, _device), do: :ok

    def write_file(_conn, _silent, 'fail', "fail", _mode), do: {:error, "write failed"}
    def write_file(_conn, _silent, _target, _content, _mode), do: :ok

    def copy(_conn, _silent, 'fail', 'fail'), do: {:error, "copy failed"}
    def copy(_conn, _silent, _source, _target), do: :ok
  end

  setup_all do
    Application.put_env(:dicon, :executor, FakeExecutor)
    on_exit(fn -> Application.delete_env(:dicon, :executor) end)
  end

  test "connect/1" do
    assert %Executor{} = Executor.connect("whatever")
    assert_receive {:mix_shell, :info, ["Connected to whatever"]}

    message = "(in Dicon.ExecutorTest.FakeExecutor) connect failed"
    assert_raise Mix.Error, message, fn -> Executor.connect("fail") end
  end

  test "exec/3" do
    conn = Executor.connect("whatever")

    assert Executor.exec(conn, false, "whatever") == :ok
    assert_receive {:mix_shell, :info, ["==> EXEC whatever"]}

    message = "(in Dicon.ExecutorTest.FakeExecutor) exec failed"
    assert_raise Mix.Error, message, fn -> Executor.exec(conn, false, 'fail') end
  end

  test "copy/3" do
    conn = Executor.connect("whatever")

    assert Executor.copy(conn, false, 'source', 'target') == :ok
    assert_receive {:mix_shell, :info, ["==> COPY source target"]}

    message = "(in Dicon.ExecutorTest.FakeExecutor) copy failed"
    assert_raise Mix.Error, message, fn -> Executor.copy(conn, false, 'fail', 'fail') end
  end

  test "write_file/5" do
    conn = Executor.connect("whatever")

    assert Executor.write_file(conn, false, 'target', "content") == :ok
    assert_receive {:mix_shell, :info, ["==> WRITE target"]}

    message = "(in Dicon.ExecutorTest.FakeExecutor) write failed"
    assert_raise Mix.Error, message, fn ->
      Executor.write_file(conn, false, 'fail', "fail")
    end
  end
end
