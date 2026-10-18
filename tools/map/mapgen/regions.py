"""Catene montuose, altopiani e deserti dai poligoni regionali di Natural Earth."""
from __future__ import annotations

import numpy as np
from scipy import ndimage

from .common import load_geojson, iter_polygons, ring_bbox, in_area, TEX_W, TEX_H, lonlat_to_px
from .raster import polygons_mask

# Quota tipica delle creste (km) per le catene più importanti; le altre usano le vette di
# Natural Earth contenute nel poligono (o 1,2 km).
RANGE_HEIGHT = {
    "ALPS": 3.0, "ATLAS MOUNTAINS": 0.9, "PYRENEES": 2.4, "APPENNINI": 1.6, "Dinaric Alps": 1.6, "Balkan Mts.": 1.6,
    "Pindus Mts.": 1.8, "CARPATHIAN MOUNTAINS": 1.7, "Transylvanian Alps": 2.0, "Taurus Mts.": 2.6,
    "PONTIC MOUNTAINS": 2.4, "CAUCASUS MTS.": 3.6, "Lesser Caucasus": 2.6, "ZAGROS MOUNTAINS": 2.8,
    "ELBURZ MTS.": 3.2, "HAUT ATLAS": 3.2, "Moyen Atlas": 2.2, "ATLAS SAHARIEN": 1.6,
    "Atlas Tellien": 1.4, "Er Rif": 1.8, "Anti Atlas": 1.8, "Lebanon Mts.": 2.2, "HEJAZ MTS.": 1.8,
    "ASIR MTS.": 2.2, "S. Nevada": 2.4, "Sierra Morena": 0.9, "Cord. Cantábrica": 1.9,
    "Calabria": 1.3, "Jura": 1.2, "Vosges": 1.0, "Massif Central": 1.0, "Ardennes": 0.5,
    "Al Jabal al Akhdar": 0.8, "Tatra Mts.": 1.8, "AHAGGAR MTS.": 2.0, "TIBESTI MTS.": 2.2,
    "Böhmerwald": 1.0, "Sudetes Mts.": 1.0, "Erzgebirge": 0.9, "Harz": 0.8, "KUH RUD MOUNTAINS": 2.6,
    "Tuwayq Mts.": 0.9, "Jabal bin Ghunaymah": 0.6, "Grampian Mts.": 0.9, "Cambrian Mts.": 0.7,
}
# Catene non presenti in Natural Earth ma importanti per il gioco: (nome, quota, punti lon/lat, larghezza km)
EXTRA_RANGES = [
    ("Sistema Central", 1.8, [(-7.2, 40.2), (-5.6, 40.3), (-4.2, 40.6), (-3.2, 41.1)], 45),
    ("Sistema Ibérico", 1.6, [(-3.4, 42.2), (-2.4, 41.6), (-1.6, 40.8), (-1.0, 40.2)], 55),
    ("Monti della Sardegna", 1.0, [(9.3, 40.3), (9.2, 39.9), (9.1, 39.5)], 35),
    ("Monti della Corsica", 1.6, [(8.9, 42.6), (9.0, 42.2), (9.2, 41.8)], 30),
    ("Monti della Sicilia", 1.2, [(13.4, 37.9), (14.4, 37.9), (15.0, 37.75)], 30),
    ("Monti di Creta", 1.6, [(23.8, 35.3), (24.8, 35.2), (25.6, 35.1)], 22),
    ("Troodos", 1.4, [(32.7, 34.95), (33.1, 34.9)], 25),
    ("Rodopi", 1.6, [(23.6, 41.7), (24.6, 41.6), (25.6, 41.5)], 50),
    ("Monti della Macedonia", 1.8, [(21.0, 41.6), (22.0, 40.4), (22.4, 40.1)], 45),
    ("Peloponneso", 1.5, [(21.8, 37.9), (22.3, 37.4), (22.6, 36.8)], 40),
    ("Anti-Libano", 1.8, [(35.9, 33.4), (36.3, 33.9), (36.7, 34.4)], 25),
    ("Monti di Giudea", 0.8, [(35.1, 31.2), (35.2, 31.8), (35.3, 32.4)], 25),
    ("Amano", 1.5, [(36.1, 36.2), (36.4, 36.8), (36.7, 37.3)], 25),
    ("Altopiano armeno", 2.2, [(40.5, 39.6), (42.5, 39.3), (44.0, 39.2)], 120),
    ("Tauro orientale", 2.3, [(36.5, 38.0), (38.5, 38.3), (40.5, 38.4), (42.5, 38.3)], 60),
    ("Monti del Sinai", 1.6, [(33.6, 28.9), (34.0, 28.5), (34.2, 28.2)], 35),
    ("Monti del Mar Rosso", 1.4, [(32.6, 27.5), (33.4, 26.0), (34.4, 24.5), (35.2, 23.0)], 35),
    ("Monti dei Balcani occidentali", 1.6, [(19.8, 42.6), (20.8, 42.3), (21.6, 42.2)], 45),
    ("Aspromonte", 1.3, [(15.9, 38.2), (16.2, 38.9), (16.3, 39.4)], 22),
]
# Altopiani: (nome NE, quota aggiunta in km)
PLATEAUS = {
    "PENÍNSULA IBÉRICA": 0.45, "ANATOLIA": 0.75, "Massif Central": 0.35, "Libyan Plateau": 0.15,
    "Stavropol’ Plateau": 0.2, "CENTRAL RUSSIAN UPLAND": 0.15, "Volga Upland": 0.1,
    "Plat. du Tademaït": 0.25, "Jilf al Kabir Plateau": 0.4,
}
DESERTS_EXTRA = ("Arabian Desert",)


