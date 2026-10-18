"""Regioni delle province: diagramma di Voronoi "geodetico" sulla terraferma, partendo dalle
città, con i vincoli dei confini di provinces.json.

Algoritmo (crescita simultanea alla Dijkstra, su griglia a metà risoluzione):
- ogni provincia parte dalla sua città (più eventuali semi extra, es. la Corsica);
- attraversare le montagne costa di più, così i confini seguono le catene (Pirenei, Alpi...);
- un pixel NON può diventare della provincia A se tocca già una provincia B che non confina con A
  nel JSON: resta libero e lo può prendere una terza provincia confinante con entrambe;
- oltre una distanza massima dalla città la terra resta "terre esterne" (fuori dal gioco);
- le isole senza città prendono la provincia della terra più vicina.
Poi il risultato è portato a piena risoluzione e ammorbidito, rispettando sempre i vincoli.
"""
from __future__ import annotations

import heapq
import math

import numpy as np
from scipy import ndimage

from .common import TEX_W, TEX_H, PX, UNIT_KM, SEA, NEUTRAL, lonlat_to_px

# Semi aggiuntivi (lon, lat) per terre che appartengono a una provincia senza esserne il centro.
EXTRA_SEEDS = {
    "sardinia": [(9.05, 42.15)],                               # Corsica
    "achaea": [(24.9, 35.2)],                                  # Creta
    "syria": [(33.2, 35.05)],                                  # Cipro
    "tarraconensis": [(2.95, 39.6), (-0.88, 41.65), (-1.65, 42.8)],  # Baleari, Caesaraugusta, Pompaelo
    "gallaecia": [(-5.6, 42.6), (-4.0, 43.1)],                 # Asturica, Asturie
    "sicilia": [(14.4, 35.9)],                                 # Malta
    "asia": [(28.0, 36.2), (30.7, 36.9), (32.48, 37.87)],      # Rodi, Attalia, Iconium
    "hijaz": [(39.8, 21.45), (38.5, 27.5), (40.5, 28.5)],      # La Mecca, Tabuk, Nafud
    "aegyptus": [(32.65, 25.7), (30.8, 27.8), (32.9, 24.1), (27.2, 31.35)],  # Tebe, Ermopoli, Siene, Paretonio
    "spoletium": [(13.6, 42.85), (14.2, 42.3)],                # Asculum, Teate
    "apulia": [(15.55, 41.45), (16.25, 39.3)],                 # Luceria, Bruttium
    "tingitana": [(-5.55, 34.07), (-2.9, 34.9)],               # Volubilis, Rusadir
    "caesariensis": [(-1.32, 34.88), (0.15, 35.7), (5.06, 36.75)],  # Pomaria, Portus Magnus, Saldae
    "tripolitania": [(14.29, 32.64), (16.6, 31.2), (10.67, 33.53)],  # Leptis Magna, Sirte, Gigthis
    "cyrenaica": [(20.07, 32.1), (19.0, 30.4), (23.9, 32.0)],   # Berenice, golfo della Sirte, Darnis
    "macedonia": [(19.45, 41.32)],                             # Dyrrachium
    "thracia": [(26.56, 41.68), (24.75, 42.15)],               # Hadrianopolis, Philippopolis
    "cappadocia": [(34.9, 36.92), (33.0, 36.4)],               # Tarso, Isauria (Cilicia)
    "aquileia": [(14.5, 46.05)],                               # Emona
    "numidia": [(6.61, 36.37)],                                # Cirta
    "pannonia": [(15.87, 46.42)],                              # Poetovio
    "africa": [(10.64, 35.83), (10.7, 34.75)],                 # Hadrumetum, Thaenae
    "moesia": [(21.9, 43.32), (22.9, 43.8), (20.5, 44.8)],     # Naissus, Ratiaria, Singidunum
    "dalmatia": [(18.5, 43.85), (19.3, 42.8), (14.45, 45.33)],  # Bosnia, Doclea, Tarsatica
    "palaestina": [(35.0, 30.0), (34.3, 31.2)],                # Negev, Gaza
    "phoenice": [(36.4, 32.3), (38.3, 33.0)],                  # Bostra, deserto siriano
    "asoristan": [(43.0, 31.5), (44.4, 31.9)],                 # Kufa/Hira, basso Eufrate
}
# Distanza massima di crescita (km "pesati") da ogni seme.
DEFAULT_REACH_KM = 480.0
REACH_KM = {
    "hijaz": 560.0, "asoristan": 520.0, "aegyptus": 340.0, "cyrenaica": 420.0, "tripolitania": 420.0,
    "tingitana": 400.0, "caesariensis": 420.0, "numidia": 400.0, "pannonia": 430.0, "moesia": 420.0,
    "austrasia": 340.0, "belgica": 280.0, "phoenice": 520.0, "mesopotamia": 480.0,
    "armorica": 300.0, "africa": 420.0, "palaestina": 420.0, "dalmatia": 360.0,
}
MOUNTAIN_COST = 2.0   # costo extra per pixel di montagna piena
DESERT_COST = 0.25


