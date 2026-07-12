defmodule ClothFitCli.Config do
  @moduledoc """
  Configuration management for ClothFitCli.

  Handles loading, saving, and managing configuration settings for the CLI application.
  """

  require Logger

  @config_filename ".cloth_fit_cli.json"
  @default_config %{
    "cloth_fit_root" => "/home/fire/Developer/cloth-fit",
    "default_forward_convention" => "+Z",
    "default_up_convention" => "+Y",
    "default_skeleton_correspond" => true,
    "max_threads" => 16,
    "log_level" => "info"
  }

  @doc """
  Gets the configuration file path.
  Looks for config file in the current directory first, then in the user's home directory.
  """
  def config_file_path do
    local_config = Path.join([File.cwd!(), @config_filename])
    home_config = Path.join([System.user_home!(), @config_filename])

    cond do
      File.exists?(local_config) -> local_config
      File.exists?(home_config) -> home_config
      true -> home_config  # Default to home directory for new config
    end
  end

  @doc """
  Loads configuration from file, merging with defaults.
  """
  def load_config do
    config_path = config_file_path()

    case File.read(config_path) do
      {:ok, content} ->
        case Jason.decode(content) do
          {:ok, file_config} ->
            merged_config = Map.merge(@default_config, file_config)
            Logger.debug("Configuration loaded from: #{config_path}")
            {:ok, merged_config}

          {:error, reason} ->
            Logger.warning("Failed to parse config file #{config_path}: #{reason}")
            Logger.info("Using default configuration.")
            {:ok, @default_config}
        end

      {:error, :enoent} ->
        Logger.debug("No config file found at #{config_path}, using defaults.")
        {:ok, @default_config}

      {:error, reason} ->
        Logger.warning("Failed to read config file #{config_path}: #{reason}")
        Logger.info("Using default configuration.")
        {:ok, @default_config}
    end
  end

  @doc """
  Saves configuration to file.
  """
  def save_config(config) do
    config_path = config_file_path()

    case Jason.encode(config, pretty: true) do
      {:ok, json_content} ->
        case File.write(config_path, json_content) do
          :ok ->
            Logger.info("Configuration saved to: #{config_path}")
            :ok

          {:error, reason} ->
            Logger.error("Failed to save config to #{config_path}: #{reason}")
            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to encode config: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Gets a configuration value by key, with optional default.
  """
  def get(key, default \\ nil) do
    case load_config() do
      {:ok, config} -> Map.get(config, key, default)
    end
  end

  @doc """
  Sets a configuration value and saves to file.
  """
  def set(key, value) do
    case load_config() do
      {:ok, config} ->
        updated_config = Map.put(config, key, value)
        save_config(updated_config)
    end
  end

  @doc """
  Merges command-line options with configuration, giving priority to command-line args.
  """
  def merge_with_opts(opts) do
    case load_config() do
      {:ok, config} ->
        merged = %{
          garment: Keyword.get(opts, :garment),
          avatar: Keyword.get(opts, :avatar),
          save_folder: Keyword.get(opts, :save_folder),
          forward_convention: Keyword.get(opts, :forward_convention, config["default_forward_convention"]),
          up_convention: Keyword.get(opts, :up_convention, config["default_up_convention"]),
          skeleton_correspond: Keyword.get(opts, :skeleton_correspond, config["default_skeleton_correspond"]),
          cloth_fit_root: config["cloth_fit_root"],
          max_threads: config["max_threads"]
        }
        {:ok, merged}
    end
  end

  @doc """
  Shows current configuration.
  """
  def show_config do
    case load_config() do
      {:ok, config} ->
        Logger.info("Current Configuration:")
        Logger.info("  Config file: #{config_file_path()}")

        Enum.each(config, fn {key, value} ->
          Logger.info("  #{key}: #{inspect(value)}")
        end)

        :ok
    end
  end

  @doc """
  Initializes a new configuration file with defaults.
  """
  def init_config do
    config_path = config_file_path()

    if File.exists?(config_path) do
      Logger.warning("Configuration file already exists at: #{config_path}")
      Logger.info("Use 'show_config()' to view current settings.")
      {:error, :already_exists}
    else
      case save_config(@default_config) do
        :ok ->
          Logger.info("Configuration file created at: #{config_path}")
          Logger.info("Edit this file to customize your settings.")
          :ok

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Validates configuration values.
  """
  def validate_config(config) do
    errors = []

    errors = if not is_binary(config["cloth_fit_root"]) do
      ["cloth_fit_root must be a string" | errors]
    else
      errors
    end

    errors = if not Enum.member?(["+X", "-X", "+Y", "-Y", "+Z", "-Z"], config["default_forward_convention"]) do
      ["default_forward_convention must be one of: +X, -X, +Y, -Y, +Z, -Z" | errors]
    else
      errors
    end

    errors = if not Enum.member?(["+X", "-X", "+Y", "-Y", "+Z", "-Z"], config["default_up_convention"]) do
      ["default_up_convention must be one of: +X, -X, +Y, -Y, +Z, -Z" | errors]
    else
      errors
    end

    errors = if not is_boolean(config["default_skeleton_correspond"]) do
      ["default_skeleton_correspond must be a boolean" | errors]
    else
      errors
    end

    errors = if not is_integer(config["max_threads"]) or config["max_threads"] < 1 do
      ["max_threads must be a positive integer" | errors]
    else
      errors
    end

    case errors do
      [] -> :ok
      _ -> {:error, errors}
    end
  end
end
