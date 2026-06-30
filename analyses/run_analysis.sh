#!/usr/bin/env bash
# Run a Rivet analysis and compare with the stored reference output.
#
# Usage:
#   bash analyses/run_analysis.sh <ANALYSIS_ID> [events.hepmc] [lock-file-stem]
#
# Example:
#   bash analyses/run_analysis.sh ATLAS_2012_I1189423 analyses/events/test.hepmc rivet-3.1.11-env
set -euo pipefail

ANALYSIS="${1:?Usage: $0 <ANALYSIS_ID> [events.hepmc] [lock-stem]}"
EVENTS="${2:-analyses/events/test.hepmc}"
LOCK_STEM="${3:-}"

# Activate conda environment
if [ -n "$LOCK_STEM" ] && command -v conda-lock &>/dev/null; then
    conda-lock install -n hep-replay "analyses/locks/${LOCK_STEM}.lock.yml"
    CONDA_RUN="conda run -n hep-replay"
else
    CONDA_RUN=""
fi

OUTPUT="output_${ANALYSIS}.yoda"
REFERENCE="analyses/reference/${ANALYSIS}.yoda"

echo "Running Rivet analysis: $ANALYSIS"
$CONDA_RUN rivet --analysis="$ANALYSIS" --hepmc "$EVENTS" -o "$OUTPUT"

if [ -f "$REFERENCE" ]; then
    echo "Comparing with reference: $REFERENCE"
    $CONDA_RUN rivet-cmp-histo "$OUTPUT" "$REFERENCE" || true
    echo "Done. Differences above (if any)."
else
    echo "No reference found at $REFERENCE — storing this run as the new reference."
    cp "$OUTPUT" "$REFERENCE"
    echo "Stored reference at $REFERENCE"
fi
