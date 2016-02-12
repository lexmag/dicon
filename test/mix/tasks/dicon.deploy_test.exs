defmodule Mix.Tasks.Dicon.DeployTest do
  use DiconTest.Case

  import PathHelpers
  import Mix.Tasks.Dicon.Deploy, only: [run: 1]

  setup_all do
    config = %{
      target_dir: "test",
      hosts: [one: "one", two: "two"],
    }
    Mix.Config.persist(dicon: config)
    :ok
  end

  test "the release is uploaded correctly" do
    source = fixture_path("empty.tar.gz")
    run([source])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test"]}
    assert_receive {:dicon, ^ref, :copy, [^source, "test/release.tar.gz"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test/current"]}
    assert_receive {:dicon, ^ref, :exec, ["tar -C test/current -zxf test/release.tar.gz"]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test"]}
    assert_receive {:dicon, ^ref, :copy, [^source, "test/release.tar.gz"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test/current"]}
    assert_receive {:dicon, ^ref, :exec, ["tar -C test/current -zxf test/release.tar.gz"]}
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
