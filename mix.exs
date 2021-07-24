defmodule Delta.MixProject do
  use Mix.Project


  @app     :delta
  @name    "Delta"
  @version "0.1.0"
  @github  "https://github.com/slab/#{@app}"


  def project do
    [
      # Project
      app:            @app,
      version:        @version,
      elixir:         "~> 1.9",
      description:    description(),
      package:        package(),
      deps:           deps(),
      elixirc_paths:  elixirc_paths(Mix.env()),

      # ExDoc
      name:           @name,
      docs: [
        main:         @name,
        source_url:   @github,
        homepage_url: @github,
        canonical:    "https://hexdocs.pm/#{@app}",
        extras:       ["README.md"]
      ]
    ]
  end


  defp description do
    "Simple, yet expressive format to describe contents and changes"
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
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end


  # Compilation Paths
  defp elixirc_paths(:dev),  do: elixirc_paths(:test)
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]


  # Package Information
  defp package do
    [
      name: @app,
      maintainers: ["Jason Chen", "Sheharyar Naseer"],
      licenses: ["MIT"],
      files: ~w(mix.exs lib README.md),
      links: %{"Github" => @github}
    ]
  end
end
