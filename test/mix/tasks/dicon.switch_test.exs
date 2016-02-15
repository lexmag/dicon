defmodule Mix.Tasks.Dicon.SwitchTest do
  use DiconTest.Case

  import Mix.Tasks.Dicon.Switch, only: [run: 1]

  test "relative path" do
    config = %{
      target_dir: "test",
      hosts: [one: "one", two: "two"],
    }
    Mix.Config.persist(dicon: config)

    run(["0.1.0"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["ln -snf $PWD/test/0.1.0 $PWD/test/current"]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["ln -snf $PWD/test/0.1.0 $PWD/test/current"]}

    refute_receive _any
  end

  test "absolute path" do
    config = %{
      target_dir: "/home/test",
      hosts: [one: "one"],
    }
    Mix.Config.persist(dicon: config)

    run(["0.2.0"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["ln -snf /home/test/0.2.0 /home/test/current"]}

    refute_receive _any
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
