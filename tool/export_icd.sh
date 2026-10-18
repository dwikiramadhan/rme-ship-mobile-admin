#!/usr/bin/env bash
# Exports the ICD-10 (diagnosis) and ICD-9-CM (procedure) code lists from the
# backend database into app assets, so the doctor's ICD pickers search on the
# device and work offline. Re-run whenever the backend's ICD tables change,
# then ship a new app release.
#
# Connection via the standard libpq variables (see tool/export_wilayah.sh).
#
# Format: {"exported_at": "2026-10-18", "items": [["A00.0", "Cholera due to ..."], ...]}
# Items keep the backend's order (ORDER BY code), so search results come in
# the same order as from the API.
set -euo pipefail

dir="$(dirname "$0")/../assets/data"
mkdir -p "$dir"

export_table() {
  local table="$1" out="$dir/$2"
  psql -At -v ON_ERROR_STOP=1 -c "
    SELECT json_build_object(
      'exported_at', to_char(current_date, 'YYYY-MM-DD'),
      'items', (SELECT json_agg(json_build_array(code, display) ORDER BY code) FROM $table)
    )" | gzip -9 > "$out"
  echo "Wrote $out ($(wc -c < "$out" | tr -d ' ') bytes)"
}

export_table icd10_diagnosis icd10.json.gz
export_table icd9cm_procedure icd9cm.json.gz
