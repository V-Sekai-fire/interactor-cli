#ifndef WEFTFIT_PORT_MESH_H
#define WEFTFIT_PORT_MESH_H
// Mesh payload crossing the weftfit port boundary. Positions are in the canonical
// Godot frame (+Y up, +Z front, right-handed, metric). Faces are polygonal (ngons
// permitted); UVs / normals / per-face groups are optional. This is the lowest
// common denominator every binding language can implement: a plain C ABI.
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct wf_mesh wf_mesh; // opaque; owned by whoever created it

wf_mesh *wf_mesh_create(void);
void     wf_mesh_destroy(wf_mesh *m);

void     wf_mesh_set_positions(wf_mesh *m, int32_t vertex_count, const double *xyz /*3*n*/);
void     wf_mesh_set_faces(wf_mesh *m, int32_t face_count,
                           const int32_t *face_vertex_counts /*face_count*/,
                           int32_t index_count, const int32_t *face_vertex_indices);

int32_t  wf_mesh_vertex_count(const wf_mesh *m);
void     wf_mesh_positions(const wf_mesh *m, double *xyz_out /*3*n*/);
int32_t  wf_mesh_face_count(const wf_mesh *m);
int32_t  wf_mesh_index_count(const wf_mesh *m);
void     wf_mesh_face_vertex_counts(const wf_mesh *m, int32_t *out /*face_count*/);
void     wf_mesh_face_vertex_indices(const wf_mesh *m, int32_t *out /*index_count*/);
#ifdef __cplusplus
}
#endif
#endif
