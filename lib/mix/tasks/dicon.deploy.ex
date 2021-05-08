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

  import Dicon, only: [config: 1, config: 2, host_config: 1]

  alias Dicon.Executor

  @options [strict: [only: :keep, skip: :keep]]

  def run(argv) do
    case OptionParser.parse(argv, @options) do
      {opts, [source, version], []} ->
        target_dir = config(:target_dir)

        for host <- config(:hosts, opts) do
          host_config = host_config(host)
          authority = Keyword.fetch!(host_config, :authority)
          conn = Executor.connect(authority)
          release_file = upload(conn, [source], target_dir)
          target_dir = [target_dir, ?/, version]
          unpack(conn, release_file, target_dir)
          write_custom_config(conn, host_config, target_dir, version)
        end

      {_opts, _commands, [switch | _]} ->
        Mix.raise("Invalid option: " <> Mix.Dicon.switch_to_string(switch))

      {_opts, _commands, _errors} ->
        Mix.raise("Expected two arguments (the tarball path and the version)")
    end
  end

  defp ensure_dir(conn, path) do
    Executor.exec(conn, ["mkdir -p ", path])
  end

  defp upload(conn, source, target_dir) do
    ensure_dir(conn, target_dir)
    release_file = [target_dir, "/release.tar.gz"]
    Executor.copy(conn, source, release_file)
    release_file
  end

  defp unpack(conn, release_file, target_dir) do
    ensure_dir(conn, target_dir)
    command = ["tar -C ", target_dir, " -zxf ", release_file]
    Executor.exec(conn, command)
    Executor.exec(conn, ["rm ", release_file])
  end

  defp write_custom_config(conn, host_config, target_dir, version) do
    if config = host_config[:apps_env] do
      sys_config_path = [target_dir, "/releases/", version, "/sys.config"]

      # We use StringIO to receive "sys.config" content
      # that we can parse later.
      {:ok, device} = StringIO.open("")
      Executor.exec(conn, ["cat ", sys_config_path], device)
      {:ok, {"", sys_config_content}} = StringIO.close(device)
      {:ok, device} = StringIO.open(sys_config_content)

      sys_config =
        case :io.read(device, "") do
          {:ok, sys_config} -> sys_config
          {:error, _reason} -> Mix.raise("Could not parse \"sys.config\" file")
          :eof -> Mix.raise("\"sys.config\" file is incomplete")
        end

      {:ok, _} = StringIO.close(device)

      config = Mix.Config.merge(sys_config, config)
      content = :io_lib.format("~p.~n", [config])
      Executor.write_file(conn, sys_config_path, content)
    end
  end
end
