#!/usr/bin/env python3
"""Dettagli della mappa di campagna, generati offline dopo generate_map.py.

Come nelle mappe di campagna dei grandi strategici, la mappa si "riempie" avvicinandosi:
strade fra le città confinanti, campi coltivati attorno agli abitati, boschi fatti di alberi,
villaggi minori sparsi nelle province e porti per le città sul mare. Tutto è calcolato qui:
il gioco carica solo dati pronti.

Legge:  assets/map/province_ids.png, province_fields.png, terrain_albedo.png,
        tools/map/_cache/heights.f32, data/map/provinces.json, data/map/campaign_map.json
Scrive: assets/map/details.png          R = distanza dalla strada più vicina (texel × 16)
                                         G = campi coltivati (0..255)
        assets/map/roads.png            RG = punto della strada più vicina (scarto dal centro del texel,
                                         texel × 32 + 128), B = direzione del tratto (0..π),
                                         A = 255 entro 3 texel da una strada
        assets/map/trees.bin            istanze degli alberi, già nel formato di MultiMesh
        data/map/campaign_details.json  stili delle città, strade, villaggi, porti, blocchi di alberi

Uso: python3 tools/map/generate_details.py
"""
from __future__ import annotations

import json
import math
import os
import struct
import sys
import time

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage
from scipy.sparse import csr_matrix
from scipy.sparse.csgraph import dijkstra

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from mapgen import common as C  # noqa: E402
from mapgen.noise import fbm  # noqa: E402
from mapgen.terrain import _terrain_map  # noqa: E402

# Stile architettonico per regione (alcune province hanno uno stile diverso dalla loro regione).
STYLE_BY_REGION = {
    "Italia": "mediterraneo", "Hispania": "mediterraneo", "Africa": "mediterraneo", "Gallia": "mediterraneo",
    "Balcani": "orientale", "Anatolia": "orientale", "Egitto": "orientale", "Oriente": "orientale",
}
STYLE_BY_PROVINCE = {
    "turonensis": "settentrionale", "burgundia": "settentrionale", "parisii": "settentrionale",
    "belgica": "settentrionale", "austrasia": "settentrionale", "armorica": "settentrionale",
    "pannonia": "settentrionale", "dalmatia": "mediterraneo",
    "mesopotamia": "desertico", "asoristan": "desertico", "hijaz": "desertico",
}
STYLES = ["mediterraneo", "orientale", "settentrionale", "desertico"]

ROAD_SCALE = 16.0          # valore del canale R per texel di distanza
TREES_PER_PX = 0.75        # alberi per pixel (2,65 km) di bosco pieno
CHUNK = 12.0               # lato dei blocchi di alberi (unità)
FLOATS_PER_TREE = 6        # x, y, z, scala, rotazione, tipo + tinta/10


def log(msg):
    print("[dettagli] %s" % msg, flush=True)


def load_heights():
    with open(os.path.join(C.CACHE, "heights.f32"), "rb") as f:
        magic, w, h = struct.unpack("<4sii", f.read(12))
        assert magic == b"RGTH"
        small = np.frombuffer(f.read(), dtype="<f4").reshape(h, w)
    full = ndimage.zoom(small, (C.TEX_H / h, C.TEX_W / w), order=1)
    out = np.zeros((C.TEX_H, C.TEX_W), np.float32)
    out[: full.shape[0], : full.shape[1]] = full[: C.TEX_H, : C.TEX_W]
    return small, out


def height_at(small, x, z):
    """Quota bilineare come CampaignMapData.height_at (stessa griglia)."""
    h, w = small.shape
    u = (np.asarray(x) - C.X_MIN) / (C.X_MAX - C.X_MIN)
    v = (np.asarray(z) - C.Z_MIN) / (C.Z_MAX - C.Z_MIN)
    fx = np.clip(u * w - 0.5, 0.0, w - 1.001)
    fy = np.clip(v * h - 0.5, 0.0, h - 1.001)
    x0 = np.floor(fx).astype(int)
    y0 = np.floor(fy).astype(int)
    tx, ty = fx - x0, fy - y0
    a = small[y0, x0] * (1 - tx) + small[y0, x0 + 1] * tx
    b = small[y0 + 1, x0] * (1 - tx) + small[y0 + 1, x0 + 1] * tx
    return np.maximum(a * (1 - ty) + b * ty, 0.0)