def city_px(provinces, scale=1.0):
    out = {}
    for p in provinces:
        x, y = lonlat_to_px(p["lon"], p["lat"], scale)
        out[p["id"]] = (float(x), float(y))
    return out


def _snap_to_land(land, x, y, max_r=12):
    xi, yi = int(round(x)), int(round(y))
    h, w = land.shape
    if 0 <= yi < h and 0 <= xi < w and land[yi, xi]:
        return xi, yi
    best = None
    for r in range(1, max_r + 1):
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                yy, xx = yi + dy, xi + dx
                if 0 <= yy < h and 0 <= xx < w and land[yy, xx]:
                    d = dx * dx + dy * dy
                    if best is None or d < best[0]:
                        best = (d, xx, yy)
        if best:
            return best[1], best[2]
    raise ValueError("Nessuna terra vicino a (%s, %s)" % (x, y))


def grow(provinces, land_full, mountain_core_full, desert_full):
    ids = [p["id"] for p in provinces]
    index = {pid: i + 1 for i, pid in enumerate(ids)}  # 1..N
    n = len(ids)
    allowed = np.zeros((n + 2, n + 2), bool)
    for p in provinces:
        a = index[p["id"]]
        allowed[a, a] = True
        for q in p["neighbors"]:
            allowed[a, index[q]] = True
            allowed[index[q], a] = True

    # Mezza risoluzione per la crescita.
    f = 2
    land = ndimage.zoom(land_full.astype(np.float32), 1.0 / f, order=1) > 0.5
    mcore = ndimage.zoom(mountain_core_full, 1.0 / f, order=1)
    desert = ndimage.zoom(desert_full, 1.0 / f, order=1)
    h, w = land.shape
    cost_px = (1.0 + MOUNTAIN_COST * mcore + DESERT_COST * desert).astype(np.float64)
    km_per_px = PX * UNIT_KM * f
    label = np.zeros((h, w), np.int32)
    flat_land = land.ravel()
    lab = label.ravel()
    cost = cost_px.ravel()
    reach = np.array([0.0] + [REACH_KM.get(pid, DEFAULT_REACH_KM) / km_per_px for pid in ids])

    heap = []
    seeds = {}
    for p in provinces:
        pts = [(p["lon"], p["lat"])] + EXTRA_SEEDS.get(p["id"], [])
        for k, (lon, lat) in enumerate(pts):
            x, y = lonlat_to_px(lon, lat, 1.0 / f)
            sx, sy = _snap_to_land(land, float(x), float(y))
            heapq.heappush(heap, (0.0, sy * w + sx, index[p["id"]]))
            if k == 0:
                seeds[p["id"]] = (sx * f, sy * f)

    nbr = [(-1, -1, math.sqrt(2)), (-1, 0, 1.0), (-1, 1, math.sqrt(2)), (0, -1, 1.0),
           (0, 1, 1.0), (1, -1, math.sqrt(2)), (1, 0, 1.0), (1, 1, math.sqrt(2))]
    allowed_l = allowed.tolist()
    while heap:
        d, idx, L = heapq.heappop(heap)
        if lab[idx]:
            continue
        y, x = divmod(idx, w)
        ok = True
        for dy, dx, _ in nbr:
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w:
                m = lab[yy * w + xx]
                if m and not allowed_l[L][m]:
                    ok = False
                    break
        if not ok:
            continue
        lab[idx] = L
        c0 = cost[idx]
        for dy, dx, step in nbr:
            yy, xx = y + dy, x + dx
            if 0 <= yy < h and 0 <= xx < w:
                j = yy * w + xx
                if flat_land[j] and not lab[j]:
                    nd = d + step * 0.5 * (c0 + cost[j])
                    if nd <= reach[L]:
                        heapq.heappush(heap, (nd, j, L))
    return label, index, allowed, seeds


