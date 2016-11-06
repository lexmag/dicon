defmodule Mix.Tasks.Dicon.Tail do
  use Mix.Task

  @shortdoc "Continuously tails the given patterns"

  @moduledoc """
  This task shows the "tailing" of the given patterns.

  The configured hosts are picked up from the application's configuration; read
  the `Dicon` documentation for more information.

  The files are tailed continuously (`tail -f`), thus this task never finishes
  unless there is an error. To exit, just exit in the same way you kill any
  running Mix task.

  This task accepts one or more arguments, that are the path wildcards to tail.

  Note that this task tails the log from all hosts (taking `--only`/`--skip`
  into account): each log line will be prefixed with the host it comes from.

  ## Usage

      mix dicon.tail PATTERN1 PATTERN2 ...

  ## Examples

      mix dicon.tail my_app/logs/erlang.log.*

  """

  import Dicon, only: [config: 2, host_config: 1]

  alias Dicon.Executor

  @options [strict: [only: :keep, skip: :keep]]

  def run(argv) do
    case OptionParser.parse(argv, @options) do
      {opts, [_ | _] = patterns, []} ->
        # First, we connect to all authorities (before tailing any of them).
        args_per_host =
          for host <- config(:hosts, opts) do
            authority = Keyword.fetch!(host_config(host), :authority)
            conn = Executor.connect(authority)
            [conn, patterns, &format_tail_line(&1, host)]
          end
        args_per_host
        |> Enum.map(&Task.async(Executor, :tail, &1))
        |> Enum.each(&Task.await(&1, :infinity))
      {_opts, _commands, [switch | _]} ->
        Mix.raise "Invalid option: " <> Mix.Dicon.switch_to_string(switch)
      {_opts, [], _errors} ->
        Mix.raise "Expected at least one pattern to tail"
    end
  end

  defp format_tail_line(line, host) do
    IO.ANSI.format([:yellow, "#{host}:", :reset, " ", line])
  end
end
