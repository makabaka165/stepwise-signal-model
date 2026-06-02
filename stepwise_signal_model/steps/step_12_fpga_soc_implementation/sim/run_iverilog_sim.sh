#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STEP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${STEP_DIR}/build/iverilog"

mkdir -p "${BUILD_DIR}"

run_tb() {
  local tb_name="$1"
  local rtl_name="$2"
  local out_file="${BUILD_DIR}/${tb_name}.vvp"
  echo "[iverilog] ${tb_name}"
  iverilog -g2012 -o "${out_file}" \
    "${STEP_DIR}/rtl/${rtl_name}.v" \
    "${STEP_DIR}/tb/${tb_name}.v"
  vvp "${out_file}"
}

run_tb tb_shared_center_column_selector shared_center_column_selector
run_tb tb_y_work_packer y_work_packer
run_tb tb_projection_score_core projection_score_core

echo "All Step12 iverilog simulations passed."
