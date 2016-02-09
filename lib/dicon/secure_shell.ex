defmodule Dicon.SecureShell do
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
    :ok = ensure_started()
    :ssh.connect(host, port, opts, @timeout)
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
        Mix.raise "Could not start ssh application: " <>
          Application.format_error(reason)
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

  def exec(conn, command) do
    {:ok, channel} = :ssh_connection.session_channel(conn, @timeout)
    :success = :ssh_connection.exec(conn, channel, command, @timeout)
    handle_reply(conn, channel, [])
  end

  defp handle_reply(conn, channel, acc) do
    receive do
      {:ssh_cm, ^conn, {:data, ^channel, _code, data}} ->
        handle_reply(conn, channel, [acc | data])
      {:ssh_cm, ^conn, {:eof, ^channel}} ->
        handle_reply(conn, channel, acc)
      {:ssh_cm, ^conn, {:exit_status, ^channel, _status}} ->
        handle_reply(conn, channel, acc)
      {:ssh_cm, ^conn, {:closed, ^channel}} ->
        IO.write(acc)
    after
      @timeout -> {:error, :timeout}
    end
  end

  def copy(conn, source, target) do
    %{size: size} = File.stat!(source)
    stream = File.stream!(source, [], div(size, 100))
    {:ok, channel} = :ssh_sftp.start_channel(conn, [timeout: @timeout])
    {:ok, handle} = :ssh_sftp.open(channel, target, [:write, :binary], @timeout)
    Enum.each(stream, fn chunk ->
      :ok = :ssh_sftp.write(channel, handle, chunk, @timeout)
      IO.write "."
    end)
    IO.puts "\n"
    :ok = :ssh_sftp.close(channel, handle, @timeout)
    :ok = :ssh_sftp.stop_channel(channel)
  end
end
