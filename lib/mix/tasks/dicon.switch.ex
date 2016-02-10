defmodule Mix.Tasks.Dicon.Switch do
  use Mix.Task

  import Dicon, only: [config: 1]

  alias Dicon.Executor

  def run(argv) do
    case OptionParser.parse(argv, strict: []) do
      {_opts, [version], []} ->
        target_dir =
          case config(:target_dir) do
            "/" <> _ = dir -> dir
            dir -> ["$PWD", ?/, dir]
          end
        for {_name, authority} <- config(:hosts) do
          conn = Executor.connect(authority)
          symlink(conn, [target_dir, ?/, version], [target_dir, "/current"])
        end
      {_opts, _commands, [switch | _]} ->
        Mix.raise "Invalid option: " <> Mix.Dicon.switch_to_string(switch)
      {_opts, _commands, _errors} ->
        Mix.raise "Expected a single argument (the version)"
    end
  end

  defp symlink(conn, source, target) do
    command = ["ln -snf ", source, ?\s, target]
    :ok = Executor.exec(conn, command)
  end
end
