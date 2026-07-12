defmodule ClothFitCli.Workers.ClothFitWorker do
  alias ClothFitCli.Config
  require Logger

  def perform(%{
    garment: garment,
    avatar: avatar,
    save_folder: save_folder,
    forward_convention: forward_convention,
    up_convention: up_convention,
    skeleton_correspond: skeleton_correspond
  }) do
    # Get configuration values
    cloth_fit_root = Config.get("cloth_fit_root", "/home/fire/Developer/cloth-fit")
    max_threads = Config.get("max_threads", 16)

    # Define paths
    garment_data_dir = Path.join([cloth_fit_root, "garment-data", garment])
    polyfem_bin_relative_path = Path.join(["..", "..", "build", "PolyFEM_bin"])
    base_setup_json_path = Path.join([garment_data_dir, "setup.json"])

    # Read the base setup.json
    case File.read(base_setup_json_path) do
      {:ok, json_content} ->
        case Jason.decode(json_content) do
          {:ok, setup_config} ->
            # Modify the setup configuration with CLI parameters
            updated_config = update_setup_config(setup_config, avatar, save_folder, forward_convention, up_convention, skeleton_correspond, max_threads)

            # Write the updated config to a temporary file
            temp_setup_path = Path.join([garment_data_dir, "temp_setup.json"])
            case Jason.encode(updated_config, pretty: true) do
              {:ok, updated_json} ->
                case File.write(temp_setup_path, updated_json) do
                  :ok ->
                    # Execute PolyFEM_bin with the temporary setup file
                    command_args = ["-j", "temp_setup.json"]
                    execute_polyfem(polyfem_bin_relative_path, command_args, garment_data_dir, garment, temp_setup_path)

                  {:error, reason} ->
                    Logger.error("Failed to write temporary setup.json: #{reason}")
                    {:error, "Failed to write temporary setup.json"}
                end

              {:error, reason} ->
                Logger.error("Failed to encode updated setup.json: #{reason}")
                {:error, "Failed to encode updated setup.json"}
            end

          {:error, reason} ->
            Logger.error("Failed to decode setup.json: #{reason}")
            {:error, "Failed to decode setup.json"}
        end

      {:error, reason} ->
        Logger.error("Failed to read setup.json from #{base_setup_json_path}: #{reason}")
        {:error, "Failed to read setup.json"}
    end
  end

  defp update_setup_config(config, avatar, save_folder, forward_convention, up_convention, skeleton_correspond, max_threads) do
    # Update avatar-related paths
    avatar_mesh_path = "../assets/avatars/#{avatar}/avatar.obj"
    target_skeleton_path = "../assets/avatars/#{avatar}/skeleton.obj"

    # Add output folder to the output section
    output_config = Map.get(config, "output", %{})
    updated_output = Map.put(output_config, "folder", save_folder)

    # Update solver configuration with max_threads
    solver_config = Map.get(config, "solver", %{})
    updated_solver = Map.put(solver_config, "max_threads", max_threads)

    # Update the configuration
    config
    |> Map.put("avatar_mesh_path", avatar_mesh_path)
    |> Map.put("target_skeleton_path", target_skeleton_path)
    |> Map.put("output", updated_output)
    |> Map.put("solver", updated_solver)
    |> Map.put("forward_convention", forward_convention)
    |> Map.put("up_convention", up_convention)
    |> Map.put("skeleton_correspond", skeleton_correspond)
  end

  defp execute_polyfem(polyfem_bin_path, command_args, working_dir, garment, temp_setup_path) do
    result = case System.cmd(polyfem_bin_path, command_args, cd: working_dir) do
      {output, 0} ->
        Logger.info("Cloth-fit job completed successfully for garment: #{garment}")
        Logger.info("Output: #{output}")
        :ok
      {output, exit_code} ->
        Logger.error("Cloth-fit job failed for garment: #{garment}, exit code: #{exit_code}")
        Logger.error("Output: #{output}")
        {:error, "Cloth-fit job failed"}
    end

    # Clean up the temporary setup file
    case File.rm(temp_setup_path) do
      :ok ->
        Logger.debug("Temporary setup file cleaned up: #{temp_setup_path}")
      {:error, reason} ->
        Logger.warning("Failed to clean up temporary setup file #{temp_setup_path}: #{reason}")
    end

    result
  end
end
