# Map data

© OpenStreetMap contributors. Original OSM files supplied by the project creator in `Maps.rar`; exact hashes and sizes are recorded in `source/provenance.json`.

`source/*.osm` and the derived geographic database in `generated/*.json` are made available under **ODbL 1.0**: https://opendatacommons.org/licenses/odbl/1-0/ . Attribution: https://www.openstreetmap.org/copyright . The source is retained for regeneration and inspection; `.gdignore` excludes the originals from Godot's import scan.

`tools/import_lisbon_maps.py` projects and crops three metric districts, then triangulates footprints and roads. Generated metadata deliberately includes only geometry, relevant street/venue names and whitelisted map properties, without copying contact records. This is a compact fictional arrangement of real local street layouts, with inferred building heights where data is absent. The river and bridge are original stylised geometry, not OSM imports.

`textures/` contains original facade variants derived from this project's own wall textures; regeneration script: `tools/build_map_facades.py`. No proprietary GTA assets are included. See `docs/ENTREGAR_MAPAS.md` and `docs/VALIDACAO_MAPAS.md` for the delivered scope and tests.
