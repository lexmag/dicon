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
  @callback connect(authority :: binary) :: {:ok, identifier} | {:error, term}

  @doc """
  Executes the given `command` on the given connection.
  """
  @callback exec(identifier, command :: char_list) :: :ok

  @doc """
  Copies the local file `source` over to the destination `target` on the given
  connection.
  """
  @callback copy(identifier, source :: char_list, target :: char_list) :: :ok

  defstruct [:module, :ref]

  @doc """
  Connects to authority.

  The connection happens through the executor configured in the configuration
  for the `:dicon` application; see the documentation for the `Dicon` module for
  more information.

  ## Examples

      %Dicon.Executor{} = Dicon.Executor.connect("meg:secret@example.com")

  """
  def connect(authority) do
    module = Application.get_env(:dicon, :executor, SecureShell)
    {:ok, ref} = module.connect(authority)
    %__MODULE__{module: module, ref: ref}
  end

  @doc """
  Executes the given `command` on the connection in `state`.

  ## Examples

      state = Dicon.Executor.connect("meg:secret@example.com")
      Dicon.Executor.exec(state, "ls -la")
      #=> :ok

  """
  def exec(%__MODULE__{} = state, command) do
    :ok = run(state, :exec, [command])
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
    :ok = run(state, :copy, [source, target])
  end

  defp run(%{module: module, ref: ref}, fun, args) do
    apply(module, fun, [ref | args])
  end
end
