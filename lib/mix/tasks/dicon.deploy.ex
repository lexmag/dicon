defmodule Mix.Tasks.Dicon.Deploy do
  use Mix.Task

  @shortdoc "Uploads a tarball to the configured server"

  @moduledoc """
  This task uploads the specified tarball on the configured hosts.

  The configured hosts are picked up from the application's configuration; read
  the `Dicon` documentation for more information.

  This task accepts two arguments: the compressed tarball to upload and its version.

  ## Usage

      mix dicon.deploy TARBALL VERSION

  ## Examples

      mix dicon.deploy my_app.tar.gz 1.0.0

  """

  import Dicon, only: [config: 1]

  alias Dicon.Executor

  def run(argv) do
    case OptionParser.parse(argv, strict: []) do
      {_opts, [source, version], []} ->
        target_dir = config(:target_dir)
        for {_name, authority} <- config(:hosts) do
          conn = Executor.connect(authority)
          release_file = upload(conn, [source], target_dir)
          unpack(conn, release_file, [target_dir, ?/, version])
        end
      {_opts, _commands, [switch | _]} ->
        Mix.raise "Invalid option: " <> Mix.Dicon.switch_to_string(switch)
      {_opts, _commands, _errors} ->
        Mix.raise "Expected two arguments (the tarball path and the version)"
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
    :ok = Executor.exec(conn, ["rm ", release_file])
  end
end
