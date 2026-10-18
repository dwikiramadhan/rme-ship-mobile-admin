#!/usr/bin/env bash
# Exports the region reference data (provinsi → kabupaten/kota → kecamatan →
# kelurahan/desa) from the backend database into the app asset
# assets/data/wilayah.json.gz, so the patient form's address dropdowns work
# offline. Re-run whenever the backend's region tables change, then ship a
# new app release.
#
# Connection via the standard libpq variables, e.g.:
#   PGHOST=127.0.0.1 PGPORT=5432 PGUSER=postgres PGPASSWORD=... \
#   PGDATABASE=rme_ship_hospitality tool/export_wilayah.sh
#
# Format (codes as strings, grouped by parent code):
#   {"exported_at": "2026-10-18",
#    "provinsi": [[64, "Kalimantan Timur"], ...],
#    "kabkota":   {"64": [["64.02", "Kabupaten Kutai Kartanegara"], ...]},
#    "kecamatan": {"64.02": [["64.02.01", "Muara Muntai"], ...]},
#    "kelurahan": {"64.02.01": [["64.02.01.2001", "Perian", 75562], ...]}}
# kode_kabkota is a `real` column; it is written with 2 decimals ("11.10").
set -euo pipefail

out="$(dirname "$0")/../assets/data/wilayah.json.gz"
mkdir -p "$(dirname "$out")"

psql -At -v ON_ERROR_STOP=1 <<'SQL' | gzip -9 > "$out"
SELECT json_build_object(
  -- Shown in the profile's "Data Offline" section.
  'exported_at', to_char(current_date, 'YYYY-MM-DD'),
  'provinsi', (
    SELECT json_agg(json_build_array(kode_provinsi, nama_provinsi) ORDER BY kode_provinsi)
    FROM provinsi
  ),
  'kabkota', (
    SELECT json_object_agg(parent, items) FROM (
      SELECT kode_provinsi::text AS parent,
             json_agg(json_build_array(to_char(kode_kabkota, 'FM990.00'), nama_kabkota)
                      ORDER BY kode_kabkota) AS items
      FROM kabupaten_kota GROUP BY kode_provinsi
    ) g
  ),
  'kecamatan', (
    SELECT json_object_agg(parent, items) FROM (
      SELECT to_char(kode_kabkota, 'FM990.00') AS parent,
             json_agg(json_build_array(kode_kecamatan, nama_kecamatan)
                      ORDER BY kode_kecamatan) AS items
      FROM kecamatan GROUP BY to_char(kode_kabkota, 'FM990.00')
    ) g
  ),
  -- Villages whose district is missing can't be reached from the dropdowns.
  'kelurahan', (
    SELECT json_object_agg(parent, items) FROM (
      SELECT d.kode_kecamatan AS parent,
             json_agg(json_build_array(d.kode_kelurahan, d.nama_kelurahan, d.kode_pos)
                      ORDER BY d.kode_kelurahan) AS items
      FROM kelurahan_desa d
      WHERE EXISTS (SELECT 1 FROM kecamatan c WHERE c.kode_kecamatan = d.kode_kecamatan)
      GROUP BY d.kode_kecamatan
    ) g
  )
);
SQL

echo "Wrote $out ($(wc -c < "$out" | tr -d ' ') bytes)"
