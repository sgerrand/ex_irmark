defmodule IRmark.MixProject do
  use Mix.Project

  def project do
    [
      app: :irmark,
      version: "0.0.0-dev",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:crypto, :xmerl, :logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:xmerl_c14n, "~> 0.2.0"}
    ]
  end
end