def upsample_and_clean(label_half, land_full, allowed):
    """Porta le etichette a piena risoluzione, le ammorbidisce e riapplica i vincoli."""
    h, w = land_full.shape
    lab = np.repeat(np.repeat(label_half, 2, axis=0), 2, axis=1)
    pad_h, pad_w = h - lab.shape[0], w - lab.shape[1]
    if pad_h > 0 or pad_w > 0:
        lab = np.pad(lab, ((0, max(0, pad_h)), (0, max(0, pad_w))), mode="edge")
    lab = lab[:h, :w].copy()
    # Pixel di terra a piena risoluzione senza etichetta: prendono quella del vicino più prossimo
    # (solo se molto vicino: riempie le coste frastagliate perse dal dimezzamento).
    missing = land_full & (lab == 0)
    if missing.any():
        dist, (iy, ix) = ndimage.distance_transform_edt(lab == 0, return_indices=True)
        fill = missing & (dist <= 3)
        lab[fill] = lab[iy[fill], ix[fill]]
    lab[~land_full] = 0
    lab[land_full & (lab == 0)] = NEUTRAL
    lab = smooth_labels(lab, land_full)
    lab[lab == NEUTRAL] = 0
    lab = enforce(lab, allowed)
    return lab


def smooth_labels(lab, land, sigma=1.8):
    """Arrotonda i confini: ogni pixel di terra va alla provincia con più "peso" sfocato attorno.
    Toglie i gradini lasciati dalla crescita a metà risoluzione."""
    H, W = lab.shape
    best = np.zeros((H, W), np.float32)
    out = lab.copy()
    pad = int(sigma * 4) + 2
    for L in np.unique(lab):
        if L == 0:
            continue
        ys, xs = np.nonzero(lab == L)
        y0, y1 = max(0, ys.min() - pad), min(H, ys.max() + pad + 1)
        x0, x1 = max(0, xs.min() - pad), min(W, xs.max() + pad + 1)
        g = ndimage.gaussian_filter((lab[y0:y1, x0:x1] == L).astype(np.float32), sigma)
        bsub = best[y0:y1, x0:x1]
        osub = out[y0:y1, x0:x1]
        upd = (g > bsub) & land[y0:y1, x0:x1]
        bsub[upd] = g[upd]
        osub[upd] = L
    out[~land] = 0
    return out


def majority_filter(lab, land, iterations=1):
    """Moda 3x3 sui pixel di terra: lima i gradini dei confini."""
    for _ in range(iterations):
        pad = np.pad(lab, 1, mode="edge")
        h, w = lab.shape
        stack = np.stack([pad[dy : dy + h, dx : dx + w] for dy in range(3) for dx in range(3)])
        best = lab.copy()
        best_count = np.zeros(lab.shape, np.int32)
        for k in range(9):
            cand = stack[k]
            cnt = (stack == cand[None]).sum(axis=0)
            better = (cnt > best_count) & (cand != 0)
            best[better] = cand[better]
            best_count[better] = cnt[better]
        keep = best_count < 5
        best[keep] = lab[keep]
        best[~land] = 0
        lab = best
    return lab


