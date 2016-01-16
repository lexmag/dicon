defmodule Mix.Tasks.Dicon.DeployTest do
  use DiconTest.Case

  import PathHelpers

  setup_all do
    config = %{
      target_dir: "test",
      hosts: [one: "one", two: "two"],
    }
    Mix.Config.persist(dicon: config)
    :ok
  end

  test "" do
    source = fixture_path("empty.tar.gz")
    Mix.Tasks.Dicon.Deploy.run([source])

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
end
