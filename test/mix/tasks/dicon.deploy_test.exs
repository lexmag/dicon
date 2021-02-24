defmodule Mix.Tasks.Dicon.DeployTest do
  use DiconTest.Case

  import PathHelpers
  import Mix.Tasks.Dicon.Deploy, only: [run: 1]

  setup_all do
    config = [
      target_dir: "test",
      hosts: [:one, :two],
      one: [
        authority: "one",
        apps_env: [foo: [bar: "baz"]],
      ],
      two: [
        authority: "two",
      ],
    ]
    Mix.Config.persist(dicon: config)
    :ok
  end

  test "the release is uploaded correctly" do
    source = fixture_path("empty.tar.gz")
    release_file = "test/release.tar.gz"

    on_exec("cat test/0.1.0/releases/0.1.0/sys.config", fn device ->
      IO.write(device, "[{foo,[{qux,<<\"baz\">>}]}].\n")
    end)

    run([source, "0.1.0"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test", false]}
    assert_receive {:dicon, ^ref, :copy, [^source, ^release_file, false]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test/0.1.0", false]}
    assert_receive {:dicon, ^ref, :exec, ["tar -C test/0.1.0 -zxf " <> ^release_file, false]}
    assert_receive {:dicon, ^ref, :exec, ["rm " <> ^release_file, false]}
    assert_receive {:dicon, ^ref, :exec, ["cat test/0.1.0/releases/0.1.0/sys.config", false]}
    assert_receive {:dicon, ^ref, :write_file, ["test/0.1.0/releases/0.1.0/sys.config", "[{foo,[{qux,<<\"baz\">>},{bar,<<\"baz\">>}]}].\n", :write, false]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test", false]}
    assert_receive {:dicon, ^ref, :copy, [^source, ^release_file, false]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test/0.1.0", false]}
    assert_receive {:dicon, ^ref, :exec, ["tar -C test/0.1.0 -zxf " <> ^release_file, false]}
    assert_receive {:dicon, ^ref, :exec, ["rm " <> ^release_file, false]}

    refute_receive {:dicon, _, _, _}
  end

  test "the release is uploaded in parallel correctly" do
    source = fixture_path("empty.tar.gz")
    release_file = "test/release.tar.gz"

    on_exec("cat test/0.1.0/releases/0.1.0/sys.config", fn device ->
      IO.write(device, "[{foo,[{qux,<<\"baz\">>}]}].\n")
    end)

    run(["--parallel", "--timeout", "36000", source, "0.1.0"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test", false]}
    assert_receive {:dicon, ^ref, :copy, [^source, ^release_file, false]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test/0.1.0", false]}
    assert_receive {:dicon, ^ref, :exec, ["tar -C test/0.1.0 -zxf " <> ^release_file, false]}
    assert_receive {:dicon, ^ref, :exec, ["rm " <> ^release_file, false]}
    assert_receive {:dicon, ^ref, :exec, ["cat test/0.1.0/releases/0.1.0/sys.config", false]}
    assert_receive {:dicon, ^ref, :write_file, ["test/0.1.0/releases/0.1.0/sys.config", "[{foo,[{qux,<<\"baz\">>},{bar,<<\"baz\">>}]}].\n", :write, false]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test", true]}
    assert_receive {:dicon, ^ref, :copy, [^source, ^release_file, true]}
    assert_receive {:dicon, ^ref, :exec, ["mkdir -p test/0.1.0", true]}
    assert_receive {:dicon, ^ref, :exec, ["tar -C test/0.1.0 -zxf " <> ^release_file, true]}
    assert_receive {:dicon, ^ref, :exec, ["rm " <> ^release_file, true]}

    refute_receive {:dicon, _, _, _}
  end

  test "hosts filtering" do
    source = fixture_path("empty.tar.gz")

    on_exec("cat test/0.1.0/releases/0.1.0/sys.config", fn device ->
      IO.write(device, "[].\n")
    end)

    run([source, "0.1.0", "--only", "one"])
    assert_receive {:dicon, ref, :connect, ["one"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run([source, "0.1.0", "--skip", "one"])
    assert_receive {:dicon, ref, :connect, ["two"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run([source, "0.1.0", "--skip", "one", "--only", "one"])
    refute_receive {:dicon, _, _, _}

    on_exec("cat test/0.1.0/releases/0.1.0/sys.config", fn device ->
      IO.write(device, "[].\n")
    end)

    run([source, "0.1.0", "--only", "one", "--only", "two"])
    assert_receive {:dicon, ref, :connect, ["one"]}
    :ok = flush_reply(ref)
    assert_receive {:dicon, ref, :connect, ["two"]}
    :ok = flush_reply(ref)
    refute_receive {:dicon, _, _, _}

    run([source, "0.1.0", "--skip", "one", "--skip", "two"])
    refute_receive {:dicon, _, _, _}

    assert_raise Mix.Error, "unknown host: \"foo\"", fn ->
      run([source, "0.1.0", "--skip", "foo", "--skip", "two"])
    end
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
