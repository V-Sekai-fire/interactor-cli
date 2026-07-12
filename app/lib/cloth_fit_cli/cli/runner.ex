defmodule ClothFitCli.CLI.Runner do
  @moduledoc """
  argv dispatcher for the standalone Burrito binary.

  Invoked from `ClothFitCli.Application.start/2` when running as a packaged
  release; parses `Burrito.Util.Args.argv/0` and drives the PolyFEM NIF. Returns
  the process exit code.
  """

  alias ClothFitCli.PolyFEM

  @spec run([String.t()]) :: non_neg_integer()
  def run(["fit" | rest]), do: fit(rest)
  def run(["validate-garment", path]), do: validate(&PolyFEM.validate_garment_mesh/1, path)
  def run(["validate-avatar", path]), do: validate(&PolyFEM.validate_avatar_mesh/1, path)
  def run(["info-garment", path]), do: info(&PolyFEM.load_garment_info/1, path)
  def run(["info-avatar", path]), do: info(&PolyFEM.load_avatar_info/1, path)
  def run([v]) when v in ["--version", "-v", "version"], do: (IO.puts(version()); 0)
  def run([]), do: (usage(); 0)
  def run([h]) when h in ["--help", "-h", "help"], do: (usage(); 0)

  def run(other) do
    IO.puts(:stderr, "cloth_fit: unknown command: #{Enum.join(other, " ")}\n")
    usage()
    2
  end

  defp fit(args) do
    {opts, _rest, _invalid} =
      OptionParser.parse(args,
        strict: [setup: :string, out: :string],
        aliases: [s: :setup, o: :out]
      )

    setup = opts[:setup]
    out = opts[:out] || "output"

    cond do
      is_nil(setup) ->
        IO.puts(:stderr, "fit: --setup <setup.json> is required")
        2

      not File.exists?(setup) ->
        IO.puts(:stderr, "fit: setup file not found: #{setup}")
        1

      true ->
        case PolyFEM.simulate_from_setup(setup, out) do
          {:ok, result} ->
            IO.puts(result)
            0

          {:error, reason} ->
            IO.puts(:stderr, "fit failed: #{reason}")
            1
        end
    end
  end

  defp validate(fun, path) do
    case fun.(path) do
      {:ok, true} -> (IO.puts("valid"); 0)
      {:ok, false} -> (IO.puts("invalid"); 1)
      {:error, reason} -> (IO.puts(:stderr, reason); 1)
    end
  end

  defp info(fun, path) do
    case fun.(path) do
      {:ok, info} when is_map(info) -> (IO.puts(Jason.encode!(info)); 0)
      {:ok, info} -> (IO.puts(info); 0)
      {:error, reason} -> (IO.puts(:stderr, reason); 1)
    end
  end

  defp version do
    vsn = Application.spec(:cloth_fit_cli, :vsn) || ~c""
    "cloth_fit_cli #{vsn}"
  end

  defp usage do
    IO.puts("""
    cloth_fit — intersection-free garment retargeting (PolyFEM)

    USAGE:
        cloth_fit <command> [options]

    COMMANDS:
        fit --setup <setup.json> [--out <dir>]   Run a garment retarget (default out: ./output)
        validate-garment <mesh.obj>              Validate a garment mesh
        validate-avatar <mesh.obj>               Validate an avatar mesh
        info-garment <mesh.obj>                  Print garment mesh metadata (JSON)
        info-avatar <mesh.obj>                   Print avatar mesh metadata (JSON)
        version                                  Print version
        help                                     Show this help

    Mesh paths inside setup.json are resolved relative to the current directory.
    """)
  end
end