def forest_density(labels, provs, index, heights):
    """Stessa maschera dei boschi di terrain.albedo (stesso rumore, stesse regole)."""
    H, W = labels.shape
    lat = (C.LAT0 - (C.Z_MIN + (np.arange(H) + 0.5) * C.PX) * C.UNIT_KM / C.KM_PER_DEG)[:, None] * np.ones((1, W))
    km = np.maximum(heights, 0.0) / C.VERTICAL
    n1 = fbm((H, W), 22, 4, seed=21)
    n3 = fbm((H, W), 160, 3, seed=23)
    temperate = C.smoothstep(40.0, 47.5, lat + (n3 - 0.5) * 3.0)
    forest_w = _terrain_map(labels, provs, index,
                            {"pianura": 0.08, "colline": 0.2, "montagna": 0.25, "bosco": 0.5, "paludi": 0.15, "deserto": 0.0}, 0.3)
    forest_w = ndimage.gaussian_filter(forest_w, 10.0)
    forest_w = forest_w * (0.4 + 0.6 * temperate) + 0.18 * temperate
    mask = np.clip((n1 - (1.0 - forest_w)) * 6.0, 0.0, 0.85) * (1 - C.smoothstep(1.6, 2.4, km))
    return mask, temperate, km, lat


# ------------------------------------------------------------------ strade

def build_roads(provs, meta, land, km, lakes, sandy, coast_sd, straits=()):
    """Percorsi di costo minimo fra le città confinanti, su una griglia a metà risoluzione."""
    f = 2
    H, W = land.shape[0] // f, land.shape[1] // f
    # terra solo dove tutta la cella è terra: gli stretti (Messina, Gibilterra) restano aperti
    landh = land[: H * f, : W * f].reshape(H, f, W, f).all(axis=(1, 3))
    lakeh = lakes[: H * f, : W * f].reshape(H, f, W, f).mean(axis=(1, 3)) >= 0.5
    kmh = km[: H * f, : W * f].reshape(H, f, W, f).mean(axis=(1, 3))
    sandh = sandy[: H * f, : W * f].reshape(H, f, W, f).mean(axis=(1, 3))
    coasth = coast_sd[: H * f, : W * f].reshape(H, f, W, f).min(axis=(1, 3))
    gy, gx = np.gradient(kmh)
    slope = np.hypot(gx, gy)
    passable = landh & ~lakeh
    # pendenza e quota costano; il deserto molto (le vie romane in Africa seguivano la costa)
    cost = 1.0 + 14.0 * slope + 0.9 * kmh + 2.5 * sandh + 1.5 * (coasth < 2.5)
    idx = -np.ones((H, W), np.int64)
    ys, xs = np.nonzero(passable)
    idx[ys, xs] = np.arange(len(ys))
    def make_graph(c):
        rows, cols, vals = [], [], []
        for dy, dx in ((0, 1), (1, 0), (1, 1), (1, -1)):
            sa = (slice(0, H - dy), slice(max(0, -dx), W - max(0, dx)))
            sb = (slice(dy, H), slice(max(0, dx), W - max(0, -dx)))
            a, b = idx[sa], idx[sb]
            ca, cb = c[sa], c[sb]
            ok = (a >= 0) & (b >= 0)
            w = math.hypot(dx, dy) * 0.5 * (ca + cb)
            rows.append(a[ok]); cols.append(b[ok]); vals.append(w[ok])
        rows = np.concatenate(rows); cols = np.concatenate(cols); vals = np.concatenate(vals)
        return csr_matrix((np.concatenate([vals, vals]), (np.concatenate([rows, cols]), np.concatenate([cols, rows]))),
                          shape=(len(ys), len(ys)))

    def node_of(pid):
        cx, cz = meta["provinces"][pid]["city"]
        px, py = C.world_to_px(cx, cz, 1.0 / f)
        px, py = int(px), int(py)
        if 0 <= py < H and 0 <= px < W and idx[py, px] >= 0:
            return int(idx[py, px])
        d = np.hypot(xs - px, ys - py)
        return int(np.argmin(d))

    ids = [p["id"] for p in provs]
    nodes = {pid: node_of(pid) for pid in ids}
    # le province unite da uno stretto si raggiungono via mare, non con una strada
    strait_pairs = {tuple(sorted((st["a"], st["b"]))) for st in straits}
    pairs = sorted({tuple(sorted((p["id"], q))) for p in provs for q in p["neighbors"]} - strait_pairs)
    sources = sorted({a for a, _ in pairs})

    def paths_for(c):
        _, pred = dijkstra(make_graph(c), directed=False, indices=[nodes[x] for x in sources], return_predecessors=True)
        out = {}
        for a, b in pairs:
            row = pred[sources.index(a)]
            n = nodes[b]
            if n != nodes[a] and row[n] < 0:
                continue  # nessun percorso via terra (stretto o isola)
            path = [n]
            while n != nodes[a]:
                n = int(row[n])
                path.append(n)
            # niente giri assurdi (es. attorno a un mare): al massimo 3 volte la distanza in linea d'aria
            straight = math.hypot(xs[nodes[a]] - xs[nodes[b]], ys[nodes[a]] - ys[nodes[b]])
            if len(path) > 3.0 * straight + 20:
                continue
            out[(a, b)] = path
        return out

    # Primo giro: percorsi indipendenti. Secondo giro: viaggiare su una strada già tracciata
    # costa meno, così i percorsi vicini si fondono in una rete invece di correre paralleli.
    first = paths_for(cost)
    used = np.zeros((H, W), bool)
    for path in first.values():
        used[ys[path], xs[path]] = True
    used = ndimage.binary_dilation(used, iterations=1)
    final = paths_for(np.where(used, cost * 0.45, cost))
    roads = []
    for (a, b), path in sorted(final.items()):
        raw = np.stack([xs[path], ys[path]], axis=1).astype(np.float64) + 0.5
        # smussa, ma non al punto di tagliare golfi e insenature
        for eps, it in ((0.8, 2), (0.4, 1), (0.0, 0)):
            pts = chaikin(rdp(raw, eps), it) if eps > 0 else raw
            px, py = pts[:, 0] * f, pts[:, 1] * f
            ix = np.clip(px.astype(int), 0, land.shape[1] - 1)
            iy = np.clip(py.astype(int), 0, land.shape[0] - 1)
            if (~land[iy, ix]).sum() == 0:
                break
        wx, wz = C.px_to_world(pts[:, 0], pts[:, 1], 1.0 / f)
        roads.append({"a": a, "b": b, "points": [[round(float(x), 2), round(float(z), 2)] for x, z in zip(wx, wz)]})
    return roads


