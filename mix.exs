defmodule MaruEntity.Mixfile do
  use Mix.Project

  def project do
    [app: :maru_entity,
     version: "0.0.1",
     elixir: "~> 1.0",
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{ :poison, "~> 1.3.1" },
     { :amrita, "~> 0.4", github: "josephwilk/amrita", only: :test }]
  end
end