def forbidden_contacts(lab, allowed):
    """Maschera dei pixel che toccano (8 direzioni) una provincia non confinante."""
    h, w = lab.shape
    bad = np.zeros((h, w), bool)
    pad = np.pad(lab, 1)
    for dy in range(3):
        for dx in range(3):
            if dy == 1 and dx == 1:
                continue
            other = pad[dy : dy + h, dx : dx + w]
            both = (lab > 0) & (other > 0) & (lab != NEUTRAL) & (other != NEUTRAL) & (lab != other)
            ok = allowed[np.where(both, lab, 0), np.where(both, other, 0)]
            bad |= both & ~ok
    return bad


def enforce(lab, allowed):
    for _ in range(10):
        bad = forbidden_contacts(lab, allowed)
        if not bad.any():
            break
        lab[bad] = NEUTRAL
    return lab


def assign_islands(lab, land, max_dist_px=40):
    """Le terre separate senza provincia (isole) prendono quella della terra più vicina."""
    comps, n = ndimage.label(land, structure=np.ones((3, 3)))
    labeled = (lab > 0) & (lab != NEUTRAL)
    has_label = ndimage.maximum(labeled, comps, index=np.arange(1, n + 1))
    dist, (iy, ix) = ndimage.distance_transform_edt(~labeled, return_indices=True)
    sizes = ndimage.sum(np.ones_like(comps), comps, index=np.arange(1, n + 1))
    for c in range(1, n + 1):
        if has_label[c - 1] or sizes[c - 1] > 4000:
            continue
        sel = comps == c
        if dist[sel].min() > max_dist_px:
            continue
        # tutta l'isola alla provincia più vicina al suo punto più vicino
        k = np.argmin(np.where(sel, dist, np.inf))
        y, x = divmod(int(k), lab.shape[1])
        lab[sel] = lab[iy[y, x], ix[y, x]]
    return lab


def remove_fragments(lab, land, min_px=60):
    """Toglie i pezzi staccati di una provincia sulla stessa terra (enclavi spurie)."""
    out = lab.copy()
    for L in np.unique(lab):
        if L in (0, NEUTRAL):
            continue
        comps, n = ndimage.label(lab == L, structure=np.ones((3, 3)))
        if n <= 1:
            continue
        sizes = ndimage.sum(np.ones_like(comps), comps, index=np.arange(1, n + 1))
        biggest = int(np.argmax(sizes)) + 1
        for c in range(1, n + 1):
            if c == biggest:
                continue
            # le isole (componente che coincide con una terra separata) restano
            sel = comps == c
            if sizes[c - 1] < min_px:
                out[sel] = NEUTRAL
    return out


def adjacency(lab, connectivity=4):
    """Coppie di province che si toccano, con il numero di pixel di contatto."""
    pairs = {}
    shifts = [(0, 1), (1, 0)] if connectivity == 4 else [(0, 1), (1, 0), (1, 1), (1, -1)]
    h, w = lab.shape
    for dy, dx in shifts:
        if dx >= 0:
            a, b = lab[0 : h - dy, 0 : w - dx], lab[dy:h, dx:w]
        else:
            a, b = lab[0 : h - dy, -dx:w], lab[dy:h, 0 : w + dx]
        m = (a != b) & (a > 0) & (b > 0) & (a != NEUTRAL) & (b != NEUTRAL)
        aa, bb = a[m], b[m]
        lo, hi = np.minimum(aa, bb), np.maximum(aa, bb)
        keys, counts = np.unique(lo.astype(np.int64) * 1000 + hi, return_counts=True)
        for k, c in zip(keys.tolist(), counts.tolist()):
            pairs[(k // 1000, k % 1000)] = pairs.get((k // 1000, k % 1000), 0) + c
    return pairs
