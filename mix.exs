defmodule Dicon.Mixfile do
  use Mix.Project

  @version "0.6.0"
  @source_url "https://github.com/lexmag/dicon"

  def project() do
    [
      app: :dicon,
      version: @version,
      elixir: "~> 1.12",
      deps: deps(),

      # Docs
      name: "Dicon",
      docs: docs(),

      # Hexpm
      package: package(),
      description: description()
    ]
  end

  def application() do
    [extra_applications: [:logger, :ssh]]
  end

  defp package() do
    [
      licenses: ["ISC"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp description() do
    "Simple release deliverer for Elixir"
  end

  defp deps() do
    [
      {:ex_doc, "~> 0.40.0", only: :docs, runtime: false}
    ]
  end

  defp docs() do
    [
      main: "Dicon",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["CHANGELOG.md"]
    ]
  end
end
