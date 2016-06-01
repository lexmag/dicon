defmodule Mix.Tasks.Dicon.Switch do
  use Mix.Task

  import Dicon, only: [config: 1, config: 2, host_config: 1]

  alias Dicon.Executor

  @options [strict: [only: :keep, skip: :keep]]

  def run(argv) do
    case OptionParser.parse(argv, @options) do
      {opts, [version], []} ->
        target_dir =
          case config(:target_dir) do
            "/" <> _ = dir -> dir
            dir -> ["$PWD", ?/, dir]
          end
        for host <- config(:hosts, opts) do
          authority = Keyword.fetch!(host_config(host), :authority)
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
    Executor.exec(conn, command)
  end
end
