defmodule Delta.MixProject do
  use Mix.Project

  @app :delta
  @name "Delta"
  @version "0.1.1"
  @github "https://github.com/slab/delta-elixir"

  def project do
    [
      # Project
      app: @app,
      version: @version,
      elixir: "~> 1.10",
      description: description(),
      package: package(),
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),

      # ExDoc
      name: @name,
      docs: [
        extras: [
          "LICENSE.md": [title: "License"],
          "README.md": [title: "Overview"],
        ],
        main: "readme",
        homepage_url: @github,
        canonical: "https://hexdocs.pm/#{@app}",
        source_url: @github,
        source_ref: "#{@version}",
        formatters: ["html"]
      ]
    ]
  end

  defp description do
  end

  # BEAM Application
  def application do
    [
      env: [custom_embeds: []],
      extra_applications: [:logger]
    ]
  end

  # Dependencies
  defp deps do
    [{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}]
  end

  # Compilation Paths
  defp elixirc_paths(:dev), do: elixirc_paths(:test)
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Package Information
  defp package do
    [
      name: @app,
      description: "Simple, yet expressive format to describe contents and changes",
      maintainers: ["Jason Chen", "Sheharyar Naseer"],
      licenses: ["MIT"],
      files: ~w(mix.exs lib README.md),
      links: %{
        "Github" => @github,
        "Delta.js" => "https://github.com/quilljs/delta"
      }
    ]
  end
end
