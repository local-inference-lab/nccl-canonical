# CUDA 13.4 SM120 NCCL release

Status: **research-only**

The release workflow compiles NCCL 2.31.2 from the source commit on
`canonical/cu134-nccl2312-amd-turin`. It emits the same compiled library in two
formats:

- `local-inference-nccl-cu134`, a platform wheel containing the shared library,
  headers, source identity, and a path-discovery command;
- a native prefix under `native/nccl` for Docker and non-Python consumers.

The wheel makes the native payload downloadable and hash-addressable through
`uv`; it does not load NCCL into a process automatically. A serving launcher
must resolve `local-inference-nccl-path` and set `LD_PRELOAD` plus
`VLLM_NCCL_SO_PATH` before importing Torch. `nccl4py` remains a separate Python
binding and does not replace the NCCL runtime.

The build targets `sm_120` and retains `compute_120` PTX. It runs serially with
other native builds on the organization-scoped `lil-wheel-builder` runner and
uses the shared, resource-bounded BuildKit cache.
