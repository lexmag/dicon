defmodule Dicon.Executor do
  @moduledoc """
  Behaviour for executors.

  This behaviour specifies the callbacks that executors must implement. Look at
  the documentation for the `Dicon` module for more information about executors.
  """

  alias Dicon.SecureShell

  @type conn :: identifier | struct

  @type t :: %__MODULE__{executor: module, conn: conn}

  defstruct [:executor, :conn]

  @doc """
  Connects to the given authority, returning a term that identifies the
  connection.
  """
  @callback connect(authority :: binary) :: {:ok, conn} | {:error, binary}

  @doc """
  Executes the given `command` on the given connection, writing the output of
  `command` to `device`.
  """
  @callback exec(conn, command :: charlist, device :: atom | pid) :: :ok | {:error, binary}

  @callback write_file(conn, target :: charlist, content :: iodata, :write | :append) :: :ok | {:error, binary}

  @doc """
  Copies the local file `source` over to the destination `target` on the given
  connection.
  """
  @callback copy(conn, source :: charlist, target :: charlist) :: :ok | {:error, binary}

  @doc """
  Tails the given list of `patterns` continuously (`tail -f`), returning only in
  case of errors.

  `line_transformer` is called on each line output by `tail` before writing it to `device`.
  """
  @callback tail(conn,
                 patterns :: [binary, ...],
                 line_transformer :: (binary -> IO.ANSI.ansidata),
                 device :: atom | pid) ::
    :ok | {:error, binary}

  @doc """
  Connects to authority.

  The connection happens through the executor configured in the configuration
  for the `:dicon` application; see the documentation for the `Dicon` module for
  more information.

  ## Examples

      %Dicon.Executor{} = Dicon.Executor.connect("meg:secret@example.com")

  """
  @spec connect(binary) :: {:ok, t} | {:error, term}
  def connect(authority) do
    executor = Application.get_env(:dicon, :executor, SecureShell)
    case executor.connect(authority) do
      {:ok, conn} ->
        Mix.shell.info "Connected to #{authority}"
        %__MODULE__{executor: executor, conn: conn}
      {:error, reason} ->
        raise_error(executor, reason)
    end
  end

  @doc """
  Executes the given `command` on the connection in `state`.

  ## Examples

      state = Dicon.Executor.connect("meg:secret@example.com")
      Dicon.Executor.exec(state, "ls -la")
      #=> :ok

  """
  def exec(%__MODULE__{} = state, command, device \\ Process.group_leader()) do
    Mix.shell.info "==> EXEC #{command}"
    run(state, :exec, [command, device])
  end

  @doc """
  Copies the `source` file on the local machine to the `target` on the remote
  machine on the connection in `state`.

  ## Examples

      state = Dicon.Executor.connect("meg:secret@example.com")
      Dicon.Executor.copy(state, "hello.txt", "uploaded-hello.txt")
      #=> :ok

  """
  def copy(%__MODULE__{} = state, source, target) do
    Mix.shell.info "==> COPY #{source} #{target}"
    run(state, :copy, [source, target])
  end

  def write_file(%__MODULE__{} = state, target, content, mode \\ :write)
      when mode in [:write, :append] and (is_binary(content) or is_list(content)) do
    Mix.shell.info "==> WRITE #{target}"
    run(state, :write_file, [target, content, mode])
  end

  def tail(%__MODULE__{} = state, patterns, line_transformer, device \\ Process.group_leader()) do
    run(state, :tail, [patterns, line_transformer, device])
  end

  defp run(%{executor: executor, conn: conn}, fun, args) do
    case apply(executor, fun, [conn | args]) do
      {:error, reason} -> raise_error(executor, reason)
      :ok              -> :ok
    end
  end

  defp raise_error(executor, reason) when is_binary(reason) do
    Mix.raise "(in #{inspect executor}) " <> reason
  end
end
