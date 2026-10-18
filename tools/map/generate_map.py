#!/usr/bin/env python3
"""Genera offline la mappa di campagna di Regna a partire da Natural Earth (pubblico dominio).

Uso:  tools/map/fetch_natural_earth.sh   (una volta)
      python3 tools/map/generate_map.py [--debug]
Poi:  godot --headless -s tools/map/build_map_resources.gd   (mesh del terreno)
Oppure tutto insieme: tools/map/build_map.sh

Produce (vedi assets/map/README.md):
  assets/map/province_ids.png     R = provincia (1..47, 0 mare, 255 terre esterne), G = provincia
                                  oltre il confine più vicino, B = terra (255) / acqua (0)
  assets/map/province_fields.png  R = distanza dal confine di provincia, G = distanza con segno
                                  dalla costa (campi lisci per linee nette a ogni zoom)
  assets/map/terrain_albedo.png   colori del terreno (biomi, fiumi, laghi)
  assets/map/minimap_base.png     sfondo della minimappa
  assets/map/water_noise.png      piccola texture ripetibile per le onde
  data/map/campaign_map.json      proiezione, dimensioni, posizioni di città ed etichette
  tools/map/_cache/heights.f32    quote per il terreno (letto dallo script Godot)
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time

import numpy as np
from PIL import Image
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mapgen import common as C  # noqa: E402
from mapgen import raster, regions, provinces as P, terrain  # noqa: E402

NATURAL_LAKES = {
    "Lake Geneva", "Bodensee", "Lake Balaton", "Lake Van", "Lake Urmia", "Lake Sevan", "Lake Tuz",
    "Dead Sea", "Sea of Galilee", "Lake Skadar", "Lough Neagh", "Lake Hammar", "Lake Habbaniyah",
}


def log(msg):
    print("[mappa] %s" % msg, flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--debug", action="store_true", help="salva immagini di controllo in tools/map/_cache")
    ap.add_argument("--solo-province", action="store_true", help="si ferma dopo le province (per le prove)")
    args = ap.parse_args()
    t0 = time.time()
    if not os.path.isdir(C.NE_DIR):
        sys.exit("Mancano i dati di Natural Earth: esegui prima tools/map/fetch_natural_earth.sh")
    os.makedirs(C.OUT_ASSETS, exist_ok=True)
    os.makedirs(C.CACHE, exist_ok=True)
    prov_data = C.load_json(os.path.join(C.OUT_DATA, "provinces.json"))
    provs = prov_data["provinces"]
    straits = prov_data.get("straits", [])
    log("griglia %d x %d, %.3f unità per pixel (%.2f km)" % (C.TEX_W, C.TEX_H, C.PX, C.PX * C.UNIT_KM))

    # 1. Terra e acqua (a doppia risoluzione per una costa precisa)
    land_fc = C.load_geojson("ne_50m_land.geojson")
    land2 = raster.polygons_mask(land_fc["features"], scale=2)
    land = raster.downsample_mean(land2.astype(np.float32), 2) >= 0.5
    lakes_fc = C.load_geojson("ne_50m_lakes.geojson")
    lakes = raster.polygons_mask(lakes_fc["features"], select=lambda f: f["properties"].get("name") in NATURAL_LAKES)
    lakes &= land
    rivers_fc = C.load_geojson("ne_50m_rivers_lake_centerlines.geojson")
    log("terra e acqua pronte (%.1f s)" % (time.time() - t0))

    # Distanza con segno dalla costa, in pixel della texture (positiva sulla terra)
    d_land = ndimage.distance_transform_edt(land2) / 2.0
    d_sea = ndimage.distance_transform_edt(~land2) / 2.0
    coast_sd2 = np.where(land2, d_land - 0.25, -(d_sea - 0.25))
    coast_sd = raster.downsample_mean(coast_sd2, 2)

    # 2. Regioni naturali
    peaks = regions.elevation_points()
    mtn_h, mtn_core, used = regions.mountain_field(peaks)
    plateau = regions.plateau_field()
    desert = regions.desert_field()
    log("%d catene montuose, %d vette (%.1f s)" % (len(used), len(peaks), time.time() - t0))

    # 3. Province
    lab_half, index, allowed, seeds = P.grow(provs, land, mtn_core, desert)
    labels = P.upsample_and_clean(lab_half, land, allowed)
    labels = P.assign_islands(labels, land)
    labels = P.remove_fragments(labels, land)
    labels = P.enforce(labels, allowed)
    labels[land & (labels == 0)] = C.NEUTRAL
    labels[~land] = C.SEA
    report = check_adjacency(provs, straits, labels, index)
    log("province pronte (%.1f s)" % (time.time() - t0))
    if args.solo_province:
        debug_images(labels, None, np.zeros((2, 2), np.float32), provs, index)
        print("\n".join(report) or "confini coerenti")
        return

    # 4. Rilievo
    heights = terrain.height_field(land, coast_sd, mtn_h, mtn_core, plateau, desert, labels, provs, index, lakes)
    heights = terrain.flatten_cities(heights, provs, land)
    log("rilievo: quota massima %.2f km (%.1f s)" % (heights.max() / C.VERTICAL, time.time() - t0))

    # 5. Colori del terreno
    river_mask = raster.lines_mask(rivers_fc["features"], scale=2, width=lambda f: 1 if (f["properties"].get("scalerank") or 9) > 4 else 2)
    river_strength = raster.downsample_mean(ndimage.gaussian_filter(river_mask.astype(np.float32), 0.9) * 1.6, 2)
    albedo = terrain.albedo(land, coast_sd, heights, mtn_core, desert, labels, provs, index, lakes, river_strength)
    log("colori pronti (%.1f s)" % (time.time() - t0))

    # 6. Texture di gioco
    ids_rgba, fields = terrain.province_textures(labels, land, coast_sd, lakes)
    Image.fromarray(ids_rgba, "RGBA").save(os.path.join(C.OUT_ASSETS, "province_ids.png"), optimize=True)
    Image.fromarray(fields, "RGBA").save(os.path.join(C.OUT_ASSETS, "province_fields.png"), optimize=True)
    Image.fromarray(albedo, "RGB").save(os.path.join(C.OUT_ASSETS, "terrain_albedo.png"), optimize=True)
    mini = terrain.minimap(albedo, heights, land)
    Image.fromarray(mini, "RGB").save(os.path.join(C.OUT_ASSETS, "minimap_base.png"), optimize=True)
    Image.fromarray(terrain.water_noise(), "RGBA").save(os.path.join(C.OUT_ASSETS, "water_noise.png"), optimize=True)
    terrain.save_heights(heights, os.path.join(C.CACHE, "heights.f32"))
    V, T = terrain.terrain_mesh(heights, coast_sd, mtn_core, land)
    terrain.save_mesh(V, T, os.path.join(C.CACHE, "terrain_mesh.bin"))
    log("mesh del terreno: %d vertici, %d triangoli" % (len(V), len(T)))
    meta = build_meta(provs, labels, index, seeds, heights, land)
    with open(os.path.join(C.OUT_DATA, "campaign_map.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=1)
        f.write("\n")
    if args.debug:
        debug_images(labels, albedo, heights, provs, index)
    log("fatto in %.1f s" % (time.time() - t0))
    if report:
        log("ATTENZIONE: confini non coerenti:\n  " + "\n  ".join(report))
        sys.exit(2)


def check_adjacency(provs, straits, labels, index):
    """Confronta i contatti sulla mappa con i confini del JSON. Restituisce i problemi."""
    pairs = P.adjacency(labels, connectivity=4)
    inv = {v: k for k, v in index.items()}
    strait_pairs = {tuple(sorted((s["a"], s["b"]))) for s in straits}
    problems = []
    for p in provs:
        for q in p["neighbors"]:
            if p["id"] < q:
                a, b = sorted((index[p["id"]], index[q]))
                n = pairs.get((a, b), 0)
                if n < 3 and tuple(sorted((p["id"], q))) not in strait_pairs:
                    problems.append("%s e %s dovrebbero toccarsi (contatto: %d px)" % (p["id"], q, n))
    nbrs = {p["id"]: set(p["neighbors"]) for p in provs}
    for (a, b), n in pairs.items():
        pa, pb = inv[a], inv[b]
        if pb not in nbrs[pa]:
            problems.append("%s e %s si toccano ma non sono confinanti (%d px)" % (pa, pb, n))
    for p in provs:
        cnt = int((labels == index[p["id"]]).sum())
        if cnt < 400:
            problems.append("%s è troppo piccola (%d px)" % (p["id"], cnt))
    return problems


def build_meta(provs, labels, index, seeds, heights, land):
    out_prov = {}
    for p in provs:
        L = index[p["id"]]
        mask = labels == L
        # Punto per l'etichetta: il più lontano dai bordi della regione principale.
        comps, n = ndimage.label(mask, structure=np.ones((3, 3)))
        sizes = ndimage.sum(mask, comps, index=np.arange(1, n + 1))
        main = comps == (int(np.argmax(sizes)) + 1)
        edt = ndimage.distance_transform_edt(main)
        ly, lx = np.unravel_index(int(np.argmax(edt)), edt.shape)
        cx, cy = (float(v) for v in C.lonlat_to_px(p["lon"], p["lat"]))
        if not land[min(C.TEX_H - 1, int(cy)), min(C.TEX_W - 1, int(cx))]:
            sx, sy = P._snap_to_land(land, cx, cy)
            cx, cy = sx + 0.5, sy + 0.5
        wx, wz = C.px_to_world(cx, cy)
        lx_w, lz_w = C.px_to_world(lx + 0.5, ly + 0.5)
        ys, xs = np.nonzero(mask)
        out_prov[p["id"]] = {
            "index": L,
            "city": [round(float(wx), 3), round(float(wz), 3)],
            "label": [round(float(lx_w), 3), round(float(lz_w), 3)],
            "area_km2": int(mask.sum() * (C.PX * C.UNIT_KM) ** 2),
            "bounds": [round(float(C.X_MIN + xs.min() * C.PX), 2), round(float(C.Z_MIN + ys.min() * C.PX), 2),
                       round(float(C.X_MIN + (xs.max() + 1) * C.PX), 2), round(float(C.Z_MIN + (ys.max() + 1) * C.PX), 2)],
        }
    return {
        "version": 1,
        "generated_by": "tools/map/generate_map.py",
        "source": "Natural Earth 1:50m e 1:10m (pubblico dominio)",
        "projection": {
            "type": "equirettangolare corretta per la latitudine media",
            "lon0": C.LON0, "lat0": C.LAT0, "km_per_degree": C.KM_PER_DEG, "unit_km": C.UNIT_KM,
            "cos_lat0": C.COS_LAT0, "vertical_units_per_km": C.VERTICAL,
        },
        "world": {"x_min": C.X_MIN, "x_max": C.X_MAX, "z_min": C.Z_MIN, "z_max": C.Z_MAX},
        "texture": {"width": C.TEX_W, "height": C.TEX_H, "units_per_pixel": C.PX},
        "codes": {"sea": C.SEA, "outer_lands": C.NEUTRAL},
        "province_order": [p["id"] for p in provs],
        "provinces": out_prov,
    }


def debug_images(labels, albedo, heights, provs, index):
    rng = np.random.default_rng(3)
    pal = rng.integers(60, 255, size=(256, 3)).astype(np.uint8)
    pal[0] = (20, 40, 80)
    pal[C.NEUTRAL] = (60, 60, 60)
    img = pal[labels]
    Image.fromarray(img).save(os.path.join(C.CACHE, "debug_labels.png"))
    h = heights.copy()
    hs = np.clip((h - h.min()) / (h.max() - h.min()) * 255, 0, 255).astype(np.uint8)
    Image.fromarray(hs).save(os.path.join(C.CACHE, "debug_heights.png"))


if __name__ == "__main__":
    main()