def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    ab = b - a
    n = np.hypot(*ab) or 1.0
    d = np.abs(ab[0] * (pts[:, 1] - a[1]) - ab[1] * (pts[:, 0] - a[0])) / n
    i = int(np.argmax(d))
    if d[i] > eps:
        return np.vstack([rdp(pts[: i + 1], eps)[:-1], rdp(pts[i:], eps)])
    return np.vstack([a, b])


def chaikin(pts, it):
    for _ in range(it):
        if len(pts) < 3:
            return pts
        q = 0.75 * pts[:-1] + 0.25 * pts[1:]
        r = 0.25 * pts[:-1] + 0.75 * pts[1:]
        mid = np.empty((2 * len(q), 2))
        mid[0::2], mid[1::2] = q, r
        pts = np.vstack([pts[:1], mid, pts[-1:]])
    return pts


def road_field(roads):
    """Distanza (in texel della mappa) dalla strada più vicina, per linee nette a ogni zoom."""
    s = 4
    img = Image.new("1", (C.TEX_W * s, C.TEX_H * s), 0)
    dr = ImageDraw.Draw(img)
    for r in roads:
        p = np.array(r["points"])
        px, py = C.world_to_px(p[:, 0], p[:, 1], s)
        dr.line(list(zip(px.tolist(), py.tolist())), fill=1, width=1)
    m = np.array(img, dtype=bool)
    d = ndimage.distance_transform_edt(~m) / s
    # valore al centro di ogni texel (un campo di distanza vero, da filtrare in modo lineare)
    return d[s // 2:: s, s // 2:: s][: C.TEX_H, : C.TEX_W]


def road_vectors(roads, reach=3.0):
    """Per ogni texel vicino a una strada: punto più vicino della strada (scarto dal centro del
    texel, in texel) e direzione del tratto. Lo shader ricava la distanza esatta dalla linea a
    ogni zoom (una distanza semplice, filtrata in modo lineare, spezzerebbe le linee sottili)."""
    best = np.full((C.TEX_H, C.TEX_W), np.inf, np.float32)
    off = np.zeros((C.TEX_H, C.TEX_W, 2), np.float32)
    ang = np.zeros((C.TEX_H, C.TEX_W), np.float32)
    for r in roads:
        p = np.array(r["points"])
        px, py = C.world_to_px(p[:, 0], p[:, 1])
        pts = np.stack([px, py], axis=1)
        for a, b in zip(pts[:-1], pts[1:]):
            x0 = int(max(0, np.floor(min(a[0], b[0]) - reach)))
            x1 = int(min(C.TEX_W - 1, np.ceil(max(a[0], b[0]) + reach)))
            y0 = int(max(0, np.floor(min(a[1], b[1]) - reach)))
            y1 = int(min(C.TEX_H - 1, np.ceil(max(a[1], b[1]) + reach)))
            if x1 < x0 or y1 < y0:
                continue
            yy, xx = np.mgrid[y0: y1 + 1, x0: x1 + 1]
            cx, cy = xx + 0.5, yy + 0.5
            ab = b - a
            L2 = float(ab @ ab) or 1e-9
            t = np.clip(((cx - a[0]) * ab[0] + (cy - a[1]) * ab[1]) / L2, 0.0, 1.0)
            qx, qy = a[0] + t * ab[0], a[1] + t * ab[1]
            d = np.hypot(cx - qx, cy - qy)
            win = best[y0: y1 + 1, x0: x1 + 1]
            better = (d < win) & (d <= reach)
            win[better] = d[better]
            off[y0: y1 + 1, x0: x1 + 1, 0][better] = (qx - cx)[better]
            off[y0: y1 + 1, x0: x1 + 1, 1][better] = (qy - cy)[better]
            ang[y0: y1 + 1, x0: x1 + 1][better] = math.atan2(ab[1], ab[0]) % math.pi
    out = np.zeros((C.TEX_H, C.TEX_W, 4), np.uint8)
    out[..., 0] = np.clip(np.round(off[..., 0] * 32.0 + 128.0), 0, 255)
    out[..., 1] = np.clip(np.round(off[..., 1] * 32.0 + 128.0), 0, 255)
    out[..., 2] = np.clip(np.round(ang / math.pi * 255.0), 0, 255)
    out[..., 3] = np.where(np.isfinite(best), 255, 0)
    return out


# ------------------------------------------------------------------ villaggi, porti, campi

def pick_hamlets(provs, meta, labels, land, km, forest, coast_px, rng):
    out = {}
    for p in provs:
        L = meta["provinces"][p["id"]]["index"]
        cx, cz = meta["provinces"][p["id"]]["city"]
        area = meta["provinces"][p["id"]]["area_km2"]
        want = 1 if area < 25000 else (2 if area < 70000 else 3)
        ok = (labels == L) & land & (km < 1.0) & (forest < 0.35) & (coast_px > 3.0)
        ys, xs = np.nonzero(ok)
        if len(xs) == 0:
            out[p["id"]] = []
            continue
        wx, wz = C.px_to_world(xs + 0.5, ys + 0.5)
        chosen = []
        dmin = np.hypot(wx - cx, wz - cz)
        dmin[dmin < 3.5] = -1.0
        for _ in range(want):
            score = np.where(dmin > 0, np.minimum(dmin, 9.0) + rng.random(len(dmin)) * 1.5, -1.0)
            i = int(np.argmax(score))
            if score[i] < 3.5:
                break
            chosen.append([round(float(wx[i]), 2), round(float(wz[i]), 2)])
            d = np.hypot(wx - wx[i], wz - wz[i])
            dmin = np.where(dmin > 0, np.minimum(dmin, np.where(d < 3.5, -1.0, d)), dmin)
            dmin[d < 3.5] = -1.0
        out[p["id"]] = chosen
    return out


def pick_ports(provs, meta, coast_sd):
    """Porto: punto di costa più vicino alla città (entro 3 unità), rivolto verso il mare."""
    out = {}
    gy, gx = np.gradient(ndimage.gaussian_filter(coast_sd, 1.5))
    for p in provs:
        if not p.get("coastal"):
            continue
        cx, cz = meta["provinces"][p["id"]]["city"]
        px, py = C.world_to_px(cx, cz)
        r = 14
        x0, y0 = int(px) - r, int(py) - r
        win = coast_sd[max(0, y0): y0 + 2 * r + 1, max(0, x0): x0 + 2 * r + 1]
        yy, xx = np.mgrid[max(0, y0): max(0, y0) + win.shape[0], max(0, x0): max(0, x0) + win.shape[1]]
        sea = (win < -0.6) & (win > -4.0)
        if not sea.any():
            continue
        d = np.hypot(xx - px, yy - py)
        d[~sea] = 1e9
        i = np.unravel_index(int(np.argmin(d)), d.shape)
        if d[i] > r:
            continue
        sx, sy = xx[i] + 0.5, yy[i] + 0.5
        # verso il mare = contro il gradiente della distanza dalla costa (positiva sulla terra)
        ang = math.atan2(-gy[yy[i], xx[i]], -gx[yy[i], xx[i]])
        wx, wz = C.px_to_world(sx, sy)
        out[p["id"]] = [round(float(wx), 2), round(float(wz), 2), round(float(ang), 3)]
    return out


def farmland(provs, meta, hamlets, land, labels, km, forest, road_d, sandy, rng):
    H, W = land.shape
    yy, xx = np.mgrid[0:H, 0:W]
    wx, wz = C.px_to_world(xx + 0.5, yy + 0.5)
    f = np.zeros((H, W), np.float32)
    near_city = np.zeros((H, W), np.float32)
    for p in provs:
        cx, cz = meta["provinces"][p["id"]]["city"]
        rad = 1.9 + p["population"] / 240.0 + p.get("fertility", 2) * 0.3
        d = np.hypot(wx - cx, wz - cz)
        f = np.maximum(f, 1.0 - C.smoothstep(rad * 0.55, rad, d))
        near_city = np.maximum(near_city, 1.0 - C.smoothstep(3.5, 6.5, d))
        for hx, hz in hamlets.get(p["id"], []):
            dh = np.hypot(wx - hx, wz - hz)
            f = np.maximum(f, 1.0 - C.smoothstep(0.6, 1.3, dh))
    # lungo le strade vicino alle città
    f = np.maximum(f, (1.0 - C.smoothstep(0.8, 2.2, road_d)) * near_city * 0.8)
    n = fbm((H, W), 18, 3, seed=77)
    f = f * C.smoothstep(0.25, 0.55, n + f * 0.35)
    f *= land & (labels != C.NEUTRAL)
    f *= (1.0 - C.smoothstep(0.7, 1.3, km)) * (1.0 - C.smoothstep(0.25, 0.5, forest)) * (1.0 - sandy * 0.85)
    return np.clip(f, 0.0, 1.0)


# ------------------------------------------------------------------ alberi

def trees(forest, temperate, km, lat, land, farm, road_d, small_h, rng):
    H, W = forest.shape
    scatter = 0.05 * temperate * land * (1.0 - farm) * (km < 1.6)
    dens = np.maximum(forest, scatter)
    dens *= (1.0 - farm * 0.9) * C.smoothstep(0.8, 1.6, road_d)
    # boschi fitti dove la maschera è forte, alberi sparsi altrove
    lam = (C.smoothstep(0.12, 0.6, dens) * 1.6 + dens * 0.3) * TREES_PER_PX
    counts = rng.poisson(lam)
    ys, xs = np.nonzero(counts)
    reps = counts[ys, xs]
    ys = np.repeat(ys, reps)
    xs = np.repeat(xs, reps)
    n = len(xs)
    px = xs + rng.random(n)
    py = ys + rng.random(n)
    wx, wz = C.px_to_world(px, py)
    y = height_at(small_h, wx, wz) - 0.004
    k = km[ys, xs]
    la = lat[ys, xs]
    t = temperate[ys, xs]
    # 0 latifoglia, 1 conifera, 2 pino domestico (mediterraneo)
    r = rng.random(n)
    kind = np.where((k > 0.9) | (la > 50.5) | (r < 0.18 * t), 1, 0)
    kind = np.where((t < 0.45) & (k < 0.7) & (r < 0.55), 2, kind)
    scale = rng.uniform(0.3, 0.42, n) * np.where(kind == 1, 1.08, 1.0)
    yaw = rng.uniform(0, math.tau, n)
    tint = rng.uniform(0.82, 1.12, n)
    return wx, y, wz, kind, scale, yaw, tint


def pack_trees(wx, wy, wz, kind, scale, yaw, tint, rng):
    """Alberi raggruppati in blocchi di CHUNK unità; il gioco costruisce il MultiMesh di un blocco
    solo quando la telecamera si avvicina. In ogni blocco l'ordine è casuale: con meno
    vegetazione (preset più bassi) il gioco usa solo i primi."""
    cxs = np.floor((wx - C.X_MIN) / CHUNK).astype(int)
    czs = np.floor((wz - C.Z_MIN) / CHUNK).astype(int)
    key = czs * 10000 + cxs
    order = np.lexsort((rng.random(len(wx)), key))
    ks = key[order]
    starts = np.flatnonzero(np.r_[True, np.diff(ks) != 0])
    ends = np.r_[starts[1:], len(ks)]
    buf = np.stack([wx[order], wy[order], wz[order], scale[order], yaw[order],
                    kind[order] + tint[order] * 0.1], axis=1).astype(np.float32)
    chunks = []
    for a, b in zip(starts, ends):
        k = int(ks[a])
        chunks.append({
            "x": round(C.X_MIN + (k % 10000) * CHUNK, 2), "z": round(C.Z_MIN + (k // 10000) * CHUNK, 2),
            "offset": int(a), "count": int(b - a), "y_max": round(float(wy[order[a:b]].max()) + 0.4, 2),
        })
    return chunks, buf


def main():
    t0 = time.time()
    rng = np.random.default_rng(2026)
    prov_data = C.load_json(os.path.join(C.OUT_DATA, "provinces.json"))
    provs = prov_data["provinces"]
    meta = C.load_json(os.path.join(C.OUT_DATA, "campaign_map.json"))
    index = {pid: v["index"] for pid, v in meta["provinces"].items()}
    ids_img = np.array(Image.open(os.path.join(C.OUT_ASSETS, "province_ids.png")).convert("RGBA"))
    labels = ids_img[..., 0].astype(np.int32)
    land = ids_img[..., 2] > 127
    fields = np.array(Image.open(os.path.join(C.OUT_ASSETS, "province_fields.png")).convert("RGBA"))
    coast_sd = (fields[..., 1].astype(np.float32) - 128.0) / 6.0
    lakes = fields[..., 2] > 127
    albedo = np.array(Image.open(os.path.join(C.OUT_ASSETS, "terrain_albedo.png")).convert("RGB"))
    small_h, heights = load_heights()
    log("dati letti (%.1f s)" % (time.time() - t0))

    forest, temperate, km, lat = forest_density(labels, provs, index, heights)
    forest *= land
    rgb = albedo.astype(np.float32) / 255.0
    sandy = C.smoothstep(0.05, 0.16, rgb[..., 0] - rgb[..., 2]) * C.smoothstep(0.55, 0.75, rgb[..., 0]) * land
    roads = build_roads(provs, meta, land, km, lakes, sandy, coast_sd, prov_data.get("straits", []))
    log("%d strade (%.1f s)" % (len(roads), time.time() - t0))
    road_d = road_field(roads)
    hamlets = pick_hamlets(provs, meta, labels, land, km, forest, coast_sd, rng)
    ports = pick_ports(provs, meta, coast_sd)
    farm = farmland(provs, meta, hamlets, land, labels, km, forest, road_d, sandy, rng)
    log("%d villaggi, %d porti (%.1f s)" % (sum(len(v) for v in hamlets.values()), len(ports), time.time() - t0))

    tw = trees(forest, temperate, km, lat, land, farm, road_d, small_h, rng)
    chunks, buf = pack_trees(*tw, rng)
    with open(os.path.join(C.OUT_ASSETS, "trees.bin"), "wb") as f:
        f.write(buf.astype("<f4").tobytes())
    log("%d alberi in %d blocchi (%.1f MB)" % (len(buf), len(chunks), buf.nbytes / 1e6))

    det = np.zeros((C.TEX_H, C.TEX_W, 4), np.uint8)
    det[..., 0] = np.clip(road_d * ROAD_SCALE, 0, 255).astype(np.uint8)
    det[..., 1] = np.clip(farm * 255.0 + 0.5, 0, 255).astype(np.uint8)
    det[..., 3] = 255
    Image.fromarray(det, "RGBA").save(os.path.join(C.OUT_ASSETS, "details.png"), optimize=True)
    Image.fromarray(road_vectors(roads), "RGBA").save(os.path.join(C.OUT_ASSETS, "roads.png"), optimize=True)

    styles = {p["id"]: STYLE_BY_PROVINCE.get(p["id"], STYLE_BY_REGION.get(p["region"], "mediterraneo")) for p in provs}
    out = {
        "version": 1,
        "generated_by": "tools/map/generate_details.py",
        "styles": styles,
        "road_scale": ROAD_SCALE,
        "roads": roads,
        "hamlets": hamlets,
        "ports": ports,
        "trees": {"file": "res://assets/map/trees.bin", "floats_per_instance": FLOATS_PER_TREE,
                  "chunk_size": CHUNK, "total": int(len(buf)), "chunks": chunks},
    }
    with open(os.path.join(C.OUT_DATA, "campaign_details.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
        f.write("\n")
    log("fatto in %.1f s" % (time.time() - t0))


if __name__ == "__main__":
    main()
