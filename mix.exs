defmodule Dicon.Mixfile do
  use Mix.Project

  def project() do
    [app: :dicon,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod]
  end

  def application() do
    [applications: [:logger, :ssh]]
  end
end
