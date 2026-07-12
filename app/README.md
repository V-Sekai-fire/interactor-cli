<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

- [ClothFitCli](#clothfitcli)
  - [Installation](#installation)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# ClothFitCli

Elixir interface to the PolyFEM garment-retargeting engine. The native bridge is
a C++ NIF built with [Fine](https://github.com/elixir-nx/fine) and compiled by
[`elixir_make`](https://github.com/elixir-lang/elixir_make) (`c_src/cloth_fit_cli/polyfem.cpp`,
`Makefile`). The `PolyFem` module loads the NIF; `ClothFitCli.PolyFEM` is the
high-level API (`simulate/2`, `validate_*_mesh/1`, `load_*_info/1`).

## Building the native NIF

The NIF links against PolyFEM's static libraries. A single portable Mix task
builds everything in one step — a static oneTBB, PolyFEM (with the dependency
options needed to build on every platform), the NIF flag files, and the NIF
itself. It works on Windows (llvm-mingw), Linux and macOS:

```sh
cd cloth_fit_cli
mix deps.get
mix cloth_fit.build_native   # builds PolyFEM libs + the NIF, in one step
```

`elixir_make` is skipped until the libraries exist, so the task can compile the
project, build the libs, and build the NIF in the same invocation; afterwards a
plain `mix compile` rebuilds the NIF incrementally. The task writes
`c_src/polyfem_defines.rsp` (`-D` defines) and `c_src/polyfem_link.rsp` (the
static libraries), and the Makefile also consumes CMake's own `includes_CXX.rsp`,
so no paths or lib names are hardcoded. Override `POLYFEM_BUILD_DIR` if the CMake
build tree is not at the default (`../build`).

## Standalone binary (Burrito)

The app is packaged as a self-extracting [Burrito](https://github.com/burrito-elixir/burrito)
binary exposing the `cloth_fit` CLI (`fit`, `validate-*`, `info-*`). Burrito
hosts on Linux/macOS (or WSL) and cross-builds per target; see
`.github/workflows/nif.yml` for the reproducible Linux and Windows builds.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cloth_fit_cli` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cloth_fit_cli, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/cloth_fit_cli>.
