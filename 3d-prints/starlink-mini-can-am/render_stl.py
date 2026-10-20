#!/usr/bin/env python3
"""Render STLs for the Starlink Mini Can-Am mount without OpenSCAD.

Mirrors the geometry in starlink_mini_canam_mount.scad using manifold3d.
    pip install manifold3d trimesh numpy
    python3 render_stl.py [out_dir]
"""
import sys, os, math
import numpy as np
import trimesh
from manifold3d import Manifold

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "stl")
os.makedirs(OUT, exist_ok=True)

# ---- parameters (keep in sync with the .scad) ----
dish_L, dish_W, dish_T = 298.5, 259.0, 38.5
clr = 1.5
gap = dish_T + 2.5
tube_sizes = {"1.75in": 44.45, "1.85in": 47.0, "2.00in": 50.8}
tube_clr = 0.4
wall, flange_t, flange_w, lip_t, lip_w = 4, 6, 34, 4, 16
ch_depth = lip_w
stop_t, ret_zone = 4, 20
rail_L = stop_t + 2 * clr + dish_L + ret_zone
joint_x, lap_L = 162, 40
rail_H = flange_t + gap + lip_t
hole_d, hole_y, grid0, grid_p, grid_n = 5.5, 25, 12, 20, 16
clamp_wall, clamp_w, ear_w, ear_t, ear_hole = 8, 30, 16, 8, 6.5
pad_L, pad_t, pad_hole_sp, tilt = 50, 8, 20, 0
xbar_L, xbar_w, xbar_t, xbar_hole_sp = 240, 25, 8, 220
SEG = 64


def cube(x, y, z, at=(0, 0, 0)):
    return Manifold.cube([x, y, z]).translate(list(at))


def cyl(d, h, at=(0, 0, 0), axis="z"):
    m = Manifold.cylinder(h, d / 2, d / 2, SEG)
    if axis == "y":
        m = m.rotate([-90, 0, 0])   # z -> y... rotate -90 about x maps +z to +y
    elif axis == "x":
        m = m.rotate([0, 90, 0])
    return m.translate(list(at))


def grid_holes():
    m = Manifold()
    for i in range(grid_n):
        m += cyl(hole_d, 50, (grid0 + i * grid_p, hole_y, -25))
    return m


def rail_full():
    body = (cube(rail_L, flange_w, flange_t)
            + cube(rail_L, wall, rail_H)
            + cube(rail_L, lip_w, lip_t, (0, 0, flange_t + gap))
            + cube(stop_t, ch_depth, rail_H))
    # front lip entry chamfer: wedge removing lip underside at the front end
    e = 0.01
    tri = np.array([[e, 0], [e, lip_t + e], [-8, 0]], dtype=np.float64)
    from manifold3d import CrossSection
    # triangle in xz, extruded along -y across the lip (same construction as the .scad)
    wedge = Manifold.extrude(CrossSection([tri]), lip_w + 2 * e).rotate([90, 0, 0])
    wedge = wedge.translate([rail_L + e, lip_w + e, flange_t + gap - e])
    return body - grid_holes() - wedge


def rail_rear():
    r = rail_full()
    r -= cube(rail_L, flange_w + 2, rail_H, (joint_x, -1, flange_t / 2))
    r -= cube(rail_L, flange_w + 2, rail_H + 2, (joint_x + lap_L, -1, -1))
    return r


def rail_front():
    r = rail_full()
    r -= cube(joint_x + 1, flange_w + 2, rail_H + 2, (-1, -1, -1))
    r -= cube(lap_L + 1, flange_w + 2, flange_t / 2 + 1, (joint_x - 1, -1, -1))
    return r.translate([-joint_x, 0, 0])


def mirror_y(m):
    return m.mirror([0, 1, 0])


def retainer():
    rx = grid0 + (grid_n - 1) * grid_p - 8
    m = (cube(15, ch_depth - wall, gap - 0.5, (rx + 1, wall, flange_t))
         + cube(16, flange_w - wall, 4, (rx, wall, flange_t)))
    return m - cyl(hole_d, 50, (rx + 8, hole_y, 0))


def crossbar():
    m = cube(xbar_L, xbar_w, xbar_t, (-xbar_L / 2, -xbar_w / 2, 0))
    for s in (-1, 1):
        m -= cyl(hole_d, xbar_t + 2, (s * xbar_hole_sp / 2, 0, -1))
    return m


def clamp(tube_od, top):
    R_in = tube_od / 2 + tube_clr
    R_out = R_in + clamp_wall
    body = cyl(2 * R_out, clamp_w, (0, -clamp_w / 2, 0), axis="y")
    for s in (-1, 1):
        body += cube(ear_w, clamp_w, 2 * ear_t, (s * (R_out - 2 + ear_w / 2) - ear_w / 2, -clamp_w / 2, -ear_t))
    cuts = cyl(2 * R_in, clamp_w + 2, (0, -clamp_w / 2 - 1, 0), axis="y")
    for s in (-1, 1):
        cuts += cyl(ear_hole, 100, (s * (R_out - 2 + ear_w / 2), 0, -50))
    cuts += cube(200, 200, 0.6, (-100, -100, -0.3))
    if top:
        pad = cube(pad_L, clamp_w, pad_t + 3, (-pad_L / 2, -clamp_w / 2, R_out - 3)).rotate([0, tilt, 0])
        m = body + pad - cuts
        for s in (-1, 1):
            m -= cyl(hole_d, 50, (s * pad_hole_sp / 2, 0, R_out - 4)).rotate([0, tilt, 0])
        m -= cube(200, 200, 100, (-100, -100, -100))
    else:
        m = body - cuts - cube(200, 200, 100, (-100, -100, 0))
    return m


def save(name, m):
    mesh = m.to_mesh()
    tm = trimesh.Trimesh(vertices=np.asarray(mesh.vert_properties)[:, :3], faces=np.asarray(mesh.tri_verts), process=False)
    assert tm.is_watertight, name
    path = os.path.join(OUT, name + ".stl")
    tm.export(path)
    b = tm.bounds
    print(f"{name:28s} vol={tm.volume/1000:7.1f} cm3  size={b[1][0]-b[0][0]:6.1f} x {b[1][1]-b[0][1]:6.1f} x {b[1][2]-b[0][2]:6.1f} mm")
    return tm


parts = {
    "rail_rear_L": rail_rear(), "rail_rear_R": mirror_y(rail_rear()),
    "rail_front_L": rail_front(), "rail_front_R": mirror_y(rail_front()),
    "retainer_L": retainer(), "retainer_R": mirror_y(retainer()),
    "crossbar": crossbar(),
}
for label, od in tube_sizes.items():
    parts[f"clamp_top_{label}"] = clamp(od, True)
    parts[f"clamp_bottom_{label}"] = clamp(od, False)

for name, m in parts.items():
    save(name, m)
