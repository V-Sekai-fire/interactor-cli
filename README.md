# interactor-cli

A command-line driver that fits a garment mesh onto an avatar with a finite-element solver, packaged as one self-contained binary.

## What it is for

It is weftfit's driving adapter. It reads the garment, avatar and skeletons through a mesh source adapter, runs the retarget core, and writes each step through one or more mesh sink adapters. The solver runs as a C++ NIF.

## Build and run

```sh
cd app
mix deps.get
mix cloth_fit.build_native
```

The last task builds the solver's static libraries and the NIF in one step. It configures the solver from the CMake project at the root of the `cloth-fit` checkout, which still provides the C++ solver, so the native build runs only from there.

## Licence

MIT; see LICENSE.
