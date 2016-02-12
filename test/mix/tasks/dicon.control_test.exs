defmodule Mix.Tasks.Dicon.ControlTest do
  use DiconTest.Case

  import Mix.Tasks.Dicon.Control, only: [run: 1]

  setup do
    config = %{
      otp_app: :sample,
      target_dir: "test",
      hosts: [one: "one", two: "two"]
    }
    Mix.Config.persist(dicon: config)
    :ok
  end

  test "commands are run and feedback is received" do
    run(["run"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["test/current/bin/sample run"]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["test/current/bin/sample run"]}
  end

  test "the task only accepts one argument" do
    message = "Expected a single argument (the command to execute)"
    assert_raise Mix.Error, message, fn -> run([]) end
    assert_raise Mix.Error, message, fn -> run(~w(one two)) end

    message = "Invalid option: --invalid"
    assert_raise Mix.Error, message, fn -> run(~w(--invalid option)) end

    message = "Invalid option: --no-value"
    assert_raise Mix.Error, message, fn -> run(~w(--no-value)) end
  end
end
