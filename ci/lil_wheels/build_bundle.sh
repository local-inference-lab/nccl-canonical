#!/usr/bin/env bash
# Build source-addressed NCCL wheel and native runtime release assets.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tool_dir="${repo_root}/ci/lil_wheels"
lock_path="${tool_dir}/runtime.lock"
output_dir=${1:-"${repo_root}/dist/lil-nccl-cu133-sm120"}
value() {
  local key=$1
  awk -F= -v key="${key}" \
    '$1 == key {sub(/^[^=]*=/, ""); print; found=1} END {exit !found}' \
    "${lock_path}"
}

commit=$(git -C "${repo_root}" rev-parse HEAD)
tree=$(git -C "${repo_root}" rev-parse 'HEAD^{tree}')
source_date_epoch=$(git -C "${repo_root}" show -s --format=%ct HEAD)
base_version=$(value nccl.version)
package_version="${base_version}+lil.cu133.sm120.g${commit:0:12}"
release_tag=${NCCL_RELEASE_TAG:-"nccl-cu133-sm120-${commit}"}
test -z "$(git -C "${repo_root}" status --porcelain --untracked-files=no)"
"${tool_dir}/ensure_builder.sh"

mkdir -p "$(dirname "${output_dir}")"
if ! mkdir "${output_dir}"; then
  printf 'Output path already exists or is being built: %s\n' \
    "${output_dir}" >&2
  exit 1
fi

docker buildx build \
  --builder "$(value buildx.builder)" \
  --file "${tool_dir}/Dockerfile" \
  --build-arg "BUILDER_IMAGE=$(value builder.image)" \
  --build-arg "BUILD_JOBS=$(value build.max-jobs)" \
  --build-arg "NCCL_PACKAGE_VERSION=${package_version}" \
  --build-arg "NCCL_SOURCE_COMMIT=${commit}" \
  --build-arg "NCCL_SOURCE_DATE_EPOCH=${source_date_epoch}" \
  --target artifacts \
  --output "type=local,dest=${output_dir}/raw" \
  "${repo_root}"

mkdir -p "${output_dir}/bundle"
cp -a "${output_dir}/raw/." "${output_dir}/bundle/"
wheel=$(find "${output_dir}/bundle/wheels" -maxdepth 1 \
  -name 'local_inference_nccl_cu133-*.whl' -print -quit)
test -n "${wheel}"
wheel_sha=$(sha256sum "${wheel}" | awk '{print $1}')
library="${output_dir}/bundle/native/nccl/lib/libnccl.so.2.31.2"
library_sha=$(sha256sum "${library}" | awk '{print $1}')

repository=${GITHUB_REPOSITORY:-local-inference-lab/nccl-canonical}
wheel_url="https://github.com/${repository}/releases/download/${release_tag}/$(basename "${wheel}")"
printf 'local-inference-nccl-cu133 @ %s --hash=sha256:%s\n' \
  "${wheel_url}" "${wheel_sha}" \
  > "${output_dir}/bundle/requirements-github.txt"

jq -n \
  --arg status research-only \
  --arg repository "https://github.com/${repository}.git" \
  --arg commit "${commit}" --arg tree "${tree}" \
  --arg package_version "${package_version}" \
  --arg wheel "$(basename "${wheel}")" --arg wheel_sha "${wheel_sha}" \
  --arg library_sha "${library_sha}" \
  --arg cuda "$(value cuda.version)" \
  '{
    schema: "local-inference-nccl-cu133-release/v1",
    status: $status,
    source: {repository: $repository, commit: $commit, tree: $tree},
    package_version: $package_version,
    runtime: {cuda: $cuda, architecture: "SM120 and compute_120 PTX"},
    wheel: {file: $wheel, sha256: $wheel_sha},
    native: {
      prefix: "native/nccl",
      library: "native/nccl/lib/libnccl.so.2.31.2",
      sha256: $library_sha
    },
    loader_contract: "Set LD_PRELOAD and VLLM_NCCL_SO_PATH before importing torch."
  }' > "${output_dir}/bundle/manifest.json"
cp "${lock_path}" "${output_dir}/bundle/"
(
  cd "${output_dir}/bundle"
  find wheels native -type f -print0 | sort -z | xargs -0 sha256sum
  sha256sum manifest.json requirements-github.txt runtime.lock
) > "${output_dir}/bundle/SHA256SUMS"

archive="${output_dir}/local-inference-nccl-cu133-${commit}.tar.zst"
tar --sort=name --mtime="@${source_date_epoch}" \
  --owner=0 --group=0 --numeric-owner --zstd \
  -C "${output_dir}/bundle" -cf "${archive}" .
sha256sum "${archive}" > "${archive}.sha256"
printf '%s\n' "${archive}"
