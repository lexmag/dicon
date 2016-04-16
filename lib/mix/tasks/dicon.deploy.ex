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
        for {name, authority} <- config(:hosts, opts) do
          conn = Executor.connect(authority)
          release_file = upload(conn, [source], target_dir)
          target_dir = [target_dir, ?/, version]
          unpack(conn, release_file, target_dir)
          write_custom_config(conn, name, target_dir, version)
        end
      {_opts, _commands, [switch | _]} ->
        Mix.raise "Invalid option: " <> Mix.Dicon.switch_to_string(switch)
      {_opts, _commands, _errors} ->
        Mix.raise "Expected two arguments (the tarball path and the version)"
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

  defp write_custom_config(conn, name, target_dir, version) do
    if config = host_config(name) do
      target_sub_dir = ["/releases/", version, ?/]
      config_sub_path = [target_sub_dir, "custom.config"]

      content = :io_lib.format('~p.\n', [config])
      Executor.write_file(conn, [target_dir, config_sub_path], content)

      vm_args_path = [target_dir, target_sub_dir, "vm.args"]
      content = ["-config ", ?., config_sub_path, ?\n]
      Executor.write_file(conn, vm_args_path, content, :append)
    end
  end
end
