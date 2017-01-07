defmodule MaruEntity.Mixfile do
  use Mix.Project

  def project do
    [app: :maru_entity,
     version: "0.1.2",
     elixir: "~> 1.0",
     description: "Elixir copy of grape-entity",
     deps: deps()]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    []
  end
end
