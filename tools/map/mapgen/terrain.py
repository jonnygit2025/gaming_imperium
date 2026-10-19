"""Rilievo, colori del terreno, texture delle province e mesh low-poly del terreno."""
from __future__ import annotations

import struct

import numpy as np
from scipy import ndimage
from scipy.spatial import Delaunay

from . import common as C
from .noise import fbm, ridged

# Ampiezza delle colline (km) secondo il terreno della provincia.
HILL_KM = {"pianura": 0.06, "colline": 0.35, "montagna": 0.75, "bosco": 0.16, "paludi": 0.01, "deserto": 0.12}
NEUTRAL_HILL_KM = 0.18


def _terrain_map(labels, provs, index, table, neutral_value):
    lut = np.full(256, neutral_value, np.float32)
    lut[0] = 0.0
    for p in provs:
        lut[index[p["id"]]] = table[p["terrain"]]
    return lut[labels]


def height_field(land, coast_sd, mtn_h, mtn_core, plateau, desert, labels, provs, index, lakes):
    """Quote in unità di gioco (0 = livello del mare)."""
    shape = land.shape
    n_mid = fbm(shape, 96, 5, seed=11)
    n_hill = fbm(shape, 28, 4, seed=12)
    rid = ridged(shape, 36, 5, seed=13)
    n_dune = fbm(shape, 10, 3, seed=14)
    inland = C.smoothstep(0.0, 90.0, coast_sd)
    near_coast = C.smoothstep(0.0, 14.0, coast_sd)

    amp = _terrain_map(labels, provs, index, HILL_KM, NEUTRAL_HILL_KM)
    amp = ndimage.gaussian_filter(amp, 16.0)

    km = 0.04 + 0.28 * inland * (0.5 + n_mid)
    km += plateau * C.smoothstep(0.0, 30.0, coast_sd)
    km += amp * (0.45 * n_hill + 0.75 * rid * rid) * near_coast
    massif = fbm(shape, 60, 3, seed=15)
    km += mtn_h * (0.12 + 1.05 * rid ** 1.4) * (0.55 + 0.7 * massif) * C.smoothstep(-2.0, 8.0, coast_sd)
    km += desert * 0.06 * n_dune
    land_u = km * C.VERTICAL * C.smoothstep(0.0, 2.5, coast_sd) + 0.03 * np.clip(coast_sd, 0.0, 1.0)

    sea_u = -(0.12 * np.clip(-coast_sd, 0.0, 1.0) + 1.4 * C.smoothstep(0.0, 30.0, -coast_sd))
    h = np.where(coast_sd >= 0.0, land_u, sea_u).astype(np.float32)

    # Laghi: conca piatta poco sotto il bordo.
    if lakes.any():
        blur = ndimage.gaussian_filter(h, 4.0)
        lk = ndimage.binary_dilation(lakes, iterations=1)
        h[lk] = np.maximum(blur[lk] - 0.03, 0.01)
    return h


def flatten_cities(h, provs, land):
    """Spiana un piccolo cerchio attorno a ogni città, così i modelli poggiano bene."""
    out = h.copy()
    yy, xx = np.mgrid[0 : h.shape[0], 0 : h.shape[1]]
    for p in provs:
        cx, cy = C.lonlat_to_px(p["lon"], p["lat"])
        x0, y0 = int(cx) - 12, int(cy) - 12
        x1, y1 = int(cx) + 13, int(cy) + 13
        sub = (slice(max(0, y0), min(h.shape[0], y1)), slice(max(0, x0), min(h.shape[1], x1)))
        d = np.hypot(xx[sub] - float(cx), yy[sub] - float(cy))
        core = d < 3.0
        target = float(np.median(out[sub][core & land[sub]])) if (core & land[sub]).any() else 0.04
        target = max(target, 0.05)
        w = 1.0 - C.smoothstep(3.0, 8.0, d)
        region = out[sub]
        is_land = land[sub]
        region[is_land] = region[is_land] * (1 - w[is_land]) + target * w[is_land]
        out[sub] = region
    return out


# ------------------------------------------------------------------ colori

def _srgb(c):
    return np.array(c, np.float32) / 255.0


