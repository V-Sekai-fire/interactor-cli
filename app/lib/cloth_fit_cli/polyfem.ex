defmodule ClothFitCli.PolyFEM do
  @moduledoc """
  Elixir interface to the PolyFEM simulation engine via Unifex NIFs.

  This module provides high-level functions for:
  - Running cloth fitting simulations
  - Validating mesh files
  - Loading garment and avatar information
  """

  @doc """
  Run a cloth fitting simulation with the given configuration.

  ## Parameters
  - `config`: A map containing simulation parameters
  - `output_path`: Directory where simulation results will be saved

  ## Returns
  - `{:ok, result}` on success
  - `{:error, reason}` on failure
  """
  def simulate(config, output_path) when is_map(config) and is_binary(output_path) do
    # When built with USD, the NIF self-locates the cloth_fit_usd bridge next to
    # itself (dladdr / import lib) and the plugin registry in priv/usd — no env
    # handoff needed. See src/usd_bridge/{loader,cloth_fit_usd}.cpp.
    config_payload = Jason.encode!(config)
    PolyFem.simulate(config_payload, output_path)
  end

  @doc """
  Validate a garment mesh file.

  ## Parameters
  - `mesh_path`: Path to the garment mesh file (.obj)

  ## Returns
  - `{:ok, true}` if mesh is valid
  - `{:ok, false}` if mesh is invalid
  - `{:error, reason}` on failure
  """
  def validate_garment_mesh(mesh_path) when is_binary(mesh_path) do
    PolyFem.validate_garment_mesh(mesh_path)
  end

  @doc """
  Validate an avatar mesh file.

  ## Parameters
  - `mesh_path`: Path to the avatar mesh file (.obj)

  ## Returns
  - `{:ok, true}` if mesh is valid
  - `{:ok, false}` if mesh is invalid
  - `{:error, reason}` on failure
  """
  def validate_avatar_mesh(mesh_path) when is_binary(mesh_path) do
    PolyFem.validate_avatar_mesh(mesh_path)
  end

  @doc """
  Load garment information and metadata.

  ## Parameters
  - `garment_path`: Path to the garment directory or file

  ## Returns
  - `{:ok, info}` containing garment metadata
  - `{:error, reason}` on failure
  """
  def load_garment_info(garment_path) when is_binary(garment_path) do
    case PolyFem.load_garment_info(garment_path) do
      {:ok, payload} ->
        try do
          # Parse JSON payload from C++
          json_string = payload
          info = Jason.decode!(json_string)
          {:ok, info}
        rescue
          Jason.DecodeError -> {:error, "Failed to parse garment info payload"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Load avatar information and metadata.

  ## Parameters
  - `avatar_path`: Path to the avatar directory or file

  ## Returns
  - `{:ok, info}` containing avatar metadata
  - `{:error, reason}` on failure
  """
  def load_avatar_info(avatar_path) when is_binary(avatar_path) do
    case PolyFem.load_avatar_info(avatar_path) do
      {:ok, payload} ->
        try do
          # Parse JSON payload from C++
          json_string = payload
          info = Jason.decode!(json_string)
          {:ok, info}
        rescue
          Jason.DecodeError -> {:error, "Failed to parse avatar info payload"}
        end
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Run a simulation using a setup.json configuration file.

  This is a convenience function that loads a setup.json file and runs the simulation.

  ## Parameters
  - `setup_path`: Path to the setup.json file
  - `output_path`: Directory where simulation results will be saved

  ## Returns
  - `{:ok, result}` on success
  - `{:error, reason}` on failure
  """
  def simulate_from_setup(setup_path, output_path) when is_binary(setup_path) and is_binary(output_path) do
    with {:ok, content} <- File.read(setup_path),
         {:ok, config} <- Jason.decode(content) do
      simulate(config, output_path)
    else
      {:error, reason} -> {:error, "Failed to load setup file: #{reason}"}
    end
  end
end
