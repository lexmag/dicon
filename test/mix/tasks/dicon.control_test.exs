defmodule Mix.Tasks.Dicon.ControlTest do
  use DiconTest.Case

  setup do
    config = %{
      app_name: "sample",
      target_dir: "test",
      hosts: [one: "one", two: "two"]
    }
    Mix.Config.persist(dicon: config)
    :ok
  end

  test "" do
    Mix.Tasks.Dicon.Control.run(["run"])

    assert_receive {:dicon, ref, :connect, ["one"]}
    assert_receive {:dicon, ^ref, :exec, ["test/current/bin/sample run"]}

    assert_receive {:dicon, ref, :connect, ["two"]}
    assert_receive {:dicon, ^ref, :exec, ["test/current/bin/sample run"]}
  end
end
