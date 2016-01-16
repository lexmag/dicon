defmodule Dicon.Executor do
  alias Dicon.SecureShell

  @callback connect(authority :: binary) :: {:ok, ref :: term} | {:error, term}
  @callback exec(ref :: term, command :: char_list) :: :ok
  @callback copy(ref :: term, source :: char_list, target :: char_list) :: :ok

  defstruct [:module, :ref]

  def connect(authority) do
    module = Application.get_env(:dicon, :executor, SecureShell)
    {:ok, ref} = module.connect(authority)
    %__MODULE__{module: module, ref: ref}
  end

  def exec(%__MODULE__{} = state, command) do
    :ok = run(state, :exec, [command])
  end

  def copy(%__MODULE__{} = state, source, target) do
    :ok = run(state, :copy, [source, target])
  end

  defp run(%{module: module, ref: ref}, fun, args) do
    apply(module, fun, [ref | args])
  end
end