def _features(fc, cls):
    for f in fc["features"]:
        p = f["properties"]
        if p.get("FEATURECLA") != cls:
            continue
        rings = list(iter_polygons(f["geometry"]))
        if not rings or not any(in_area(ring_bbox(r[0]), 0.0) for r in rings):
            continue
        yield f


def _polyline_mask(points, width_km):
    from PIL import Image, ImageDraw
    from .common import PX, UNIT_KM
    img = Image.new("L", (TEX_W, TEX_H), 0)
    d = ImageDraw.Draw(img)
    lon = np.array([p[0] for p in points])
    lat = np.array([p[1] for p in points])
    px, py = lonlat_to_px(lon, lat)
    w = max(2, int(round(width_km / UNIT_KM / PX)))
    d.line(list(zip(px.tolist(), py.tolist())), fill=255, width=w, joint="curve")
    r = w // 2
    for x, y in zip(px.tolist(), py.tolist()):
        d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return np.asarray(img) > 127


def mountain_field(peaks):
    """Restituisce (inviluppo in km, nucleo 0..1): quota delle creste già sfumata e forza della catena."""
    fc = load_geojson("ne_10m_geography_regions_polys.geojson")
    height = np.zeros((TEX_H, TEX_W), np.float32)
    core = np.zeros((TEX_H, TEX_W), np.float32)
    used = []

    def add(mask, h, name):
        if not mask.any():
            return
        ys, xs = np.nonzero(mask)
        y0, y1 = max(0, ys.min() - 40), min(TEX_H, ys.max() + 41)
        x0, x1 = max(0, xs.min() - 40), min(TEX_W, xs.max() + 41)
        sub = mask[y0:y1, x0:x1]
        edt = ndimage.distance_transform_edt(sub)
        sigma = max(2.0, min(12.0, float(edt.max()) * 0.38))
        c = ndimage.gaussian_filter(sub.astype(np.float32), sigma)
        c = np.clip(c / max(1e-6, float(c[sub].max()) * 0.85), 0.0, 1.0) ** 0.8
        hs, cs = height[y0:y1, x0:x1], core[y0:y1, x0:x1]
        hs[:] = np.maximum(hs, c * h)
        cs[:] = np.maximum(cs, c)
        used.append((name, h))

    for f in _features(fc, "Range/mtn"):
        name = f["properties"]["NAME"]
        mask = polygons_mask([f])
        h = RANGE_HEIGHT.get(name)
        if h is None:
            inside = [e for (x, y, e) in peaks if 0 <= int(y) < TEX_H and 0 <= int(x) < TEX_W and mask[int(y), int(x)]]
            h = 0.6 * max(inside) / 1000.0 if inside else 1.2
        add(mask, float(h), name)
    for name, h, pts, width in EXTRA_RANGES:
        add(_polyline_mask(pts, width * 1.5), h, name)
    return height, core, used


def plateau_field():
    fc = load_geojson("ne_10m_geography_regions_polys.geojson")
    out = np.zeros((TEX_H, TEX_W), np.float32)
    for cls in ("Plateau", "Geoarea", "Pen/cape"):
        for f in _features(fc, cls):
            h = PLATEAUS.get(f["properties"]["NAME"])
            if h is None:
                continue
            m = polygons_mask([f]).astype(np.float32)
            m = ndimage.gaussian_filter(m, 18.0)
            out = np.maximum(out, m * h)
    return out


def desert_field():
    """0..1: quanto è desertico un pixel (Sahara, deserti arabi e siriani)."""
    fc = load_geojson("ne_10m_geography_regions_polys.geojson")
    m = np.zeros((TEX_H, TEX_W), np.float32)
    for f in _features(fc, "Desert"):
        m = np.maximum(m, polygons_mask([f]).astype(np.float32))
    # La penisola arabica interna e la Mesopotamia meridionale sono aride anche senza poligono.
    lon = np.linspace(-12, 50, TEX_W)[None, :]
    lat = np.linspace(56, 20, TEX_H)[:, None]
    arabia = ((lon > 36.5) & (lat < 31.5)) | ((lon > 38) & (lat < 33.5) & (lon < 44.5))
    m = np.maximum(m, arabia.astype(np.float32) * 0.9)
    return np.clip(ndimage.gaussian_filter(m, 14.0) * 1.3, 0.0, 1.0)


def elevation_points():
    fc = load_geojson("ne_10m_geography_regions_elevation_points.geojson")
    out = []
    for f in fc["features"]:
        lon, lat = f["geometry"]["coordinates"][:2]
        e = f["properties"].get("elevation") or 0
        if -12 <= lon <= 50 and 20 <= lat <= 56 and e > 0:
            px, py = lonlat_to_px(lon, lat)
            out.append((float(px), float(py), float(e)))
    return out
