defmodule Delta.MixProject do
  use Mix.Project

  @app :delta
  @name "Delta"
  @version "0.4.1"
  @github "https://github.com/slab/delta-elixir"

  def project do
    [
      app: @app,
      version: @version,
      elixir: "~> 1.18",
      description: description(),
      package: package(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      name: @name,
      docs: [
        main: @name,
        source_url: @github,
        homepage_url: @github,
        canonical: "https://hexdocs.pm/#{@app}",
        extras: ["README.md", "CHANGELOG.md"]
      ]
    ]
  end

  defp description do
    "Simple, yet expressive format to describe contents and changes"
  end

  def application do
    [
      env: [custom_embeds: []],
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:diff_match_patch, "~> 0.2"},
      {:diffy, "~> 1.1"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:dev), do: elixirc_paths(:test)
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      name: @app,
      maintainers: ["Slab"],
      licenses: ["BSD-3-Clause"],
      files: ~w(mix.exs lib README.md CHANGELOG.md),
      links: %{
        "Github" => @github,
        "Delta.js" => "https://github.com/slab/delta",
        "Changelog" => "https://hexdocs.pm/delta/changelog.html"
      }
    ]
  end
end
