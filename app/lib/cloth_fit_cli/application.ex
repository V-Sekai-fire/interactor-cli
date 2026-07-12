defmodule ClothFitCli.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ClothFitCli.Worker.start_link(arg)
      # {ClothFitCli.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ClothFitCli.Supervisor]
    {:ok, sup} = Supervisor.start_link(children, opts)

    # When packaged as a Burrito release, run the CLI and halt. Under `mix`
    # (dev/test) RELEASE_ROOT is unset, so we stay a normal OTP application.
    if running_as_release?() do
      argv = Burrito.Util.Args.argv()
      exit_code = ClothFitCli.CLI.Runner.run(argv)
      System.halt(exit_code)
    end

    {:ok, sup}
  end

  defp running_as_release?, do: System.get_env("RELEASE_ROOT") not in [nil, ""]
end
