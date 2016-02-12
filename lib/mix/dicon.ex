defmodule Mix.Dicon do
  @moduledoc false

  @doc """
  Converts a command-line switch to its string representation.
  """
  def switch_to_string({name, nil}), do: name
  def switch_to_string({name, val}), do: name <> "=" <> val
end
