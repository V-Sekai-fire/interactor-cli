defmodule ClothFitCli.MixProject do
  use Mix.Project

  def project do
    [
      app: :cloth_fit_cli,
      # dev stage per the release-tag progression convention (dev→beta→rc→release);
      # 0.1.0 has not been released. Unpadded counter starting at 1.
      version: "0.1.0-dev.2",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      compilers: compilers(),
      make_env: &make_env/0,
      make_executable: make_executable(),
      releases: releases(),
      aliases: aliases()
    ]
  end

  # elixir_make builds the NIF, but only once its PolyFEM libraries exist. On a
  # fresh checkout `polyfem_link.rsp` is absent, so elixir_make is skipped and
  # `mix cloth_fit.build_native` can compile the project, build the libs, and
  # then build the NIF itself in one step. Afterwards the file exists and plain
  # `mix compile` rebuilds the NIF incrementally. CLOTH_FIT_SKIP_MAKE=1 forces a
  # skip (used when a cross-target Burrito release injects a prebuilt NIF).
  defp compilers do
    if not skip_make?() and File.exists?(Path.join(__DIR__, "c_src/polyfem_link.rsp")),
      do: [:elixir_make] ++ Mix.compilers(),
      else: Mix.compilers()
  end

  defp skip_make?, do: System.get_env("CLOTH_FIT_SKIP_MAKE") in ~w(1 true)

  # One release per platform so each bundles the correct pre-built native lib
  # (priv/polyfem.so or .dll). Burrito hosts on Linux/macOS and cross-builds the
  # self-extracting wrapper per target with Zig; the NIF is placed into priv
  # before wrapping (see scripts/build_burrito_*.sh).
  defp releases do
    wrap = [steps: [:assemble, &Burrito.wrap/1]]

    [
      # Linux: built natively on a Linux host, so Burrito uses the .so that
      # elixir_make compiled during assemble. Burrito's default Linux ERTS is
      # musl; our NIF is glibc, so point custom_erts at the host (glibc) OTP.
      cloth_fit_linux:
        wrap ++
          [burrito: [targets: [linux: [os: :linux, cpu: :x86_64, custom_erts: to_string(:code.root_dir())]]]],
      # Windows: cross-built from a Linux host. skip_nifs stops Burrito from
      # trying to recompile the NIF for Windows; the pre-built self-contained
      # priv/polyfem.dll is injected before wrapping.
      cloth_fit_windows:
        wrap ++
          [burrito: [targets: [windows: [os: :windows, cpu: :x86_64, skip_nifs: true]]]]
    ]
  end

  # The Makefile uses GNU make syntax. On Windows elixir_make defaults to
  # `nmake`, so point it at the mingw GNU make; elsewhere use the default.
  defp make_executable do
    case :os.type() do
      {:win32, _} -> "mingw32-make"
      _ -> :default
    end
  end

  # Environment passed to the Makefile by elixir_make.
  # FINE_INCLUDE_DIR is required by Fine; ERTS_INCLUDE_DIR is provided by
  # elixir_make automatically, but we surface it here for clarity.
  # The NIF links libpolyfem + the cloth_fit_usd_stub (via polyfem_link.rsp) and
  # dlopens the USD bridge at runtime — no usd_ms on its link line — so no USD env
  # is needed here.
  defp make_env do
    %{"FINE_INCLUDE_DIR" => Fine.include_dir()}
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ClothFitCli.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:fine, "~> 0.1", runtime: false},
      {:elixir_make, "~> 0.8", runtime: false},
      # Prebuilt OpenUSD runtime (monolithic usd_ms + headers), fetched per
      # triplet from Hex instead of compiling USD from source (~40+ min). The NIF
      # links against StageRuntime.include_dir/0 and lib_dir/0.
      {:stage_runtime, "~> 0.1.0-dev"},
      {:burrito, "~> 1.3"},
      {:jason, "~> 1.4"},
      {:igniter, "~> 0.6", only: [:dev, :test]}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"],
      test: ["test"]
    ]
  end
end
