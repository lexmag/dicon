defmodule Dicon.Mixfile do
  use Mix.Project

  def project() do
    [app: :dicon,
     version: "0.5.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     package: package(),
     deps: deps(),
     description: description()]
  end

  def application() do
    [applications: [:logger, :ssh]]
  end

  defp package() do
    [maintainers: ["Aleksei Magusev", "Andrea Leopardi"],
     licenses: ["ISC"],
     links: %{"GitHub" => "https://github.com/lexmag/dicon"}]
  end

  defp description() do
    "Simple release deliverer for Elixir"
  end

  defp deps() do
    [{:earmark, ">= 0.0.0", only: :docs},
     {:ex_doc, ">= 0.0.0", only: :docs}]
  end
end