def albedo(land, coast_sd, heights, mtn_core, desert, labels, provs, index, lakes, rivers):
    H, W = land.shape
    lat = (C.LAT0 - (C.Z_MIN + (np.arange(H) + 0.5) * C.PX) * C.UNIT_KM / C.KM_PER_DEG)[:, None] * np.ones((1, W))
    km = np.maximum(heights, 0.0) / C.VERTICAL
    n1 = fbm(land.shape, 22, 4, seed=21)
    n2 = fbm(land.shape, 12, 3, seed=22)
    n3 = fbm(land.shape, 160, 3, seed=23)

    dry = _srgb((154, 150, 92))       # macchia mediterranea in estate
    green = _srgb((98, 126, 66))      # pianure temperate
    forest = _srgb((54, 82, 44))
    marsh = _srgb((88, 106, 70))
    steppe = _srgb((168, 156, 104))
    sand = _srgb((214, 186, 136))
    rock_desert = _srgb((178, 140, 98))
    rock = _srgb((124, 114, 100))
    farm = _srgb((176, 160, 98))

    temperate = C.smoothstep(40.0, 47.5, lat + (n3 - 0.5) * 3.0)
    col = dry[None, None, :] * (1 - temperate[..., None]) + green[None, None, :] * temperate[..., None]
    # campi coltivati e variazioni
    fields = C.smoothstep(0.55, 0.75, n2) * (1 - C.smoothstep(0.4, 1.0, km)) * 0.35
    col = col * (1 - fields[..., None]) + farm * fields[..., None]

    def lut(table, neutral):
        return _terrain_map(labels, provs, index, table, neutral)

    forest_w = lut({"pianura": 0.08, "colline": 0.2, "montagna": 0.25, "bosco": 0.5, "paludi": 0.15, "deserto": 0.0}, 0.3)
    forest_w = ndimage.gaussian_filter(forest_w, 10.0)
    forest_w = forest_w * (0.4 + 0.6 * temperate) + 0.18 * temperate
    forest_mask = np.clip((n1 - (1.0 - forest_w)) * 6.0, 0.0, 0.85) * (1 - C.smoothstep(1.6, 2.4, km))
    col = col * (1 - forest_mask[..., None]) + forest * forest_mask[..., None]

    marsh_w = ndimage.gaussian_filter(lut({"pianura": 0, "colline": 0, "montagna": 0, "bosco": 0, "paludi": 1.0, "deserto": 0}, 0), 8.0)
    marsh_w *= 1 - C.smoothstep(0.2, 0.6, km)
    col = col * (1 - 0.7 * marsh_w[..., None]) + marsh * 0.7 * marsh_w[..., None]

    steppe_w = C.smoothstep(0.25, 0.6, desert) * 0.8
    col = col * (1 - steppe_w[..., None]) + steppe * steppe_w[..., None]
    sand_w = C.smoothstep(0.55, 0.9, desert)
    dcol = sand * (1 - n1[..., None] * 0.7) + rock_desert * (n1[..., None] * 0.7)
    col = col * (1 - sand_w[..., None]) + dcol * sand_w[..., None]

    rock_w = C.smoothstep(1.1, 2.0, km + (n2 - 0.5) * 0.4) * np.clip(mtn_core * 1.5, 0.0, 1.0)
    col = col * (1 - rock_w[..., None]) + rock * rock_w[..., None]

    # Nilo e oasi: striscia verde lungo il fiume nel deserto
    riv = np.clip(rivers, 0.0, 1.0)
    oasis = ndimage.gaussian_filter(riv, 4.0) * 4.0 * sand_w
    col = col * (1 - np.clip(oasis, 0, 0.85)[..., None]) + green * np.clip(oasis, 0, 0.85)[..., None]

    # variazione di luminosità a larga scala
    col *= (0.9 + 0.2 * n3)[..., None]
    # Ombreggiatura del rilievo "cotta" nella texture (luce da nord-ovest, come nelle carte):
    # dà dettaglio alle montagne più fine della mesh, a costo zero durante il gioco.
    col *= hillshade(heights)[..., None]
    # fiumi e laghi
    water = _srgb((64, 96, 118))
    rv = np.clip(riv * 1.3, 0.0, 0.9)
    col = col * (1 - rv[..., None]) + water * rv[..., None]
    lk = ndimage.gaussian_filter(lakes.astype(np.float32), 0.7)
    col = col * (1 - lk[..., None]) + _srgb((58, 92, 116)) * lk[..., None]

    # Il colore della terra si estende nel mare (niente aloni blu sulla costa filtrata).
    _, (iy, ix) = ndimage.distance_transform_edt(~land, return_indices=True)
    col = col[iy, ix]
    return np.clip(col * 255.0 + 0.5, 0, 255).astype(np.uint8)


