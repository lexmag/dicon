defmodule Dicon.SecureShell do
  @moduledoc """
  A `Dicon.Executor` based on SSH.

  ## Configuration

  The configuration for this executor must be specified under the configuration
  for the `:dicon` application:

      config :dicon, Dicon.SecureShell,
        dir: "..."

  The available configuration options for this executor are:

    * `:dir` - a binary that specifies the directory where the SSH keys are (in
      the local machine). Defaults to `"~/.ssh"`.

  The username and password user to connect to the server will be picked up by
  the URL that identifies that server (in `:dicon`'s configuration); read more
  about this in the documentation for the `Dicon` module.

  """

  @behaviour Dicon.Executor

  @timeout 5_000

  def connect(authority) do
    config = Application.get_env(:dicon, __MODULE__, [])
    user_dir = Keyword.get(config, :dir, "~/.ssh") |> Path.expand
    {user, passwd, host, port} = parse_elements(authority)
    opts =
      put_option([], :user, user)
      |> put_option(:password, passwd)
      |> put_option(:user_dir, user_dir)
    host = String.to_char_list(host)

    result =
      with :ok <- ensure_started(),
           {:ok, conn} <- :ssh.connect(host, port, opts, @timeout),
        do: {:ok, conn}

    format_if_error(result)
  end

  defp put_option(opts, _key, nil), do: opts
  defp put_option(opts, key, value) do
    [{key, String.to_char_list(value)} | opts]
  end

  defp ensure_started() do
    case :ssh.start do
      :ok -> :ok
      {:error, {:already_started, :ssh}} -> :ok
      {:error, reason} ->
        {:error, "could not start ssh application: " <>
          Application.format_error(reason)}
    end
  end

  defp parse_elements(authority) do
    parts = String.split(authority, "@", [parts: 2])
    [user_info, host_info] = case parts do
      [host_info] ->
        ["", host_info]
      result -> result
    end

    parts = String.split(user_info, ":", [parts: 2, trim: true])
    destructure([user, passwd], parts)

    parts = String.split(host_info, ":", [parts: 2, trim: true])
    {host, port} = case parts do
      [host, port] ->
        {host, String.to_integer(port)}
      [host] -> {host, 22}
    end

    {user, passwd, host, port}
  end

  def exec(conn, command, device) do
    result =
      with {:ok, channel} <- :ssh_connection.session_channel(conn, @timeout),
           :success <- :ssh_connection.exec(conn, channel, command, @timeout),
        do: handle_reply(conn, channel, device, [])

    format_if_error(result)
  end

  defp handle_reply(conn, channel, device, acc) do
    receive do
      {:ssh_cm, ^conn, {:data, ^channel, _code, data}} ->
        handle_reply(conn, channel, device, [acc | data])
      {:ssh_cm, ^conn, {:eof, ^channel}} ->
        handle_reply(conn, device, channel, acc)
      {:ssh_cm, ^conn, {:exit_status, ^channel, _status}} ->
        handle_reply(conn, device, channel, acc)
      {:ssh_cm, ^conn, {:closed, ^channel}} ->
        IO.write(device, acc)
    after
      @timeout -> {:error, :timeout}
    end
  end

  def copy(conn, source, target) do
    result =
      with {:ok, %File.Stat{size: size}} <- File.stat(source),
           stream = File.stream!(source, [], div(size, 100)),
           {:ok, channel} <- :ssh_sftp.start_channel(conn, [timeout: @timeout]),
           {:ok, handle} <- :ssh_sftp.open(channel, target, [:write, :binary], @timeout),
           Enum.each(stream, fn chunk ->
             # TODO: we need to remove this assertion here as well, once we have a
             # better "streaming" API.
             :ok = :ssh_sftp.write(channel, handle, chunk, @timeout)
             IO.write "."
           end),
           IO.puts("\n"),
           :ok <- :ssh_sftp.close(channel, handle, @timeout),
           :ok <- :ssh_sftp.stop_channel(channel),
        do: :ok

    format_if_error(result)
  end

  defp format_if_error(:failure) do
    {:error, "failure on the SSH connection"}
  end

  defp format_if_error({:error, reason} = error) when is_binary(reason) do
    error
  end

  defp format_if_error({:error, reason}) do
    case :inet.format_error(reason) do
      'unknown POSIX error' ->
        {:error, inspect(reason)}
      message ->
        {:error, List.to_string(message)}
    end
  end

  defp format_if_error(non_error) do
    non_error
  end
end
