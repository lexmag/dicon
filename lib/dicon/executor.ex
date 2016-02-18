defmodule Dicon.Executor do
  @moduledoc """
  Behaviour for executors.

  This behaviour specifies the callbacks that executors must implement. Look at
  the documentation for the `Dicon` module for more information about executors.
  """

  alias Dicon.SecureShell

  @doc """
  Connects to the given authority, returning a term that identifies the
  connection.
  """
  @callback connect(authority :: binary) :: {:ok, identifier} | {:error, binary}

  @doc """
  Executes the given `command` on the given connection.
  """
  @callback exec(identifier, command :: char_list) :: :ok | {:error, binary}

  @doc """
  Copies the local file `source` over to the destination `target` on the given
  connection.
  """
  @callback copy(identifier, source :: char_list, target :: char_list) :: :ok | {:error, binary}

  @type t :: %__MODULE__{executor: module, id: identifier}

  defstruct [:executor, :id]

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
      {:ok, id}        -> %__MODULE__{executor: executor, id: id}
      {:error, reason} -> raise_error(executor, reason)
    end
  end

  @doc """
  Executes the given `command` on the connection in `state`.

  ## Examples

      state = Dicon.Executor.connect("meg:secret@example.com")
      Dicon.Executor.exec(state, "ls -la")
      #=> :ok

  """
  def exec(%__MODULE__{} = state, command) do
    run(state, :exec, [command])
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
    run(state, :copy, [source, target])
  end

  defp run(%{executor: executor, id: id}, fun, args) do
    case apply(executor, fun, [id | args]) do
      {:error, reason} -> raise_error(executor, reason)
      :ok              -> :ok
    end
  end

  defp raise_error(executor_mod, reason) when is_binary(reason) do
    Mix.raise "(in #{inspect executor_mod}) " <> reason
  end
end