def hillshade(heights, strength=1.6):
    """Moltiplicatore 0,55..1,3 (1 = pianura) per una luce da nord-ovest alta 40°."""
    h = ndimage.gaussian_filter(np.maximum(heights, 0.0), 0.8)
    gy, gx = np.gradient(h, C.PX)
    nx, ny, nz = -gx, np.ones_like(h), -gy          # normale (x est, y su, z sud)
    norm = np.sqrt(nx * nx + ny * ny + nz * nz)
    az, alt = np.radians(315.0), np.radians(40.0)
    lx, ly, lz = np.cos(alt) * np.sin(az), np.sin(alt), -np.cos(alt) * np.cos(az)
    lit = (nx * lx + ny * ly + nz * lz) / norm
    rel = lit - ly
    return np.clip(1.0 + strength * rel, 0.55, 1.3).astype(np.float32)


def minimap(albedo_img, heights, land, width=512):
    from PIL import Image
    H, W = land.shape
    hgt = width * H // W
    gy, gx = np.gradient(ndimage.gaussian_filter(heights, 2.0))
    shade = np.clip(1.0 - (gx * 1.2 - gy * 1.2) * 2.5, 0.6, 1.3)
    col = albedo_img.astype(np.float32) / 255.0 * shade[..., None]
    sea = np.array([0.13, 0.25, 0.36], np.float32)
    col = np.where(land[..., None], col, sea)
    img = Image.fromarray(np.clip(col * 255, 0, 255).astype(np.uint8)).resize((width, hgt), Image.LANCZOS)
    return np.asarray(img)


def water_noise(size=256):
    """Due rumori ripetibili (RG e BA) per perturbare le normali dell'acqua."""
    out = np.zeros((size, size, 4), np.uint8)
    rng = np.random.default_rng(31)
    for ch, cell in ((0, 32), (2, 16)):
        acc = np.zeros((size, size), np.float32)
        amp = 1.0
        c = cell
        while c >= 4:
            g = size // c
            grid = rng.random((g, g)).astype(np.float32)
            up = ndimage.zoom(grid, c, order=3, mode="grid-wrap")
            acc += amp * up[:size, :size]
            amp *= 0.5
            c //= 2
        acc = (acc - acc.min()) / (acc.max() - acc.min())
        gy, gx = np.gradient(np.pad(acc, 1, mode="wrap"))
        gx, gy = gx[1:-1, 1:-1], gy[1:-1, 1:-1]
        s = 0.5 / max(np.abs(gx).max(), np.abs(gy).max())
        out[..., ch] = np.clip(128 + gx * s * 255, 0, 255).astype(np.uint8)
        out[..., ch + 1] = np.clip(128 + gy * s * 255, 0, 255).astype(np.uint8)
    return out


# ------------------------------------------------------------------ texture delle province

def province_textures(labels, land, coast_sd, lakes=None):
    """(ids RGBA8, campi RGBA8). Vedi generate_map.py per il significato dei canali."""
    H, W = labels.shape
    # Etichette estese di qualche pixel nel mare (la costa della mesh e della texture non coincidono
    # al pixel: così il colore di fazione non si interrompe prima dell'acqua).
    sea = labels == C.SEA
    dist, (iy, ix) = ndimage.distance_transform_edt(sea, return_indices=True)
    dl = labels.copy()
    near = sea & (dist <= 12)
    dl[near] = labels[iy[near], ix[near]]

    border = np.full((H, W), 255.0, np.float32)
    neighbor = np.zeros((H, W), np.uint8)
    ids = [v for v in np.unique(dl) if v != 0]
    pad = 24
    for L in ids:
        ys, xs = np.nonzero(dl == L)
        y0, y1 = max(0, ys.min() - pad), min(H, ys.max() + pad + 1)
        x0, x1 = max(0, xs.min() - pad), min(W, xs.max() + pad + 1)
        sub = dl[y0:y1, x0:x1]
        other = (sub != L) & (sub != 0)
        if not other.any():
            continue
        d, (oy, ox) = ndimage.distance_transform_edt(~other, return_indices=True)
        mine = sub == L
        bsub = border[y0:y1, x0:x1]
        nsub = neighbor[y0:y1, x0:x1]
        dd = np.clip(d - 0.5, 0.0, 16.0)
        bsub[mine] = np.minimum(bsub[mine], dd[mine] * 15.9)
        nsub[mine] = sub[oy[mine], ox[mine]]
    # Leggera sfocatura del campo: le linee seguono il confine senza i gradini dei pixel.
    border = ndimage.gaussian_filter(border, 0.9)
    ids_rgba = np.zeros((H, W, 4), np.uint8)
    ids_rgba[..., 0] = dl.astype(np.uint8)
    ids_rgba[..., 1] = neighbor
    ids_rgba[..., 2] = np.where(land, 255, 0).astype(np.uint8)
    ids_rgba[..., 3] = 255
    fields = np.zeros((H, W, 4), np.uint8)
    fields[..., 0] = np.clip(border, 0, 255).astype(np.uint8)
    fields[..., 1] = np.clip(128.0 + coast_sd * 6.0, 0, 255).astype(np.uint8)
    if lakes is not None:
        fields[..., 2] = np.clip(ndimage.gaussian_filter(lakes.astype(np.float32), 0.8) * 255, 0, 255).astype(np.uint8)
    fields[..., 3] = 255
    return ids_rgba, fields


