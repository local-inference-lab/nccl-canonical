#!/usr/bin/env bash
# Verify the bounded rootless BuildKit worker shared by native wheel builds.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
lock_path="${repo_root}/ci/lil_wheels/runtime.lock"
value() {
  local key=$1
  awk -F= -v key="${key}" \
    '$1 == key {sub(/^[^=]*=/, ""); print; found=1} END {exit !found}' \
    "${lock_path}"
}

builder=$(value buildx.builder)
docker info --format '{{json .SecurityOptions}}' | grep -q 'name=rootless'
docker buildx inspect --bootstrap "${builder}" >/dev/null

runner_uid=$(id -u)
user_slice="user-${runner_uid}.slice"
control_group=$(systemctl show --value --property ControlGroup "${user_slice}")
cgroup="/sys/fs/cgroup${control_group}"
test "$(<"${cgroup}/memory.high")" = "$(value buildx.memory-high-bytes)"
test "$(<"${cgroup}/memory.max")" = "$(value buildx.memory-bytes)"
test "$(<"${cgroup}/memory.swap.max")" = "$(value buildx.swap-max-bytes)"
test "$(<"${cgroup}/pids.max")" = "$(value buildx.tasks-max)"
test "$(<"${cgroup}/cpuset.cpus.effective")" = "$(value buildx.cpuset)"
read -r quota period < "${cgroup}/cpu.max"
test "${quota}" = "$(value buildx.cpu-quota)"
test "${period}" = "$(value buildx.cpu-period)"

printf 'builder=%s memory_max=%s cpuset=%s cpu_quota=%s\n' \
  "${builder}" "$(<"${cgroup}/memory.max")" \
  "$(<"${cgroup}/cpuset.cpus.effective")" "${quota}/${period}"
