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
    run([source, "0.1.0"])

    release_file = "test/release.tar.gz"

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test"]}
    assert_receive {:dicon, ^ref, :copy, [^source, ^release_file]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test/0.1.0"]}
    assert_receive {:dicon, ^ref, :exec, ["tar -C test/0.1.0 -zxf " <> ^release_file]}
    assert_receive {:dicon, ^ref, :exec, ["rm " <> ^release_file]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test"]}
    assert_receive {:dicon, ^ref, :copy, [^source, ^release_file]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test/0.1.0"]}
    assert_receive {:dicon, ^ref, :exec, ["tar -C test/0.1.0 -zxf " <> ^release_file]}
    assert_receive {:dicon, ^ref, :exec, ["rm " <> ^release_file]}

    refute_receive _any
  end

  test "it accepts only two arguments" do
    message = "Expected two arguments (the tarball path and the version)"
    assert_raise Mix.Error, message, fn -> run([]) end
    assert_raise Mix.Error, message, fn -> run(~w(one)) end

    message = "Invalid option: --invalid"
    assert_raise Mix.Error, message, fn -> run(~w(--invalid option)) end

    message = "Invalid option: --no-value"
    assert_raise Mix.Error, message, fn -> run(~w(--no-value)) end
  end
end