# ------------------------------------------------------------------ mesh del terreno

def _bilinear(a, x, y):
    H, W = a.shape
    x = np.clip(x - 0.5, 0, W - 1.001)
    y = np.clip(y - 0.5, 0, H - 1.001)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    return (a[y0, x0] * (1 - fx) * (1 - fy) + a[y0, x0 + 1] * fx * (1 - fy)
            + a[y0 + 1, x0] * (1 - fx) * fy + a[y0 + 1, x0 + 1] * fx * fy)


def _thin(points, cell):
    """Tiene un punto per cella di griglia (spaziatura minima ~cell)."""
    if len(points) == 0:
        return points
    keys = np.floor(points / cell).astype(np.int64)
    _, keep = np.unique(keys[:, 0] * 100000 + keys[:, 1], return_index=True)
    return points[np.sort(keep)]


def _contour_points(field, level):
    """Punti dove `field` attraversa `level` sui lati orizzontali e verticali dei pixel."""
    f = field - level
    pts = []
    a, b = f[:, :-1], f[:, 1:]
    m = (a * b) < 0
    y, x = np.nonzero(m)
    t = a[m] / (a[m] - b[m])
    pts.append(np.stack([x + 0.5 + t, y + 0.5], 1))
    a, b = f[:-1, :], f[1:, :]
    m = (a * b) < 0
    y, x = np.nonzero(m)
    t = a[m] / (a[m] - b[m])
    pts.append(np.stack([x + 0.5, y + 0.5 + t], 1))
    return np.concatenate(pts)


def _jitter_grid(mask, spacing, rng):
    H, W = mask.shape
    ys = np.arange(spacing / 2, H, spacing)
    xs = np.arange(spacing / 2, W, spacing)
    gx, gy = np.meshgrid(xs, ys)
    pts = np.stack([gx.ravel(), gy.ravel()], 1)
    pts += (rng.random(pts.shape) - 0.5) * spacing * 0.8
    pts[:, 0] = np.clip(pts[:, 0], 0.5, W - 0.5)
    pts[:, 1] = np.clip(pts[:, 1], 0.5, H - 0.5)
    sel = mask[pts[:, 1].astype(int), pts[:, 0].astype(int)]
    return pts[sel]


COAST_Y = -0.03


