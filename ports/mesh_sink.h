#ifndef WEFTFIT_PORT_MESH_SINK_H
#define WEFTFIT_PORT_MESH_SINK_H
// Driven (output) SINK port: an adapter that writes the core's per-step meshes to
// a destination. One core output fans out to several sinks from one pass (obj +
// stage/OpenUSD + viewer). A C-ABI struct of function pointers.
#include <stdint.h>
#include "mesh.h"
#ifdef __cplusplus
extern "C" {
#endif
typedef struct wf_mesh_sink {
    void *ctx;
    // Write `mesh` to `uri` in the sink's format. Returns 0 on success.
    int32_t (*write)(void *ctx, const char *uri, const wf_mesh *mesh);
    const char *(*last_error)(void *ctx);
} wf_mesh_sink;
#ifdef __cplusplus
}
#endif
#endif
