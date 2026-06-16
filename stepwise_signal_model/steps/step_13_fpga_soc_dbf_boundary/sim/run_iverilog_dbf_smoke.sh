#!/usr/bin/env bash
set -euo pipefail

if [[ ! -d "rtl" || ! -d "tb" || ! -d "sim" ]]; then
  echo "ERROR: run this script from steps/step_13_fpga_soc_dbf_boundary" >&2
  exit 2
fi

if ! command -v iverilog >/dev/null 2>&1; then
  echo "UNAVAILABLE: iverilog was not found on PATH." >&2
  exit 3
fi

if ! command -v vvp >/dev/null 2>&1; then
  echo "UNAVAILABLE: vvp was not found on PATH." >&2
  exit 3
fi

GOLDEN_VH="results_step13_fpga_soc_dbf_boundary/rtl_golden/step13_dbf_rtl_golden_vectors.vh"
if [[ ! -f "${GOLDEN_VH}" ]]; then
  echo "ERROR: missing ${GOLDEN_VH}; run matlab_golden/generate_step13_dbf_rtl_golden.m first." >&2
  exit 4
fi

SIM_DIR="results_step13_fpga_soc_dbf_boundary/rtl_sim"
mkdir -p "${SIM_DIR}"
rm -f "${SIM_DIR}/dbf_core_accum_output.csv"
rm -f "${SIM_DIR}/step13_dbf_rtl_sim_summary.csv"

iverilog -g2001 -Wall \
  -o "${SIM_DIR}/tb_dbf_complex_mac.vvp" \
  rtl/dbf_complex_mac.v \
  tb/tb_dbf_complex_mac.v
vvp "${SIM_DIR}/tb_dbf_complex_mac.vvp"

iverilog -g2001 -Wall \
  -I "results_step13_fpga_soc_dbf_boundary/rtl_golden" \
  -o "${SIM_DIR}/tb_dbf_core_accum.vvp" \
  rtl/dbf_complex_mac.v \
  rtl/dbf_beam_accum_core.v \
  rtl/dbf_core_accum.v \
  tb/tb_dbf_core_accum.v
vvp "${SIM_DIR}/tb_dbf_core_accum.vvp"

{
  echo "metric,value"
  echo "sim_status,pass"
  echo "tool,iverilog"
  echo "scope,raw DBF accumulator Z = W^H Y"
  echo "formal_result_claimed,false"
  echo "rz_gcache_ml_topk_c05_implemented,false"
} > "${SIM_DIR}/step13_dbf_rtl_sim_summary.csv"

echo "Step13.2 iverilog DBF smoke PASS. Outputs: ${SIM_DIR}"

