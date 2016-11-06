defmodule Mix.Tasks.Dicon.TailTest do
  use DiconTest.Case

  import Mix.Tasks.Dicon.Tail, only: [run: 1]

  test "tails the given list of patterns" do
    config = %{
      target_dir: "/home/test",
      hosts: [:one],
      one: [authority: "one"],
    }
    Mix.Config.persist(dicon: config)

    run(["./foo.log", "./logs/*.log"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :tail, [["./foo.log", "./logs/*.log"]]}

    refute_receive {:dicon, _, _, _}
  end

  test "hosts filtering" do
    config = %{
      target_dir: "test",
      hosts: [:one, :two],
      one: [authority: "one"],
      two: [authority: "two"],
    }
    Mix.Config.persist(dicon: config)

    run(["./foo.log", "--only", "one"])
    assert_receive {:dicon, ref, :connect, ["one"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["./foo.log", "--skip", "one"])
    assert_receive {:dicon, ref, :connect, ["two"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["./foo.log", "--skip", "one", "--only", "one"])
    refute_receive {:dicon, _, _, _}

    run(["./foo.log", "--only", "one", "--only", "two"])
    assert_receive {:dicon, ref, :connect, ["one"]}
    :ok = flush_reply(ref)
    assert_receive {:dicon, ref, :connect, ["two"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run(["./foo.log", "--skip", "one", "--skip", "two"])
    refute_receive {:dicon, _, _, _}

    assert_raise Mix.Error, "unknown host: \"foo\"", fn ->
      run(["./foo.log", "--skip", "foo", "--skip", "two"])
    end
  end

  test "the task requires one or more arguments" do
    message = "Expected at least one pattern to tail"
    assert_raise Mix.Error, message, fn -> run([]) end
  end
end
