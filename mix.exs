defmodule MaruEntity.Mixfile do
  use Mix.Project

  def project do
    [
      app: :maru_entity,
      version: "0.2.4",
      elixir: "~> 1.12",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: "Parallelizable serializer inspired by grape-entity.",
      source_url: "https://github.com/elixir-maru/maru_entity",
      package: package(),
      test_coverage: [tool: ExCoveralls],
      docs: [
        extras: ["README.md"],
        main: "readme"
      ]
    ]
  end

  def application do
    [
      extra_applications: [:logger, :runtime_tools, :public_key, :ssl]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :docs}
    ]
  end

  defp package do
    %{
      maintainers: ["Xiangrong Hao", "Teodor Pripoae"],
      licenses: ["Apache-2.0"],
      links: %{"Github" => "https://github.com/elixir-maru/maru_entity"}
    }
  end
end
