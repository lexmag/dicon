defmodule Mix.Tasks.Dicon.SwitchTest do
  use DiconTest.Case

  import Mix.Tasks.Dicon.Switch, only: [run: 1]

  test "relative path" do
    config = [
      target_dir: "test",
      hosts: [:one, :two],
      one: [authority: "one"],
      two: [authority: "two"],
    ]
    Mix.Config.persist(dicon: config)

    run(["0.1.0"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["ln -snf $PWD/test/0.1.0 $PWD/test/current", false]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["ln -snf $PWD/test/0.1.0 $PWD/test/current", false]}

    refute_receive {:dicon, _, _, _}
  end

  test "absolute path" do
    config = [
      target_dir: "/home/test",
      hosts: [:one],
      one: [authority: "one"],
    ]
    Mix.Config.persist(dicon: config)

    run(["0.2.0"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["ln -snf /home/test/0.2.0 /home/test/current", false]}

    refute_receive {:dicon, _, _, _}
  end

  test "hosts filtering" do
    config = [
      target_dir: "test",
      hosts: [:one, :two],
      one: [authority: "one"],
      two: [authority: "two"],
    ]
    Mix.Config.persist(dicon: config)

    run(["0.2.0", "--only", "one"])
    assert_receive {:dicon, ref, :connect, ["one"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["0.2.0", "--skip", "one"])
    assert_receive {:dicon, ref, :connect, ["two"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["0.2.0", "--skip", "one", "--only", "one"])
    refute_receive {:dicon, _, _, _}

    run(["0.2.0", "--only", "one", "--only", "two"])
    assert_receive {:dicon, ref, :connect, ["one"]}
    :ok = flush_reply(ref)
    assert_receive {:dicon, ref, :connect, ["two"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["0.2.0", "--skip", "one", "--skip", "two"])
    refute_receive {:dicon, _, _, _}

    assert_raise Mix.Error, "unknown host: \"foo\"", fn ->
      run(["0.2.0", "--skip", "foo", "--skip", "two"])
    end
  end

  test "the task only accepts one argument" do
    message = "Expected a single argument (the version)"
    assert_raise Mix.Error, message, fn -> run([]) end
    assert_raise Mix.Error, message, fn -> run(~w(one two)) end

    message = "Invalid option: --invalid"
    assert_raise Mix.Error, message, fn -> run(~w(--invalid option)) end

    message = "Invalid option: --no-value"
    assert_raise Mix.Error, message, fn -> run(~w(--no-value)) end
  end
end
