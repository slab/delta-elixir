defmodule Delta.MixProject do
  use Mix.Project


  @app     :delta
  @name    "Delta"
  @version "0.3.0"
  @github  "https://github.com/slab/delta-elixir"


  def project do
    [
      # Project
      app:            @app,
      version:        @version,
      elixir:         "~> 1.13",
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
    [{:ex_doc, ">= 0.0.0", only: :dev, runtime: false}]
  end


  # Compilation Paths
  defp elixirc_paths(:dev),  do: elixirc_paths(:test)
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]


  # Package Information
  defp package do
    [
      name: @app,
      maintainers: ["Slab"],
      licenses: ["BSD-3-Clause"],
      files: ~w(mix.exs lib README.md),
      links: %{
        "Github" => @github,
        "Delta.js" => "https://github.com/quilljs/delta"
      }
    ]
  end
end
