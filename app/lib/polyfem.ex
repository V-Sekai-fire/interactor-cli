defmodule PolyFem do
  @moduledoc """
  Low-level NIF loader for the PolyFEM garment-retargeting engine.

  The native library is implemented in C++ against the
  [Fine](https://github.com/elixir-nx/fine) NIF API and compiled by
  `elixir_make` into `priv/polyfem`. Each function below is a stub that is
  replaced by the native implementation once the NIF is loaded; if loading
  fails the stub raises so the failure is obvious.

  All functions return `{:ok, result}` or `{:error, reason}`.
  """

  @on_load :load_nif

  @doc false
  def load_nif do
    path = :filename.join(:code.priv_dir(:cloth_fit_cli), ~c"polyfem")
    :erlang.load_nif(path, 0)
  end

  @doc """
  Run a garment-retargeting simulation.

  `config` is a JSON-encoded configuration binary and `output_path` is the
  directory where result meshes are written.
  """
  def simulate(_config, _output_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Validate a garment mesh file. Returns `{:ok, boolean}`."
  def validate_garment_mesh(_mesh_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Validate an avatar mesh file. Returns `{:ok, boolean}`."
  def validate_avatar_mesh(_mesh_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Load garment metadata as a JSON string. Returns `{:ok, json}`."
  def load_garment_info(_garment_path), do: :erlang.nif_error(:nif_not_loaded)

  @doc "Load avatar metadata as a JSON string. Returns `{:ok, json}`."
  def load_avatar_info(_avatar_path), do: :erlang.nif_error(:nif_not_loaded)
end
