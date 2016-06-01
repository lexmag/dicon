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
    * `:hosts` - a list of `{host_name, authority}` that specifies on which
      servers the release should be uploaded and extracted. `host_name`s should
      be atoms; they're used to identify authorities in the list of authorities.
      `authority`s should be "authorities" according to [this
      RFC](https://tools.ietf.org/html/rfc3986#section-3.2), i.e., binaries with
      an optional userinfo followed by `@`, an hostname, and an optional port
      preceded by `:`. For example, `me:mypassword@example.com:22`.
    * `:executor` - a module that will be used to execute commands on servers.
      By default, it's `Dicon.SecureShell`.

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
    only = Keyword.get_values(opts, :only)
    skip = Keyword.get_values(opts, :skip)

    fun = hosts_selector(only, skip)

    Application.fetch_env!(:dicon, :hosts)
    |> Enum.filter(fun)
  end

  def config(key, _opts) do
    Application.fetch_env!(:dicon, key)
  end

  def host_config(name) do
    Application.get_env(:dicon, name)
  end

  defp hosts_selector([], skip) do
    skip = Enum.map(skip, &String.to_atom/1)
    &not(&1 in skip)
  end

  defp hosts_selector(only, skip) do
    only = Enum.map(only -- skip, &String.to_atom/1)
    &(&1 in only)
  end
end