def terrain_mesh(heights, coast_sd, mtn_core, land):
    """Triangolazione di Delaunay su punti adattivi: fitta su coste e montagne, rada in pianura.
    Restituisce (vertici Nx3 in unità di gioco, indici Mx3)."""
    rng = np.random.default_rng(41)
    H, W = heights.shape
    km = np.maximum(heights, 0) / C.VERTICAL
    relief = ndimage.maximum_filter(km, 5) - ndimage.minimum_filter(km, 5)
    band = coast_sd > -7.0
    pts = [
        _jitter_grid(band, 6.5, rng),
        _jitter_grid(band & ((relief > 0.18) | (mtn_core > 0.35)), 4.4, rng),
        _jitter_grid(band & ((relief > 0.5) | (mtn_core > 0.7)), 3.1, rng),
        _thin(_contour_points(coast_sd, 0.0), 1.6),
        _thin(_contour_points(coast_sd, 1.6), 2.6),
        _thin(_contour_points(coast_sd, -2.5), 3.2),
        _thin(_contour_points(coast_sd, -6.0), 5.0),
    ]
    # bordo della mappa
    e = np.arange(0.0, W + 0.01, 4.0)
    f = np.arange(0.0, H + 0.01, 4.0)
    pts.append(np.stack([e, np.zeros_like(e)], 1))
    pts.append(np.stack([e, np.full_like(e, H)], 1))
    pts.append(np.stack([np.zeros_like(f), f], 1))
    pts.append(np.stack([np.full_like(f, W), f], 1))
    P = np.concatenate(pts)
    P[:, 0] = np.clip(P[:, 0], 0, W)
    P[:, 1] = np.clip(P[:, 1], 0, H)
    P = _thin(P, 0.9)
    edge = (P[:, 0] <= 0.01) | (P[:, 0] >= W - 0.01) | (P[:, 1] <= 0.01) | (P[:, 1] >= H - 0.01)
    on_edge_band = edge & (_bilinear(coast_sd, P[:, 0], P[:, 1]) > -7.0)
    keep = ~edge | on_edge_band
    P = P[keep]

    tri = Delaunay(P)
    T = tri.simplices
    sd = _bilinear(coast_sd, P[:, 0], P[:, 1])
    hv = _bilinear(heights, P[:, 0], P[:, 1])
    # i punti della costa stanno appena sotto il livello del mare: un triangolo con i tre
    # vertici sulla costa (stretti, golfi) resta così sotto l'acqua invece di coprirla
    hv[np.abs(sd) < 0.05] = COAST_Y
    # via i triangoli di mare aperto e quelli troppo lunghi in acqua
    cx = P[T].mean(axis=1)
    csd = _bilinear(coast_sd, cx[:, 0], cx[:, 1])
    vmax_sd = sd[T].max(axis=1)
    elen = np.max(np.linalg.norm(P[T] - P[np.roll(T, 1, axis=1)], axis=2), axis=1)
    keep_t = ~((csd < -6.5) | ((vmax_sd < 0.5) & (elen > 14.0)))
    T = T[keep_t]
    # Triangoli di terra stretta con tutti i vertici sulla costa: si aggiunge il baricentro
    # con la quota della terra, così la striscia non finisce sott'acqua.
    cx = P[T].mean(axis=1)
    csd = _bilinear(coast_sd, cx[:, 0], cx[:, 1])
    thin = (csd > 0.3) & (hv[T].max(axis=1) <= 0.0)
    if thin.any():
        base = len(P)
        newp = cx[thin]
        newh = np.maximum(_bilinear(heights, newp[:, 0], newp[:, 1]), 0.02)
        P = np.concatenate([P, newp])
        hv = np.concatenate([hv, newh])
        tt = T[thin]
        ids = base + np.arange(len(tt))
        split = np.concatenate([
            np.stack([tt[:, 0], tt[:, 1], ids], 1),
            np.stack([tt[:, 1], tt[:, 2], ids], 1),
            np.stack([tt[:, 2], tt[:, 0], ids], 1)])
        T = np.concatenate([T[~thin], split])
    used = np.unique(T)
    remap = -np.ones(len(P), np.int64)
    remap[used] = np.arange(len(used))
    P, hv, T = P[used], hv[used], remap[T]
    wx, wz = C.px_to_world(P[:, 0], P[:, 1])
    V = np.stack([wx, hv, wz], 1).astype(np.float32)
    # orientamento: in Godot le facce frontali sono in senso orario visto da sopra (+Y)
    a, b, c = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    n_y = (b[:, 2] - a[:, 2]) * (c[:, 0] - a[:, 0]) - (b[:, 0] - a[:, 0]) * (c[:, 2] - a[:, 2])
    flip = n_y > 0
    T[flip] = T[flip][:, [0, 2, 1]]
    return V, T.astype(np.int32)


def vertex_normals(V, T):
    """Normali lisce pesate per area (in Godot le facce frontali sono in senso orario)."""
    a, b, c = V[T[:, 0]], V[T[:, 1]], V[T[:, 2]]
    fn = np.cross(c - a, b - a)
    N = np.zeros_like(V)
    for k in range(3):
        np.add.at(N, T[:, k], fn)
    N /= np.maximum(np.linalg.norm(N, axis=1, keepdims=True), 1e-9)
    return N.astype(np.float32)


def save_mesh(V, T, path):
    """Formato semplice letto da tools/map/build_map_resources.gd:
    'RGTM', n_vertici, n_triangoli, posizioni xyz, normali xyz, indici."""
    N = vertex_normals(V, T)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sii", b"RGTM", len(V), len(T)))
        f.write(V.astype("<f4").tobytes())
        f.write(N.astype("<f4").tobytes())
        f.write(T.astype("<i4").tobytes())


def save_heights(heights, path, width=1024):
    """Griglia di quote ridotta per le richieste della CPU (telecamera, selezione, posizioni)."""
    H, W = heights.shape
    hh = width * H // W
    zy, zx = hh / H, width / W
    small = ndimage.zoom(heights, (zy, zx), order=1).astype("<f4")
    small = small[:hh, :width]
    with open(path, "wb") as f:
        f.write(struct.pack("<4sii", b"RGTH", small.shape[1], small.shape[0]))
        f.write(small.tobytes())
