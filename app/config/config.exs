import Config

config :cloth_fit_cli,
  ecto_repos: [ClothFitCli.Repo]

config :cloth_fit_cli, ClothFitCli.Repo,
  database: "cloth_fit.db",
  pool_size: 10

config :cloth_fit_cli, Oban,
  repo: ClothFitCli.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10],
  notifier: Oban.Notifiers.Phoenix

import_config "#{config_env()}.exs"
