#ifndef WEFTFIT_PORT_MESH_SOURCE_H
#define WEFTFIT_PORT_MESH_SOURCE_H
// Driving (input) SOURCE port: an adapter that reads meshes for the retarget core.
// One core, many source adapters (obj, stage/OpenUSD, recorded fixtures). A C-ABI
// struct of function pointers so any language can implement it.
#include <stdint.h>
#include "mesh.h"
#ifdef __cplusplus
extern "C" {
#endif
typedef struct wf_mesh_source {
    void *ctx;
    // Read the resource at `uri` (file path or stage prim). Returns a wf_mesh the
    // caller releases via `release`; NULL on failure (see last_error).
    wf_mesh *(*read)(void *ctx, const char *uri);
    void (*release)(void *ctx, wf_mesh *mesh);
    const char *(*last_error)(void *ctx);
} wf_mesh_source;
#ifdef __cplusplus
}
#endif
#endif
