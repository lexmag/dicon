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

  # Size in bytes.
  @file_chunk_size 100_000

  defstruct [
    :conn,
    :connect_timeout,
    :write_timeout,
    :exec_timeout
  ]

  @localhost {127, 0, 0, 1}

  @impl true
  def connect(authority, host_config) do
    config = Application.get_env(:dicon, __MODULE__, [])
    connect_timeout = Keyword.get(config, :connect_timeout, 5_000)
    write_timeout = Keyword.get(config, :write_timeout, 5_000)
    exec_timeout = Keyword.get(config, :exec_timeout, 5_000)
    user_dir = config |> Keyword.get(:dir, "~/.ssh") |> Path.expand() |> String.to_charlist()
    connect_options = put_option([], :user_dir, user_dir)

    target_authority = parse_authority(authority)

    jump_authority =
      case Keyword.fetch(host_config, :jump_authority) do
        {:ok, jump_authority} -> parse_authority(jump_authority)
        :error -> nil
      end

    with :ok <- ensure_started(),
         {:ok, conn} <-
           connect(target_authority, jump_authority, connect_options, connect_timeout) do
      state = %__MODULE__{
        conn: conn,
        connect_timeout: connect_timeout,
        write_timeout: write_timeout,
        exec_timeout: exec_timeout
      }

      {:ok, state}
    else
      error ->
        format_if_error(error)
    end
  end

  defp connect({user, password, host, port}, connect_options, connect_timeout) do
    connect_options =
      connect_options
      |> put_option(:user, user)
      |> put_option(:password, password)

    :ssh.connect(host, port, connect_options, connect_timeout)
  end

  defp connect(target_authority, nil, connect_options, connect_timeout) do
    connect(target_authority, connect_options, connect_timeout, 0)
  end

  if Code.ensure_loaded?(:ssh) and function_exported?(:ssh, :tcpip_tunnel_to_server, 6) do
    defp connect(target_authority, jump_authority, connect_options, connect_timeout) do
      {target_user, target_password, target_host, target_port} = target_authority

      with {:ok, jump_conn} <- connect(jump_authority, connect_options, connect_timeout),
           {:ok, tunnel_port} <-
             :ssh.tcpip_tunnel_to_server(
               jump_conn,
               @localhost,
               0,
               target_host,
               target_port,
               connect_timeout
             ) do
        # Wait a bit for the tunnel to be available.
        Process.sleep(1_000)
        tunnel_authority = {target_user, target_password, @localhost, tunnel_port}

        connect_options =
          connect_options
          |> Keyword.put(:silently_accept_hosts, true)
          |> Keyword.put(:save_accepted_host, false)

        connect_to_tunnel(tunnel_authority, connect_options, connect_timeout)
      end
    end

    defp connect_to_tunnel(authority, connect_options, connect_timeout, retries \\ 2) do
      with {:error, :timeout} <- connect(authority, connect_options, connect_timeout) do
        if retries > 0 do
          Process.sleep(1_000)
          connect_to_tunnel(authority, connect_options, connect_timeout, retries - 1)
        else
          {:error, :timeout}
        end
      end
    end
  else
    defp connect(_target_authority, _jump_authority, _connect_options, _connect_timeout) do
      {:error, ":jump_authority option is only supported in OTP 23+"}
    end
  end

  defp put_option(options, key, value) do
    if value do
      Keyword.put(options, key, value)
    else
      options
    end
  end

  defp ensure_started() do
    case :ssh.start() do
      :ok ->
        :ok

      {:error, {:already_started, :ssh}} ->
        :ok

      {:error, reason} ->
        {:error, "could not start ssh application: " <> Application.format_error(reason)}
    end
  end

  defp parse_authority(authority) do
    %URI{host: host, port: port, userinfo: user_info} = URI.parse("ssh://" <> authority)

    parts = String.split(user_info, ":", parts: 2, trim: true)
    destructure([user, password], parts)

    {maybe_to_charlist(user), maybe_to_charlist(password), maybe_to_charlist(host), port || 22}
  end

  defp maybe_to_charlist(value) do
    if is_binary(value) do
      String.to_charlist(value)
    else
      value
    end
  end

  @impl true
  def exec(%__MODULE__{} = state, command, device) do
    %{conn: conn, connect_timeout: connect_timeout, exec_timeout: exec_timeout} = state

    result =
      with {:ok, channel} <- :ssh_connection.session_channel(conn, connect_timeout),
           :success <- :ssh_connection.exec(conn, channel, command, exec_timeout) do
        handle_reply(conn, channel, device, exec_timeout, _acc = [])
      end

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

  @impl true
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
           :ok <- :ssh_connection.send_eof(conn, channel) do
        handle_reply(conn, channel, Process.group_leader(), exec_timeout, _acc = [])
      end

    format_if_error(result)
  end

  @impl true
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
           :ok <- :ssh_connection.send_eof(conn, channel) do
        handle_reply(conn, channel, Process.group_leader(), exec_timeout, _acc = [])
      end

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

  defp format_if_error(other), do: other
end
