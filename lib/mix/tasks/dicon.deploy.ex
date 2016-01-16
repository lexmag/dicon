defmodule Mix.Tasks.Dicon.Deploy do
  use Mix.Task

  import Dicon, only: [config: 1]

  alias Dicon.Executor

  def run(argv) do
    {_opts, [source], []} = OptionParser.parse(argv)
    target_dir = config(:target_dir)
    for {_name, authority} <- config(:hosts) do
      conn = Executor.connect(authority)
      release_file = upload(conn, [source], target_dir)
      unpack(conn, release_file, [target_dir, "/current"])
    end
  end

  defp ensure_dir(conn, path) do
    :ok = Executor.exec(conn, ["mkdir -p ", path])
  end

  defp upload(conn, source, target_dir) do
    :ok = ensure_dir(conn, target_dir)
    release_file = [target_dir, "/release.tar.gz"]
    :ok = Executor.copy(conn, source, release_file)
    release_file
  end

  defp unpack(conn, release_file, target_dir) do
    :ok = ensure_dir(conn, target_dir)
    command = ["tar -C ", target_dir, " -zxf ", release_file]
    :ok = Executor.exec(conn, command)
  end
end
