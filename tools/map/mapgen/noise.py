"""Rumore frattale deterministico con numpy (valori su griglia + interpolazione cubica)."""
from __future__ import annotations

import numpy as np
from scipy import ndimage


def value_noise(shape, cell, rng):
    """Rumore liscio in [0,1] con celle di `cell` pixel."""
    h, w = shape
    gh, gw = int(np.ceil(h / cell)) + 3, int(np.ceil(w / cell)) + 3
    grid = rng.random((gh, gw)).astype(np.float32)
    up = ndimage.zoom(grid, cell, order=3, mode="wrap", prefilter=False)
    oy, ox = int(rng.integers(0, cell)), int(rng.integers(0, cell))
    out = up[oy : oy + h, ox : ox + w]
    return np.clip(out, 0.0, 1.0)


def fbm(shape, base_cell, octaves, seed, gain=0.5):
    rng = np.random.default_rng(seed)
    total = np.zeros(shape, np.float32)
    amp, norm, cell = 1.0, 0.0, float(base_cell)
    for _ in range(octaves):
        c = max(2, int(round(cell)))
        total += amp * value_noise(shape, c, rng)
        norm += amp
        amp *= gain
        cell /= 2.0
    return total / norm


def ridged(shape, base_cell, octaves, seed):
    """Creste: 1 - |2n-1|, accentuate."""
    rng = np.random.default_rng(seed)
    total = np.zeros(shape, np.float32)
    amp, norm, cell = 1.0, 0.0, float(base_cell)
    for _ in range(octaves):
        c = max(2, int(round(cell)))
        n = value_noise(shape, c, rng)
        r = 1.0 - np.abs(2.0 * n - 1.0)
        total += amp * r * r
        norm += amp
        amp *= 0.5
        cell /= 2.0
    return total / norm
