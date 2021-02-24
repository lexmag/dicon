defmodule Mix.Tasks.Dicon.Deploy do
  use Mix.Task

  @shortdoc "Uploads a tarball to the configured server"

  @moduledoc """
  This task uploads the specified tarball on the configured hosts.

  The configured hosts are picked up from the application's configuration; read
  the `Dicon` documentation for more information.

  This task accepts two arguments: the compressed tarball to upload and its version. There are
  also two flags that can be passed to configure uploading the tarball to multiple hosts in
  parallel.

  ## Flags

    This command supports the following CLI flags:

    * `--parallel` - boolean flag that will enable uploading the compressed tarball in parallel to all hosts.
    * `--timeout` - the value in milliseconds for a timeout for each async upload. Defaults to `:infinity`.

    `--timeout` is ignored if it is passed without `--parallel`.

  ## Usage

      mix dicon.deploy TARBALL VERSION

  ## Examples

      mix dicon.deploy my_app.tar.gz 1.0.0
      mix dicon.deploy --parallel my_app.tar.gz 1.0.0
      mix dicon.deploy my_app.tar.gz 1.0.0 --parallel --timeout 36000

  """

  import Dicon, only: [config: 1, config: 2, host_config: 1]

  alias Dicon.Executor

  @options [strict: [only: :keep, skip: :keep, parallel: :boolean, timeout: :integer]]

  def run(argv) do
    case OptionParser.parse(argv, @options) do
      {opts, [source, version], []} ->
        target_dir = config(:target_dir)
        hosts = config(:hosts, opts)

        if opts[:parallel] do
          parallel_deploy(hosts, target_dir, version, source, opts)
        else
          Enum.map(hosts, &deploy(&1, source, target_dir, version, false))
        end

      {_opts, _commands, [switch | _]} ->
        Mix.raise("Invalid option: " <> Mix.Dicon.switch_to_string(switch))

      {_opts, _commands, _errors} ->
        Mix.raise("Expected two arguments (the tarball path and the version)")
    end
  end

  defp parallel_deploy(hosts, target_dir, version, source, opts) do
    timeout = Keyword.get(opts, :timeout, :infinity)
    [first | hosts] = hosts
    task = Task.async(fn -> deploy(first, source, target_dir, version, false) end)

    other_ios =
      Task.async_stream(
        hosts,
        &ExUnit.CaptureIO.capture_io(fn -> deploy(&1, source, target_dir, version, true) end),
        timeout: timeout,
        ordered: false,
        max_concurrency: length(hosts)
      )

    Task.await(task, timeout)

    Enum.each(other_ios, fn
      {:ok, ""} -> :ok
      {:ok, io} -> IO.puts(io)
      {:error, reason} -> IO.puts("Deploy failed for reason #{inspect(reason)}")
    end)
  end

  defp deploy(host, source, target_dir, version, silent) do
    host_config = host_config(host)
    authority = Keyword.fetch!(host_config, :authority)
    conn = Executor.connect(authority)
    release_file = upload(conn, silent, [source], target_dir)
    target_dir = [target_dir, ?/, version]
    unpack(conn, silent, release_file, target_dir)
    write_custom_config(conn, silent, host_config, target_dir, version)
  end

  defp ensure_dir(conn, silent, path) do
    Executor.exec(conn, silent, ["mkdir -p ", path])
  end

  defp upload(conn, silent, source, target_dir) do
    ensure_dir(conn, silent, target_dir)
    release_file = [target_dir, "/release.tar.gz"]
    Executor.copy(conn, silent, source, release_file)
    release_file
  end

  defp unpack(conn, silent, release_file, target_dir) do
    ensure_dir(conn, silent, target_dir)
    command = ["tar -C ", target_dir, " -zxf ", release_file]
    Executor.exec(conn, silent, command)
    Executor.exec(conn, silent, ["rm ", release_file])
  end

  defp write_custom_config(conn, silent, host_config, target_dir, version) do
    if config = host_config[:apps_env] do
      sys_config_path = [target_dir, "/releases/", version, "/sys.config"]

      # We use StringIO to receive "sys.config" content
      # that we can parse later.
      {:ok, device} = StringIO.open("")
      Executor.exec(conn, silent, ["cat ", sys_config_path], device)
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
      Executor.write_file(conn, silent, sys_config_path, content)
    end
  end
end
