defmodule Mix.Tasks.Dicon.Control do
  use Mix.Task

  @shortdoc "Execute a command on the remote release"

  @moduledoc """
  This task is used to execute commands on the remote release.

  It accepts one argument and forwards that command to the remote release.

  ## Usage

      mix dicon.control COMMAND

  ## Examples

      mix dicon.control ping

  """

  import Dicon, only: [config: 1, config: 2]

  alias Dicon.Executor

  @options [strict: [only: :keep, skip: :keep]]

  def run(argv) do
    case OptionParser.parse(argv, @options) do
      {opts, [command], []} ->
        for {_name, authority} <- config(:hosts, opts) do
          conn = Executor.connect(authority)
          exec(conn, config(:target_dir), command)
        end
      {_opts, _commands, [switch | _]} ->
        Mix.raise "Invalid option: " <> Mix.Dicon.switch_to_string(switch)
      {_opts, _commands, _errors} ->
        Mix.raise "Expected a single argument (the command to execute)"
    end
  end

  defp exec(conn, target_dir, command) do
    otp_app = config(:otp_app) |> Atom.to_string
    command = [target_dir, "/current/bin/", otp_app, ?\s, command]
    Executor.exec(conn, command)
  end
end
