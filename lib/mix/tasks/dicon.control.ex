defmodule Mix.Tasks.Dicon.Control do
  use Mix.Task

  import Dicon, only: [config: 1]

  alias Dicon.Executor

  def run(argv) do
    {_opts, [command], []} = OptionParser.parse(argv)
    for {_name, authority} <- config(:hosts) do
      conn = Executor.connect(authority)
      exec(conn, config(:target_dir), command)
    end
  end

  defp exec(conn, target_dir, command) do
    app_name = config(:app_name)
    command = [target_dir, "/current/bin/", app_name, ?\s, command]
    :ok = Executor.exec(conn, command)
  end
end
