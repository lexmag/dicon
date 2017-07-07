defmodule Dicon do
  @moduledoc """
  Simple release deliverer for Elixir.

  Dicon gets most of the information needed to deploy and manage releases from
  the configuration of the `:dicon` application. For example, in your
  application's configuration (`my_app/config/config.exs`):

      config :dicon,
        target_dir: "/home/deploy/my_app"

  ## Configuration options

    * `:otp_app` - an atom that specifies the name of the application being
      deployed.

    * `:target_dir` - a binary that specifies the directory where the release
      tarball will be extracted into.

    * `:hosts` - a list of `host_name` atoms that specifies which
      servers the release should be deployed to. Each host should be then
      configured under the `:dicon` application. See the "Configuration for hosts"
      section below.
      `authority`s should be "authorities" according to [this
      RFC](https://tools.ietf.org/html/rfc3986#section-3.2), i.e., binaries with
      an optional userinfo followed by `@`, an hostname, and an optional port
      preceded by `:`. For example, `me:mypassword@example.com:22`.

    * `:executor` - a module that will be used to execute commands on servers.
      By default, it's `Dicon.SecureShell`.

  ### Configuration for hosts

  Each host listed in the `:hosts` configuration option mentioned above can be
  configured under the `:dicon` application. For example, take this configuration:

      config :dicon,
        hosts: [:app01, :app02]

  Now the `:app01` and `:app02` hosts can be configured like this:

      config :dicon, :app01,
        authority: "myuser@app01.example.net"

  These are the supported host configuration options:

    * `:authority` - (binary) an "authority" according to [this
      RFC](https://tools.ietf.org/html/rfc3986#section-3.2), that is, a binary with
      an optional userinfo followed by `@`, an hostname, and an optional port
      preceded by `:`. For example, `"me:mypassword@example.net:22"`.

    * `:os_env` - (map) a map of environment variable name (as a binary) to
      value (as a binary). These environment variables will be used when running
      commands on the target host.

    * `:apps_env` - (keyword list) a keyword list of application to configuration
      that can be used to override the configuration for some applications on
      the target host.

  ### Configuration for executors

  Each executor can be configured differently; to configure an executor, specify
  the configuration for that executor under the configuration for the `:dicon`
  application.

      config :dicon, Dicon.SecureShell,
        dir: "..."

  """

  @doc false
  def config(key, opts \\ [])

  def config(:hosts, opts) do
    only = Keyword.get_values(opts, :only) |> Enum.map(&String.to_atom/1)
    skip = Keyword.get_values(opts, :skip) |> Enum.map(&String.to_atom/1)

    hosts = Application.fetch_env!(:dicon, :hosts)

    assert_filtered_hosts_exist(hosts, only ++ skip)

    Enum.filter(hosts, hosts_selector(only, skip))
  end

  def config(key, _opts) do
    Application.fetch_env!(:dicon, key)
  end

  def host_config(name) do
    Application.fetch_env!(:dicon, name)
  end

  defp assert_filtered_hosts_exist(hosts, filtered_hosts) do
    if unknown_host = Enum.find(filtered_hosts, &not(&1 in hosts)) do
      Mix.raise "unknown host: #{inspect(Atom.to_string(unknown_host))}"
    end
  end

  defp hosts_selector([], skip) do
    &not(&1 in skip)
  end

  defp hosts_selector(only, skip) do
    only = only -- skip
    &(&1 in only)
  end
end
