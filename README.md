# weftfit/cli

The **driving adapter** for weftfit: an Elixir CLI (`fit` / `validate-*` /
`info-*` / `version`) that drives the `retarget` core through the mesh ports and
ships as a single self-contained **Burrito** binary — no runtime toolchain.

- **`app/`** — the mix project. The solver is exposed as a **Fine NIF**
  (`c_src/cloth_fit_cli/polyfem.cpp`), packaged per-target with Burrito;
  `mix cloth_fit.build_native` builds the static PolyFEM + NIF; with
  `CLOTH_FIT_WITH_USD=1` it bundles the **weftfit/stage** adapter (`cloth_fit_usd`
  bridge + `usd_ms` + plugins) into `priv/`.
- **`ports/`** — the port contracts it composes.

Wiring (hexagonal): `cli` selects a **source** adapter (OBJ or OpenUSD) to read
the garment/avatar/skeletons, runs the **retarget** core, and fans the per-step
output to one or more **sink** adapters (OBJ, OpenUSD, later viewer) in one pass.

## Migration status (from `cloth-fit`)

`app/` is lifted from `V-Sekai-fire/cloth-fit/cloth_fit_cli`. Remaining: point the
NIF/build at the sibling `weftfit/{retarget,stage,obj}` repos instead of the
in-tree `src/` (currently the monolith still provides the C++ solver + adapters).
