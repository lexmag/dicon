defmodule Mix.Tasks.Dicon.ControlTest do
  use DiconTest.Case

  import Mix.Tasks.Dicon.Control, only: [run: 1]

  setup do
    put_dicon_env(%{
      otp_app: :sample,
      target_dir: "test",
      hosts: [:one, :two],
      one: [authority: "one"],
      two: [authority: "two"]
    })

    :ok
  end

  test "commands are run and feedback is received" do
    run(["run"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["test/current/bin/sample run"]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["test/current/bin/sample run"]}

    refute_receive {:dicon, _, _, _}
  end

  test "hosts filtering" do
    put_dicon_env(%{
      otp_app: :sample,
      target_dir: "test",
      hosts: [:one, :two],
      one: [authority: "one"],
      two: [authority: "two"]
    })

    run(["run", "--only", "one"])
    assert_receive {:dicon, ref, :connect, ["one"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["run", "--skip", "one"])
    assert_receive {:dicon, ref, :connect, ["two"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["run", "--skip", "one", "--only", "one"])
    refute_receive {:dicon, _, _, _}

    run(["run", "--only", "one", "--only", "two"])
    assert_receive {:dicon, ref, :connect, ["one"]}
    :ok = flush_reply(ref)
    assert_receive {:dicon, ref, :connect, ["two"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["run", "--skip", "one", "--skip", "two"])
    refute_receive {:dicon, _, _, _}

    assert_raise Mix.Error, "Unknown host: \"foo\"", fn ->
      run(["run", "--skip", "foo", "--skip", "two"])
    end
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

  test "OS environment" do
    put_dicon_env(%{
      otp_app: :sample,
      target_dir: "test",
      hosts: [:one],
      one: [authority: "one", os_env: %{"IS_FOO" => "yes it is", "BAR" => "baz\"bong"}]
    })

    run(["run"])
    assert_receive {:dicon, ref, :connect, ["one"]}

    assert_receive {:dicon, ^ref, :exec,
                    [~S(BAR="baz\"bong" IS_FOO="yes it is" test/current/bin/sample run)]}
  end
end
