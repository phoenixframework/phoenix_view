defmodule PhoenixView.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_view,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:eex],
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.0", optional: true},
      {:phoenix_html, "~> 2.14.2 or ~> 2.15"},
      {:ex_doc, "~> 0.22", only: :docs},
    ]
  end

  defp package do
    [
      maintainers: ["Chris McCord", "José Valim", "Gary Rennie"],
      licenses: ["MIT"],
      links: %{github: "https://github.com/phoenixframework/phoenix_view"},
      files:
      ~w(lib mix.exs .formatter.exs)
    ]
  end
end
