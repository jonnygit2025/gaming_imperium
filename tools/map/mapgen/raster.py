"""Rasterizzazione di poligoni e linee Natural Earth sulla griglia della mappa."""
from __future__ import annotations

import numpy as np
from PIL import Image, ImageDraw

from .common import TEX_W, TEX_H, lonlat_to_px, iter_polygons, iter_lines, ring_bbox, in_area


def _ring_px(ring, scale):
    a = np.asarray(ring, dtype=np.float64)
    px, py = lonlat_to_px(a[:, 0], a[:, 1], scale)
    return list(zip(px.tolist(), py.tolist()))


def polygons_mask(features, scale=1, select=None):
    """Maschera booleana (H*scale, W*scale) dei poligoni scelti (buchi compresi)."""
    w, h = TEX_W * scale, TEX_H * scale
    img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(img)
    for f in features:
        if select is not None and not select(f):
            continue
        for rings in iter_polygons(f["geometry"]):
            if not in_area(ring_bbox(rings[0])):
                continue
            draw.polygon(_ring_px(rings[0], scale), fill=255)
            for hole in rings[1:]:
                draw.polygon(_ring_px(hole, scale), fill=0)
    return np.asarray(img) > 127


def lines_mask(features, scale=1, width=1, select=None):
    w, h = TEX_W * scale, TEX_H * scale
    img = Image.new("L", (w, h), 0)
    draw = ImageDraw.Draw(img)
    for f in features:
        if select is not None and not select(f):
            continue
        wf = width(f) if callable(width) else width
        for line in iter_lines(f["geometry"]):
            if len(line) < 2 or not in_area(ring_bbox(line)):
                continue
            draw.line(_ring_px(line, scale), fill=255, width=max(1, int(round(wf))), joint="curve")
    return np.asarray(img) > 127


def downsample_mean(a, factor):
    h, w = a.shape[0] // factor, a.shape[1] // factor
    return a[: h * factor, : w * factor].reshape(h, factor, w, factor).mean(axis=(1, 3))
