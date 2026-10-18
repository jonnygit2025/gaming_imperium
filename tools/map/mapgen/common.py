"""Costanti, proiezione e utilità condivise dalla generazione della mappa di campagna.

Proiezione: equirettangolare corretta per la latitudine media (38°N), centrata su 19°E.
1 unità di gioco = 10 km in orizzontale. Nord = -Z, Est = +X (convenzione di Godot).
"""
from __future__ import annotations

import json
import math
import os

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
CACHE = os.path.join(ROOT, "tools", "map", "_cache")
NE_DIR = os.path.join(CACHE, "natural-earth-vector", "geojson")
OUT_ASSETS = os.path.join(ROOT, "assets", "map")
OUT_DATA = os.path.join(ROOT, "data", "map")

LON_MIN, LON_MAX = -12.0, 50.0
LAT_MIN, LAT_MAX = 20.0, 56.0
LON0 = (LON_MIN + LON_MAX) / 2.0      # 19°E
LAT0 = (LAT_MIN + LAT_MAX) / 2.0      # 38°N
KM_PER_DEG = 111.19                   # sfera di raggio 6371 km
UNIT_KM = 10.0                        # 1 unità = 10 km
COS_LAT0 = math.cos(math.radians(LAT0))

# Texture principali: 2048 px di larghezza (limite del progetto).
TEX_W = 2048
WORLD_W = (LON_MAX - LON_MIN) * KM_PER_DEG * COS_LAT0 / UNIT_KM
PX = WORLD_W / TEX_W                  # unità per pixel (~0,265 = 2,65 km)
WORLD_H_RAW = (LAT_MAX - LAT_MIN) * KM_PER_DEG / UNIT_KM
TEX_H = int(round(WORLD_H_RAW / PX))
WORLD_H = TEX_H * PX
X_MIN, X_MAX = -WORLD_W / 2.0, WORLD_W / 2.0
Z_MIN, Z_MAX = -WORLD_H / 2.0, WORLD_H / 2.0

# Rilievo: 1 km di quota = VERTICAL unità (esagerazione ×10 rispetto alla scala orizzontale,
# come nelle mappe strategiche: altrimenti da lontano le montagne non si vedrebbero).
VERTICAL = 1.0
SEA_LEVEL = 0.0

SEA = 0
NEUTRAL = 255


def lonlat_to_world(lon, lat):
    x = (np.asarray(lon, dtype=np.float64) - LON0) * KM_PER_DEG * COS_LAT0 / UNIT_KM
    z = (LAT0 - np.asarray(lat, dtype=np.float64)) * KM_PER_DEG / UNIT_KM
    return x, z


def world_to_px(x, z, scale=1.0):
    """Coordinate continue in pixel (0..TEX_W*scale) dal mondo."""
    px = (np.asarray(x) - X_MIN) / PX * scale
    py = (np.asarray(z) - Z_MIN) / PX * scale
    return px, py


def lonlat_to_px(lon, lat, scale=1.0):
    x, z = lonlat_to_world(lon, lat)
    return world_to_px(x, z, scale)


def px_to_world(px, py, scale=1.0):
    x = X_MIN + np.asarray(px) / scale * PX
    z = Z_MIN + np.asarray(py) / scale * PX
    return x, z


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def load_geojson(name):
    return load_json(os.path.join(NE_DIR, name))


def iter_polygons(geom):
    """Restituisce liste di anelli [esterno, buchi...] in lon/lat."""
    t = geom["type"]
    if t == "Polygon":
        yield geom["coordinates"]
    elif t == "MultiPolygon":
        for poly in geom["coordinates"]:
            yield poly


def iter_lines(geom):
    t = geom["type"]
    if t == "LineString":
        yield geom["coordinates"]
    elif t == "MultiLineString":
        for line in geom["coordinates"]:
            yield line


def ring_bbox(ring):
    a = np.asarray(ring)
    return a[:, 0].min(), a[:, 1].min(), a[:, 0].max(), a[:, 1].max()


def in_area(bbox, margin=2.0):
    x0, y0, x1, y1 = bbox
    return x1 > LON_MIN - margin and x0 < LON_MAX + margin and y1 > LAT_MIN - margin and y0 < LAT_MAX + margin


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)
