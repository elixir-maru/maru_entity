defmodule MaruEntity.Mixfile do
  use Mix.Project

  def project do
    [ app: :maru_entity,
      version: "0.1.2",
      elixir: "~> 1.0",
      description: "Elixir copy of grape-entity",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps(),
      description: "An API focused facade that sits on top of an object model inspired by grape-entity",
      source_url: "https://github.com/elixir-maru/maru_entity",
      package: package(),
      docs: [
        extras: ["README.md"],
        main: "readme",
      ]
    ]
  end

  def application do
    [ applications: [:logger],
    ]
  end

  defp deps do
    [ {:ex_doc, "~> 0.12", only: :docs},
    ]
  end

  defp package do
    %{ maintainers: ["Xiangrong Hao", "Teodor Pripoae"],
       licenses: ["WTFPL"],
       links: %{"Github" => "https://github.com/elixir-maru/maru_entity"}
     }
  end
end
