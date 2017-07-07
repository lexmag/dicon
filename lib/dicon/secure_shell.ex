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

    * `:connect_timeout` - an integer that specifies the timeout (in milliseconds)
      when connecting to the host.

    * `:write_timeout` - an integer that specifies the timeout (in milliseconds)
      when writing data to the host.

    * `:exec_timeout` - an integer that specifies the timeout (in milliseconds)
      when executing commands on the host.

  The username and password user to connect to the server will be picked up by
  the URL that identifies that server (in `:dicon`'s configuration); read more
  about this in the documentation for the `Dicon` module.
  """

  @behaviour Dicon.Executor

  @file_chunk_size 100_000 # in bytes

  defstruct [
    :conn,
    :connect_timeout,
    :write_timeout,
    :exec_timeout,
  ]

  def connect(authority) do
    config = Application.get_env(:dicon, __MODULE__, [])
    connect_timeout = Keyword.get(config, :connect_timeout, 5_000)
    write_timeout = Keyword.get(config, :write_timeout, 5_000)
    exec_timeout = Keyword.get(config, :exec_timeout, 5_000)
    user_dir = Keyword.get(config, :dir, "~/.ssh") |> Path.expand
    {user, passwd, host, port} = parse_elements(authority)
    opts =
      put_option([], :user, user)
      |> put_option(:password, passwd)
      |> put_option(:user_dir, user_dir)
    host = String.to_charlist(host)

    result =
      with :ok <- ensure_started(),
           {:ok, conn} <- :ssh.connect(host, port, opts, connect_timeout) do
        state = %__MODULE__{
          conn: conn,
          connect_timeout: connect_timeout,
          write_timeout: write_timeout,
          exec_timeout: exec_timeout,
        }
        {:ok, state}
      end

    format_if_error(result)
  end

  defp put_option(opts, _key, nil), do: opts
  defp put_option(opts, key, value) do
    [{key, String.to_charlist(value)} | opts]
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

  def exec(%__MODULE__{} = state, command, device) do
    %{conn: conn, connect_timeout: connect_timeout, exec_timeout: exec_timeout} = state

    result =
      with {:ok, channel} <- :ssh_connection.session_channel(conn, connect_timeout),
           :success <- :ssh_connection.exec(conn, channel, command, exec_timeout),
        do: handle_reply(conn, channel, device, exec_timeout, _acc = [])

    format_if_error(result)
  end

  defp handle_reply(conn, channel, device, exec_timeout, acc) do
    receive do
      {:ssh_cm, ^conn, {:data, ^channel, _code, data}} ->
        handle_reply(conn, channel, device, exec_timeout, [acc | data])
      {:ssh_cm, ^conn, {:eof, ^channel}} ->
        handle_reply(conn, channel, device, exec_timeout, acc)
      {:ssh_cm, ^conn, {:exit_status, ^channel, _status}} ->
        handle_reply(conn, channel, device, exec_timeout, acc)
      {:ssh_cm, ^conn, {:closed, ^channel}} ->
        IO.write(device, acc)
    after
      exec_timeout -> {:error, :timeout}
    end
  end

  def write_file(%__MODULE__{} = state, target, content, :append) do
    write_file(state, ["cat >> ", target], content)
  end

  def write_file(%__MODULE__{} = state, target, content, :write) do
    write_file(state, ["cat > ", target], content)
  end

  defp write_file(state, command, content) do
    %{conn: conn, connect_timeout: connect_timeout, exec_timeout: exec_timeout} = state

    result =
      with {:ok, channel} <- :ssh_connection.session_channel(conn, connect_timeout),
           :success <- :ssh_connection.exec(conn, channel, command, exec_timeout),
           :ok <- :ssh_connection.send(conn, channel, content, exec_timeout),
           :ok <- :ssh_connection.send_eof(conn, channel),
           do: handle_reply(conn, channel, Process.group_leader(), exec_timeout, _acc = [])

    format_if_error(result)
  end

  def copy(%__MODULE__{} = state, source, target) do
    %{conn: conn, connect_timeout: connect_timeout, exec_timeout: exec_timeout} = state

    result =
      with {:ok, %File.Stat{size: size}} <- File.stat(source),
           chunk_count = round(Float.ceil(size / @file_chunk_size)),
           stream = File.stream!(source, [], @file_chunk_size) |> Stream.with_index(1),
           {:ok, channel} <- :ssh_connection.session_channel(conn, connect_timeout),
           :success <- :ssh_connection.exec(conn, channel, ["cat > ", target], exec_timeout),
           Enum.each(stream, fn {chunk, chunk_index} ->
             # TODO: we need to remove this assertion here as well, once we have a
             # better "streaming" API.
             :ok = :ssh_connection.send(conn, channel, chunk, exec_timeout)
             write_spinner(chunk_index, chunk_count)
           end),
           IO.write(IO.ANSI.format([:clear_line, ?\r])),
           :ok <- :ssh_connection.send_eof(conn, channel),
           do: handle_reply(conn, channel, Process.group_leader(), exec_timeout, _acc = [])

    format_if_error(result)
  end

  @spinner_chars {?|, ?/, ?-, ?\\}

  defp write_spinner(index, count) do
    percent = round(100 * index / count)
    spinner = elem(@spinner_chars, rem(index, tuple_size(@spinner_chars)))
    [:clear_line, ?\r, spinner, ?\s, Integer.to_string(percent), ?%]
    |> IO.ANSI.format()
    |> IO.write()
  end

  def tail(%__MODULE__{conn: conn}, patterns, line_transformer, device) do
    result =
      with {:ok, channel} <- :ssh_connection.session_channel(conn, @timeout),
           tail_command = String.to_charlist("tail --follow=name " <> Enum.join(patterns, " ")),
           :success <- :ssh_connection.exec(conn, channel, tail_command, @timeout),
           :ok <- tail_loop(conn, channel, line_transformer, device) do
        :ok
      end

    format_if_error(result)
  end

  defp tail_loop(conn, channel, line_transformer, device) do
    receive do
      {:ssh_cm, ^conn, {:data, ^channel, _code, data}} ->
        data
        |> String.splitter("\n")
        |> Enum.each(fn(line) -> IO.write(device, [line_transformer.(line), ?\n]) end)
        tail_loop(conn, channel, line_transformer, device)
      {:ssh_cm, ^conn, {:eof, ^channel}} ->
        :ok
      {:ssh_cm, ^conn, {:exit_status, ^channel, status}} ->
        {:error, "exited with status: #{status}"}
      {:ssh_cm, ^conn, {:closed, ^channel}} ->
        {:error, "connection closed"}
    end
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
