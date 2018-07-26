defmodule VayneMetricHttp.MixProject do
  use Mix.Project

  def project do
    [
      app: :vayne_metric_http,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:httpotion, "~> 3.1"},
      {:vayne, github: "mon-suit/vayne_core", only: [:dev, :test], runtime: false},
      {:credo, "~> 0.9", only: [:dev, :test], runtime: false}
    ]
  end
end
