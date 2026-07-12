defmodule ClothFitCli.CLI do
  alias ClothFitCli.Workers.ClothFitWorker
  alias ClothFitCli.Config
  require Logger

  @doc """
  Runs the cloth-fit process.

  Usage: mix run --eval "ClothFitCli.CLI.main(garment: \"jumpsuit_dense\", avatar: \"FoxGirl\", save_folder: \"output\", forward_convention: \"+Z\", up_convention: \"+Y\", skeleton_correspond: true)"
  """
  def main(opts) do
    # Merge command-line options with configuration defaults
    case Config.merge_with_opts(opts) do
      {:ok, merged_opts} ->
        garment = merged_opts.garment
        avatar = merged_opts.avatar
        save_folder = merged_opts.save_folder
        forward_convention = merged_opts.forward_convention
        up_convention = merged_opts.up_convention
        skeleton_correspond = merged_opts.skeleton_correspond

        # Input Validation
        case validate_inputs(garment, avatar, save_folder, forward_convention, up_convention, skeleton_correspond) do
          :ok ->
            Logger.info("Inputs validated successfully. Starting job...")
            # Execute the job directly
            case ClothFitWorker.perform(%{
              garment: garment,
              avatar: avatar,
              save_folder: save_folder,
              forward_convention: forward_convention,
              up_convention: up_convention,
              skeleton_correspond: skeleton_correspond
            }) do
              :ok ->
                Logger.info("Job completed successfully.")
              {:error, reason} ->
                Logger.error("Job failed: #{reason}")
                System.halt(1)
            end

          {:error, message} ->
            Logger.error("Input validation failed: #{message}")
            System.halt(1)
        end

    end
  end

  @doc """
  Lists available garments and avatars.

  Usage: mix run --eval "ClothFitCli.CLI.list_assets()"
  """
  def list_assets do
    cloth_fit_root = "/home/fire/Developer/cloth-fit"
    garments_path = Path.join([cloth_fit_root, "garment-data", "assets", "garments"])
    avatars_path = Path.join([cloth_fit_root, "garment-data", "assets", "avatars"])

    Logger.info("Available Garments:")
    case File.ls(garments_path) do
      {:ok, garments} ->
        if Enum.empty?(garments) do
          Logger.warning("  No garments found in #{garments_path}")
        else
          Enum.each(garments, fn garment ->
            Logger.info("  - #{garment}")
          end)
        end
      {:error, :enoent} ->
        Logger.error("Garments directory not found: #{garments_path}")
        Logger.info("Please ensure the cloth-fit project structure is correct.")
      {:error, reason} ->
        Logger.error("Failed to list garments: #{reason}")
    end

    Logger.info("Available Avatars:")
    case File.ls(avatars_path) do
      {:ok, avatars} ->
        if Enum.empty?(avatars) do
          Logger.warning("  No avatars found in #{avatars_path}")
        else
          Enum.each(avatars, fn avatar ->
            Logger.info("  - #{avatar}")
          end)
        end
      {:error, :enoent} ->
        Logger.error("Avatars directory not found: #{avatars_path}")
        Logger.info("Please ensure the cloth-fit project structure is correct.")
      {:error, reason} ->
        Logger.error("Failed to list avatars: #{reason}")
    end
  end

  @doc """
  Lists current simulation jobs in the queue.

  Usage: mix run --eval "ClothFitCli.CLI.list_jobs()"
  """
  def list_jobs do
    Logger.info("Job queue functionality has been removed.")
    Logger.info("Jobs are now executed directly without queueing.")
  end

  @doc """
  Views simulation results from a specified output folder.

  Usage: mix run --eval "ClothFitCli.CLI.view_results(\"output_folder_name\")"
  """
  def view_results(output_folder) when is_binary(output_folder) do
    cloth_fit_root = "/home/fire/Developer/cloth-fit"
    results_path = Path.join([cloth_fit_root, output_folder])

    Logger.info("Simulation Results in: #{results_path}")

    case File.exists?(results_path) do
      true ->
        case File.ls(results_path) do
          {:ok, files} ->
            if Enum.empty?(files) do
              Logger.info("  No files found in results directory.")
            else
              Logger.info("  Files:")
              Enum.each(files, fn file ->
                file_path = Path.join([results_path, file])
                case File.stat(file_path) do
                  {:ok, %File.Stat{size: size, mtime: mtime}} ->
                    Logger.info("    - #{file} (#{size} bytes, modified: #{inspect(mtime)})")
                  {:error, _} ->
                    Logger.info("    - #{file}")
                end
              end)
            end
          {:error, reason} ->
            Logger.error("Failed to list files in results directory: #{reason}")
        end
      false ->
        Logger.warning("Results directory does not exist: #{results_path}")
    end
  end

  def view_results(_) do
    Logger.error("Output folder must be a string.")
  end

  @doc """
  Shows current configuration.

  Usage: mix run --eval "ClothFitCli.CLI.show_config()"
  """
  def show_config do
    Config.show_config()
  end

  @doc """
  Initializes a new configuration file with defaults.

  Usage: mix run --eval "ClothFitCli.CLI.init_config()"
  """
  def init_config do
    Config.init_config()
  end

  @doc """
  Sets a configuration value.

  Usage: mix run --eval "ClothFitCli.CLI.set_config(\"default_forward_convention\", \"+X\")"
  """
  def set_config(key, value) do
    case Config.set(key, value) do
      :ok ->
        Logger.info("Configuration updated: #{key} = #{inspect(value)}")
      {:error, reason} ->
        Logger.error("Failed to update configuration: #{reason}")
    end
  end

  @doc """
  Gets a configuration value.

  Usage: mix run --eval "ClothFitCli.CLI.get_config(\"default_forward_convention\")"
  """
  def get_config(key) do
    value = Config.get(key)
    Logger.info("#{key}: #{inspect(value)}")
    value
  end

  @doc """
  Lists all available simulation results directories.

  Usage: mix run --eval "ClothFitCli.CLI.list_results()"
  """
  def list_results do
    cloth_fit_root = "/home/fire/Developer/cloth-fit"

    # Common output directory patterns to check
    potential_dirs = [
      "output",
      "results",
      "garment-data"
    ]

    Logger.info("Available Results Directories:")

    Enum.each(potential_dirs, fn dir ->
      dir_path = Path.join([cloth_fit_root, dir])
      case File.exists?(dir_path) and File.dir?(dir_path) do
        true ->
          case File.ls(dir_path) do
            {:ok, subdirs} ->
              subdirs
              |> Enum.filter(fn subdir ->
                subdir_path = Path.join([dir_path, subdir])
                File.dir?(subdir_path)
              end)
              |> case do
                [] -> :ok
                dirs ->
                  Logger.info("  #{dir}/:")
                  Enum.each(dirs, fn subdir ->
                    Logger.info("    - #{subdir}")
                  end)
              end
            {:error, _} -> :ok
          end
        false -> :ok
      end
    end)
  end

  defp validate_inputs(garment, avatar, save_folder, forward_convention, up_convention, skeleton_correspond) do
    cloth_fit_root = "/home/fire/Developer/cloth-fit"

    cond do
      is_nil(garment) or garment == "" ->
        {:error, "Garment cannot be empty. Use ClothFitCli.CLI.list_assets() to see available garments."}

      is_nil(avatar) or avatar == "" ->
        {:error, "Avatar cannot be empty. Use ClothFitCli.CLI.list_assets() to see available avatars."}

      is_nil(save_folder) or save_folder == "" ->
        {:error, "Save folder cannot be empty. Specify a directory name for output files."}

      not Enum.member?(["+X", "-X", "+Y", "-Y", "+Z", "-Z"], forward_convention) ->
        {:error, "Invalid forward convention '#{forward_convention}'. Must be one of: +X, -X, +Y, -Y, +Z, -Z"}

      not Enum.member?(["+X", "-X", "+Y", "-Y", "+Z", "-Z"], up_convention) ->
        {:error, "Invalid up convention '#{up_convention}'. Must be one of: +X, -X, +Y, -Y, +Z, -Z"}

      not is_boolean(skeleton_correspond) ->
        {:error, "Skeleton correspond must be a boolean (true or false), got: #{inspect(skeleton_correspond)}"}

      forward_convention == up_convention ->
        {:error, "Forward convention and up convention cannot be the same. Got both: #{forward_convention}"}

      true ->
        # Additional validation: check if garment and avatar exist
        garment_path = Path.join([cloth_fit_root, "garment-data", garment, "setup.json"])
        avatar_garments_path = Path.join([cloth_fit_root, "garment-data", "assets", "avatars", avatar])

        cond do
          not File.exists?(garment_path) ->
            {:error, "Garment '#{garment}' not found. Expected setup.json at: #{garment_path}"}

          not File.exists?(avatar_garments_path) ->
            {:error, "Avatar '#{avatar}' not found. Expected directory at: #{avatar_garments_path}"}

          true -> :ok
        end
    end
  end
end
