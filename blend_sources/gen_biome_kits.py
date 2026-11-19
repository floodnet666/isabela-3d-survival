import bpy, bmesh, math, os, random
from mathutils import Vector, Matrix, noise

OUT_ROOT = r"D:\Godot\isabela_scene_test\assets"
TILE_SIZE = 6.0


def make_mat(name, rgba, metallic=0.1, roughness=0.6, emission=0.0, alpha=1.0):
    m = bpy.data.materials.new(name=name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = rgba
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission > 0.0:
        bsdf.inputs['Emission Color'].default_value = rgba
        bsdf.inputs['Emission Strength'].default_value = emission
    if alpha < 1.0:
        bsdf.inputs['Alpha'].default_value = alpha
        m.blend_method = 'BLEND'
    return m


def apply_box_uv(bm, uv_scale=0.35):
    uv_layer = bm.loops.layers.uv.verify()
    bm.normal_update()
    for f in bm.faces:
        n = f.normal
        ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
        for loop in f.loops:
            co = loop.vert.co
            if az >= ax and az >= ay:
                u, v = co.x * uv_scale, co.y * uv_scale
            elif ax >= ay and ax >= az:
                u, v = co.y * uv_scale, co.z * uv_scale
            else:
                u, v = co.x * uv_scale, co.z * uv_scale
            loop[uv_layer].uv = (u, v)


def set_smooth_by_angle(bm, angle_deg=38.0):
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True


def add_box(bm, size, pos, rot=(0, 0, 0), mat_idx=0, bevel=0.04, bevel_segs=2):
    sx, sy, sz = size
    m = (
        Matrix.Translation(Vector(pos))
        @ Matrix.Rotation(math.radians(rot[2]), 4, 'Z')
        @ Matrix.Rotation(math.radians(rot[0]), 4, 'X')
        @ Matrix.Rotation(math.radians(rot[1]), 4, 'Y')
        @ Matrix.Diagonal(Vector((sx, sy, sz, 1.0)))
    )
    res = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    faces = list({f for v in res['verts'] for f in v.link_faces})
    for f in faces:
        f.material_index = mat_idx
    if bevel > 0.0:
        edges = list({e for f in faces for e in f.edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=bevel_segs, affect='EDGES')
    return res['verts']


def add_cone(bm, segs, r1, r2, h, pos, rot=(0, 0, 0), mat_idx=0, cap_ends=True):
    m = (
        Matrix.Translation(Vector(pos))
        @ Matrix.Rotation(math.radians(rot[2]), 4, 'Z')
        @ Matrix.Rotation(math.radians(rot[0]), 4, 'X')
        @ Matrix.Rotation(math.radians(rot[1]), 4, 'Y')
    )
    res = bmesh.ops.create_cone(
        bm, cap_ends=cap_ends, cap_tris=False, segments=segs, radius1=r1, radius2=r2, depth=h, matrix=m
    )
    for v in res['verts']:
        for f in v.link_faces:
            f.material_index = mat_idx
    return res['verts']


def add_rock(bm, radius, pos, scale=(1, 1, 1), seed=1, mat_idx=0, subdivs=3, amp=0.36, ridged=False, flat_bottom=True, smooth=True):
    res = bmesh.ops.create_icosphere(bm, subdivisions=subdivs, radius=radius)
    off = Vector((seed * 3.17, seed * 1.93, seed * 5.41))
    for v in res['verts']:
        p = v.co * 1.15 + off
        n1 = noise.noise(p)
        n2 = noise.noise(p * 2.3 + Vector((7.1, 2.3, 4.7))) * 0.45
        n3 = noise.noise(p * 4.9 - Vector((3.2, 8.1, 1.9))) * 0.18
        n = (1.0 - abs(n1)) * 0.65 - 0.3 + n2 + n3 if ridged else (n1 + n2 + n3)
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2])) * (1.0 + n * amp)
        if flat_bottom and v.co.z < -radius * scale[2] * 0.45:
            v.co.z = -radius * scale[2] * 0.45
        v.co += Vector(pos)
        for f in v.link_faces:
            f.material_index = mat_idx
            f.smooth = smooth
    return res['verts']


def add_tube_along_points(bm, pts, radius, segs=8, mat_idx=0):
    rings = []
    for i, p in enumerate(pts):
        if i == 0:
            tangent = (pts[1] - pts[0]).normalized()
        elif i == len(pts) - 1:
            tangent = (pts[-1] - pts[-2]).normalized()
        else:
            tangent = (pts[i + 1] - pts[i - 1]).normalized()
        up = Vector((0, 0, 1)) if abs(tangent.z) < 0.92 else Vector((1, 0, 0))
        side = tangent.cross(up).normalized()
        binorm = side.cross(tangent).normalized()
        ring = []
        for s in range(segs):
            a = (s / float(segs)) * math.tau
            offset = (side * math.cos(a) + binorm * math.sin(a)) * radius
            ring.append(bm.verts.new(p + offset))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(segs):
            s2 = (s + 1) % segs
            f = bm.faces.new((rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]))
            f.material_index = mat_idx
            f.smooth = True


def add_organic_arch(bm, span_x, height_z, base_r, top_r, segs_arc=11, segs_ring=10, seed=10, mat_idx=0, disp=0.22):
    rings = []
    off = Vector((seed * 2.7, seed * 4.1, seed * 1.3))
    for i in range(segs_arc + 1):
        t = i / float(segs_arc)
        ang = math.pi * t
        cx = -math.cos(ang) * (span_x * 0.5)
        cz = math.sin(ang) * height_z
        center = Vector((cx, 0.0, cz))
        tangent = Vector((math.sin(ang) * span_x * 0.5, 0.0, math.cos(ang) * height_z)).normalized()
        side = Vector((0.0, 1.0, 0.0))
        normal = tangent.cross(side).normalized()
        rad = base_r * (1.0 - math.sin(ang) * 0.35) + top_r * (math.sin(ang) * 0.35)
        ring = []
        for s in range(segs_ring):
            a = (s / float(segs_ring)) * math.tau
            dir_v = side * math.cos(a) * 0.85 + normal * math.sin(a) * 1.05
            pos = center + dir_v * rad
            n = noise.noise(pos * 0.9 + off) + 0.45 * noise.noise(pos * 2.1 - off)
            pos += dir_v * (n * disp)
            if i == 0 or i == segs_arc:
                pos.z = min(pos.z, 0.02)
            ring.append(bm.verts.new(pos))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for s in range(segs_ring):
            s2 = (s + 1) % segs_ring
            f = bm.faces.new((rings[i][s], rings[i][s2], rings[i + 1][s2], rings[i + 1][s]))
            f.material_index = mat_idx
            f.smooth = True


def add_sculpted_peak(bm, base_r, top_r, height, pos, rings=10, segs=22, seed=1, mat_idx=0, ridge_amp=0.28, angular=False, crater_depth=0.0):
    off = Vector((seed * 4.3, seed * 2.1, seed * 6.7))
    ring_verts = []
    for ri in range(rings + 1):
        t = ri / float(rings)
        z = t * height
        r_base = base_r * ((1.0 - t) ** (1.12 if angular else 1.18)) + top_r * t
        row = []
        for si in range(segs):
            a = (si / float(segs)) * math.tau
            dx, dy = math.cos(a), math.sin(a)
            p_n = Vector((dx * (2.4 if angular else 1.6), dy * (2.4 if angular else 1.6), t * 2.6)) + off
            n1 = 1.0 - abs(noise.noise(p_n))
            n2 = (1.0 - abs(noise.noise(p_n * 2.7))) * 0.45
            n3 = (1.0 - abs(noise.noise(p_n * 5.2))) * 0.18
            rib = (abs(math.sin(a * (3.0 + (seed % 3)) + seed)) ** 1.3 - 0.35) * (0.38 if angular else 0.0)
            ridge = (n1 + n2 + n3 - 0.70 + rib) * ridge_amp * (1.0 - t * 0.28) * (0.20 + 0.80 * math.sin(t * math.pi))
            r = max(0.35, r_base * (1.0 + ridge))
            x = pos[0] + dx * r
            y = pos[1] + dy * r
            z_j = (noise.noise(Vector((dx * 3.0, dy * 3.0, seed))) * 1.4) if (angular and ri == rings) else 0.0
            row.append(bm.verts.new((x, y, pos[2] + z + z_j)))
        ring_verts.append(row)
    for ri in range(rings):
        for si in range(segs):
            s2 = (si + 1) % segs
            f = bm.faces.new((ring_verts[ri][si], ring_verts[ri][s2], ring_verts[ri + 1][s2], ring_verts[ri + 1][si]))
            f.material_index = mat_idx
            f.smooth = True
    top_z = pos[2] + height - crater_depth if crater_depth > 0.0 else pos[2] + height + (1.0 if angular else 0.6)
    top_center = bm.verts.new((pos[0], pos[1], top_z))
    for si in range(segs):
        s2 = (si + 1) % segs
        f = bm.faces.new((ring_verts[rings][si], ring_verts[rings][s2], top_center))
        f.material_index = mat_idx
        f.smooth = True


def finalize_and_export(obj, mesh, bm, out_path, uv_scale=0.35):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    apply_box_uv(bm, uv_scale=uv_scale)
    bm.to_mesh(mesh)
    bm.free()
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format='GLB',
        use_selection=False,
        export_materials='EXPORT',
        export_yup=True,
    )


def new_scene_mesh(name, mats_fn):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for m in mats_fn():
        obj.data.materials.append(m)
    return obj, mesh


# ==============================================================================
# 0. ENV_CoastProps — UPGRADED PHOTOREALISTIC PROPS FOR BIOME 1 (MIRROR COAST)
# ==============================================================================
def build_coast_props():
    out = os.path.join(OUT_ROOT, "ENV_CoastProps")

    def mats():
        return [
            make_mat("MAT_CoastArmor", (0.14, 0.17, 0.21, 1.0), 0.82, 0.34),
            make_mat("MAT_CoastDarkSteel", (0.08, 0.10, 0.13, 1.0), 0.88, 0.28),
            make_mat("MAT_CoastBasalt", (0.10, 0.11, 0.12, 1.0), 0.08, 0.22),
            make_mat("MAT_CoastCyan", (0.14, 0.88, 1.00, 1.0), 0.10, 0.15, emission=3.4),
            make_mat("MAT_CoastAmber", (1.00, 0.56, 0.14, 1.0), 0.10, 0.15, emission=3.0),
        ]

    # SM_CoastBarrier (3.6 x 1.22 x 0.65m sleek ribbed ballistic barrier matching Ref 1)
    obj, mesh = new_scene_mesh("SM_CoastBarrier", mats)
    bm = bmesh.new()
    # Base plinth submerged in water
    add_box(bm, (3.65, 0.82, 0.24), (0, 0, 0.12), (0, 0, 0), mat_idx=1, bevel=0.04)
    # Main sloped ballistic wall
    add_box(bm, (3.40, 0.54, 0.96), (0, 0, 0.66), (0, 0, 0), mat_idx=0, bevel=0.05)
    # Recessed dark armored center channel
    add_box(bm, (2.90, 0.59, 0.30), (0, 0, 0.68), (0, 0, 0), mat_idx=1, bevel=0.02)
    # 4 vertical heavy structural reinforcement ribs + corner stanchions
    for ox in [-1.62, -0.58, 0.58, 1.62]:
        add_box(bm, (0.24, 0.72, 1.18), (ox, 0, 0.60), (0, 0, 0), mat_idx=1, bevel=0.03)
    # Top beveled cap rail + subtle tactical cyan indicator strip
    add_box(bm, (3.50, 0.62, 0.12), (0, 0, 1.16), (0, 0, 0), mat_idx=0, bevel=0.03)
    add_box(bm, (2.20, 0.61, 0.055), (0, 0, 0.94), (0, 0, 0), mat_idx=3, bevel=0.01)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "SM_CoastBarrier.glb"), uv_scale=0.65)

    # SM_CoastCrate (2.5 x 2.1 x 1.75m military ribbed container)
    obj, mesh = new_scene_mesh("SM_CoastCrate", mats)
    bm = bmesh.new()
    add_box(bm, (2.42, 2.02, 1.64), (0, 0, 0.82), (0, 0, 0), mat_idx=0, bevel=0.06)
    # Corner bumpers
    for sx in [-1.14, 1.14]:
        for sy in [-0.94, 0.94]:
            add_box(bm, (0.26, 0.26, 1.76), (sx, sy, 0.88), (0, 0, 0), mat_idx=1, bevel=0.03)
    # Roof armor ribs
    for ox in [-0.75, 0.0, 0.75]:
        add_box(bm, (0.22, 2.08, 0.14), (ox, 0, 1.68), (0, 0, 0), mat_idx=1, bevel=0.02)
    add_box(bm, (1.80, 2.06, 0.07), (0, 0, 1.38), (0, 0, 0), mat_idx=4, bevel=0.01)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "SM_CoastCrate.glb"), uv_scale=0.55)

    # SM_CoastPylon (5.8m detailed comms/beacon tower)
    obj, mesh = new_scene_mesh("SM_CoastPylon", mats)
    bm = bmesh.new()
    add_cone(bm, 8, 1.05, 0.82, 0.85, (0, 0, 0.42), (0, 0, 22.5), mat_idx=1)
    add_cone(bm, 8, 0.52, 0.34, 4.4, (0, 0, 2.95), (0, 0, 22.5), mat_idx=0)
    for k in range(4):
        a = k * math.pi * 0.5
        add_box(bm, (0.14, 0.32, 4.2), (math.cos(a) * 0.46, math.sin(a) * 0.46, 2.8), (0, 0, k * 90), mat_idx=1, bevel=0.02)
    # Upper glowing emitter housing + fin cap
    add_cone(bm, 8, 0.44, 0.44, 1.15, (0, 0, 4.75), (0, 0, 22.5), mat_idx=3)
    add_cone(bm, 8, 0.56, 0.18, 0.65, (0, 0, 5.60), (0, 0, 22.5), mat_idx=1)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "SM_CoastPylon.glb"), uv_scale=0.50)

    # SM_CoastRockCluster (wet dark coastal basalt boulders matching Ref 1 foreground)
    obj, mesh = new_scene_mesh("SM_CoastRockCluster", mats)
    bm = bmesh.new()
    add_rock(bm, 1.25, (0.0, 0.0, 0.42), (1.35, 1.05, 0.68), seed=71, mat_idx=2, subdivs=3, amp=0.30, ridged=True)
    add_rock(bm, 0.85, (1.35, 0.55, 0.24), (1.25, 0.95, 0.52), seed=72, mat_idx=2, subdivs=3, amp=0.25)
    add_rock(bm, 0.62, (-1.15, -0.45, 0.18), (1.15, 1.10, 0.45), seed=73, mat_idx=2, subdivs=2, amp=0.22)
    add_rock(bm, 0.42, (0.45, -1.05, 0.12), (1.20, 0.95, 0.38), seed=74, mat_idx=2, subdivs=2, amp=0.18)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "SM_CoastRockCluster.glb"), uv_scale=0.55)


# ==============================================================================
# 1. ENV_SandPyramid — DUNAS DA PIRAMIDE SOLAR (REF 2)
# ==============================================================================
def build_sand_pyramid():
    out = os.path.join(OUT_ROOT, "ENV_SandPyramid")

    def mats():
        return [
            make_mat("MAT_SandDunes", (0.82, 0.63, 0.36, 1.0), 0.02, 0.88),
            make_mat("MAT_SandstoneRuins", (0.68, 0.49, 0.28, 1.0), 0.04, 0.80),
            make_mat("MAT_SandstoneBlocks", (0.60, 0.43, 0.24, 1.0), 0.05, 0.76),
            make_mat("MAT_GoldCapstone", (1.00, 0.78, 0.24, 1.0), 0.94, 0.16, emission=1.8),
            make_mat("MAT_DarkRelicMetal", (0.20, 0.17, 0.14, 1.0), 0.68, 0.42),
            make_mat("MAT_SciFiCyan", (0.22, 0.90, 1.00, 1.0), 0.10, 0.18, emission=3.0),
            make_mat("MAT_SandFloor", (0.76, 0.58, 0.34, 1.0), 0.02, 0.86),
        ]

    # BACKDROP: Sharp wind-carved dune ring + flanking rocky mesas + 3 colossal horizon pyramids + perimeter obelisks
    obj, mesh = new_scene_mesh("BACKDROP", mats)
    bm = bmesh.new()
    rings, segs = 22, 72
    grid_v = []
    for ri in range(rings):
        r = 31.0 + (ri / float(rings - 1)) ** 1.28 * 145.0
        row = []
        for si in range(segs):
            a = (si / float(segs)) * math.tau
            x, y = math.cos(a) * r, math.sin(a) * r
            # Sharp windward/leeward barchan dune crest formula
            w1 = 1.0 - abs(math.sin(x * 0.042 + y * 0.026 + noise.noise(Vector((x * 0.018, y * 0.018, 0.5))) * 2.2))
            w2 = noise.noise(Vector((x * 0.024, y * 0.024, 3.1))) * 0.5 + 0.5
            dune_h = (w1 ** 1.45) * 11.5 + w2 * 7.5
            fade = min(1.0, max(0.0, (r - 31.5) / 16.0))
            # Lower slightly directly in front of pyramid sightline (+Y) so pyramids tower dramatically
            sight_dip = 0.58 if (y > 40.0 and -45.0 < x < 75.0) else 1.0
            z = -0.25 + dune_h * fade * sight_dip
            row.append(bm.verts.new((x, y, z)))
        grid_v.append(row)
    for ri in range(rings - 1):
        for si in range(segs):
            s2 = (si + 1) % segs
            f = bm.faces.new((grid_v[ri][si], grid_v[ri][s2], grid_v[ri + 1][s2], grid_v[ri + 1][si]))
            f.material_index = 0
            f.smooth = True

    # Flanking rocky desert mesas (left & right horizon, matching Ref 2)
    for mx, my, mr, mh, sd in [(-92, 52, 26, 22, 11), (-110, 12, 24, 18, 12), (98, 48, 28, 20, 13), (112, -8, 24, 17, 14)]:
        add_sculpted_peak(bm, mr, mr * 0.55, mh, (mx, my, -0.5), rings=7, segs=18, seed=sd, mat_idx=1, ridge_amp=0.22)

    # Colossal Great Pyramid (shifted right of center so SM_Ship never overlaps its golden capstone!)
    px, py = 20.0, 118.0
    add_cone(bm, 4, 56.0, 10.5, 48.0, (px, py, 23.0), (0, 0, 45), mat_idx=2)
    add_cone(bm, 4, 10.7, 0.15, 11.8, (px, py, 52.8), (0, 0, 45), mat_idx=3)
    # Two flanking pyramids (matching Ref 2 triad silhouette)
    add_cone(bm, 4, 34.0, 1.2, 31.0, (-34.0, 128.0, 14.5), (0, 0, 45), mat_idx=2)
    add_cone(bm, 4, 38.0, 1.2, 35.0, (70.0, 124.0, 16.5), (0, 0, 45), mat_idx=2)

    # Perimeter sunken ruins & leaning carved obelisks around the plaza edge
    for opos, otilt in [((-33, 22, 5.5), (4, -3, 18)), ((34, 18, 6.0), (-3, 5, -14)), ((-36, -24, 4.5), (8, 6, 32)), ((35, -26, 5.0), (-6, -7, 40))]:
        add_box(bm, (3.2, 3.2, 1.4), (opos[0], opos[1], 0.5), (0, 0, otilt[2]), mat_idx=2, bevel=0.08)
        add_cone(bm, 4, 1.85, 1.05, 13.5, opos, otilt, mat_idx=1)
        add_cone(bm, 4, 1.05, 0.08, 2.3, (opos[0], opos[1], opos[2] + 7.8), otilt, mat_idx=3)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "BACKDROP.glb"), uv_scale=0.12)

    # FLOOR: Solid closed disk (upward normals guaranteed!) driven by custom biome_sand_floor.gdshader
    obj, mesh = new_scene_mesh("FLOOR", mats)
    bm = bmesh.new()
    add_cone(bm, 64, 35.5, 35.5, 0.24, (0, 0, -0.12), (0, 0, 0), mat_idx=6)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "FLOOR.glb"), uv_scale=0.25)

    # WFC TILES: Authentic weathered Egyptian sandstone ruins + subtle sci-fi relic inlays
    for tname in ["TILE_Open", "TILE_CoverLow", "TILE_Pillar", "TILE_WallStraight", "TILE_WallCorner", "TILE_Arch"]:
        obj, mesh = new_scene_mesh(tname, mats)
        bm = bmesh.new()
        if tname == "TILE_Open":
            # Subtle scattered weathered desert stones & half-buried masonry chips (never flat boxy rectangles)
            add_rock(bm, 0.36, (-1.9, 1.6, 0.04), (1.35, 1.05, 0.28), seed=101, mat_idx=1, subdivs=2, amp=0.25)
            add_rock(bm, 0.28, (1.8, -1.5, 0.03), (1.20, 0.90, 0.24), seed=102, mat_idx=2, subdivs=2, amp=0.25)
        elif tname == "TILE_CoverLow":
            # Multi-block weathered sandstone low ruin wall + relic metal brace & glowing accent
            add_box(bm, (3.25, 1.02, 0.36), (0.0, 0.0, 0.18), (0, 0, 0), mat_idx=2, bevel=0.06)
            add_box(bm, (1.58, 0.86, 0.72), (-0.78, 0.0, 0.70), (0, 0, 2), mat_idx=1, bevel=0.07)
            add_box(bm, (1.35, 0.82, 0.56), (0.82, 0.04, 0.62), (0, 0, -4), mat_idx=1, bevel=0.07)
            add_box(bm, (0.58, 0.92, 0.82), (0.05, 0.0, 0.68), (0, 0, 0), mat_idx=4, bevel=0.03)
            add_box(bm, (0.48, 0.96, 0.08), (0.05, 0.0, 0.88), (0, 0, 0), mat_idx=5, bevel=0.01)
            add_rock(bm, 0.44, (1.68, -0.35, 0.18), (1.15, 0.95, 0.62), seed=111, mat_idx=1, subdivs=2, amp=0.28)
            add_rock(bm, 0.34, (-1.62, 0.38, 0.14), (1.10, 0.90, 0.55), seed=112, mat_idx=2, subdivs=2, amp=0.28)
        elif tname == "TILE_Pillar":
            # Tall monolithic Egyptian obelisk with stepped pedestal + carved bands + gleaming gold apex
            add_box(bm, (1.92, 1.92, 0.42), (0, 0, 0.21), (0, 0, 0), mat_idx=2, bevel=0.06)
            add_box(bm, (1.56, 1.56, 0.40), (0, 0, 0.60), (0, 0, 0), mat_idx=4, bevel=0.05)
            add_cone(bm, 4, 0.92, 0.54, 4.4, (0, 0, 2.98), (0, 0, 45), mat_idx=1)
            # Carved horizontal frieze collars
            for hz, hr in [(1.8, 0.84), (3.1, 0.72), (4.3, 0.60)]:
                add_cone(bm, 4, hr, hr, 0.14, (0, 0, hz), (0, 0, 45), mat_idx=2)
            add_cone(bm, 4, 0.56, 0.04, 1.15, (0, 0, 5.75), (0, 0, 45), mat_idx=3)
        elif tname == "TILE_WallStraight":
            # Stepped weathered temple masonry wall with broken crown blocks & pilasters
            add_box(bm, (TILE_SIZE, 1.32, 0.65), (0, 0, 0.325), (0, 0, 0), mat_idx=2, bevel=0.06)
            add_box(bm, (TILE_SIZE - 0.12, 1.06, 1.15), (0, 0, 1.22), (0, 0, 0), mat_idx=1, bevel=0.06)
            # Broken/stepped top ashlar courses
            for ox, w, h in [(-2.0, 1.65, 0.62), (0.05, 1.90, 0.42), (2.05, 1.55, 0.72)]:
                add_box(bm, (w, 0.94, h), (ox, 0, 1.78 + h * 0.5), (0, 0, 0), mat_idx=1, bevel=0.06)
            for ox in [-2.65, 2.65]:
                add_box(bm, (0.65, 1.38, 2.35), (ox, 0, 1.175), (0, 0, 0), mat_idx=2, bevel=0.05)
            add_box(bm, (TILE_SIZE - 0.6, 1.12, 0.10), (0, 0, 1.48), (0, 0, 0), mat_idx=4, bevel=0.01)
            add_box(bm, (1.4, 1.15, 0.06), (0, 0, 1.48), (0, 0, 0), mat_idx=5, bevel=0.01)
        elif tname == "TILE_WallCorner":
            add_box(bm, (3.6, 1.22, 2.15), (1.2, 0, 1.075), (0, 0, 0), mat_idx=1, bevel=0.07)
            add_box(bm, (1.22, 3.6, 2.15), (0, 1.2, 1.075), (0, 0, 0), mat_idx=1, bevel=0.07)
            # Corner temple pylon tower with flared cavetto cornice
            add_cone(bm, 4, 1.48, 1.12, 3.10, (0, 0, 1.55), (0, 0, 45), mat_idx=2)
            add_cone(bm, 4, 1.12, 1.36, 0.48, (0, 0, 3.34), (0, 0, 45), mat_idx=1)
            add_box(bm, (1.95, 1.95, 0.22), (0, 0, 3.68), (0, 0, 0), mat_idx=4, bevel=0.04)
            add_cone(bm, 4, 0.82, 0.08, 0.68, (0, 0, 4.12), (0, 0, 45), mat_idx=3)
        elif tname == "TILE_Arch":
            # Monumental Egyptian Temple Pylon Gateway (tapered pylons + cavetto cornice lintel)
            for sx in [-2.22, 2.22]:
                add_box(bm, (1.58, 1.52, 0.48), (sx, 0, 0.24), (0, 0, 0), mat_idx=2, bevel=0.05)
                add_cone(bm, 4, 1.06, 0.78, 3.85, (sx, 0, 2.38), (0, 0, 45), mat_idx=1)
                add_cone(bm, 4, 0.78, 0.96, 0.36, (sx, 0, 4.46), (0, 0, 45), mat_idx=2)
            # Massive carved lintel & flared cornice
            add_box(bm, (5.85, 1.34, 0.88), (0, 0, 4.30), (0, 0, 0), mat_idx=1, bevel=0.07)
            add_box(bm, (6.20, 1.56, 0.34), (0, 0, 4.86), (0, 0, 0), mat_idx=2, bevel=0.05)
            add_box(bm, (4.20, 1.40, 0.14), (0, 0, 4.30), (0, 0, 0), mat_idx=3, bevel=0.02)
        finalize_and_export(obj, mesh, bm, os.path.join(out, f"{tname}.glb"), uv_scale=0.45)


# ==============================================================================
# 2. ENV_MothershipInterior — HANGAR INTERNO DA NAVE-MAE (REF 3)
# ==============================================================================
def build_mothership_interior():
    out = os.path.join(OUT_ROOT, "ENV_MothershipInterior")

    def mats():
        return [
            make_mat("MAT_DeckMetal", (0.11, 0.13, 0.17, 1.0), 0.88, 0.30),
            make_mat("MAT_HullArmor", (0.16, 0.19, 0.24, 1.0), 0.84, 0.34),
            make_mat("MAT_DarkTitanium", (0.07, 0.08, 0.11, 1.0), 0.90, 0.26),
            make_mat("MAT_ReactorCyan", (0.14, 0.90, 1.00, 1.0), 0.10, 0.12, emission=4.6),
            make_mat("MAT_ReactorCore", (0.72, 0.98, 1.00, 1.0), 0.05, 0.08, emission=8.0),
            make_mat("MAT_WarningAmber", (1.00, 0.46, 0.10, 1.0), 0.15, 0.22, emission=3.2),
            make_mat("MAT_SpaceViewport", (0.02, 0.04, 0.10, 1.0), 0.0, 0.05, emission=1.2),
            make_mat("MAT_MothershipDeck", (0.10, 0.12, 0.16, 1.0), 0.86, 0.28),
        ]

    # BACKDROP: Massive enclosed circular armored hangar dome + deep-space viewports + draped power cables + central Reactor Core!
    obj, mesh = new_scene_mesh("BACKDROP", mats)
    bm = bmesh.new()
    bays = 16
    for i in range(bays):
        a = (i / float(bays)) * math.tau
        deg = math.degrees(a)
        # Forward view direction in Godot is -Z which is +Y in Blender (angle ~ pi/2 -> bays 3, 4, 5)
        is_viewport_bay = i in (3, 4, 5)
        px, py = math.cos(a) * 35.8, math.sin(a) * 35.8
        # Lower armored bulkhead sill
        if is_viewport_bay:
            # Lower wall below massive space viewport window
            add_box(bm, (1.6, 14.4, 3.6), (px, py, 1.8), (0, 0, deg), mat_idx=1, bevel=0.06)
            # Upper header above viewport window
            add_box(bm, (1.6, 14.4, 6.2), (px, py, 14.2), (0, 0, deg), mat_idx=1, bevel=0.06)
            # Heavy side mullions framing the chamfered window
            for off_t in [-5.8, 5.8]:
                tx, ty = -math.sin(a) * off_t, math.cos(a) * off_t
                add_box(bm, (1.9, 2.2, 8.2), (px + tx, py + ty, 7.6), (0, 0, deg), mat_idx=2, bevel=0.08)
            # Giant deep-space starry viewport glass pane recessed behind mullions
            gx, gy = math.cos(a) * 36.4, math.sin(a) * 36.4
            add_box(bm, (0.25, 11.4, 7.6), (gx, gy, 7.5), (0, 0, deg), mat_idx=6, bevel=0.0)
            # Subtle cyan rim strip along window sill
            sx, sy = math.cos(a) * 34.8, math.sin(a) * 34.8
            add_box(bm, (0.22, 9.6, 0.16), (sx, sy, 3.62), (0, 0, deg), mat_idx=3, bevel=0.01)
        else:
            # Solid armored hangar hull bay with deep recessed panels & industrial turbine vent
            add_box(bm, (1.6, 14.6, 17.5), (px, py, 8.75), (0, 0, deg), mat_idx=0, bevel=0.06)
            # Upper catwalk overhang & lower armored dado
            ix, iy = math.cos(a) * 34.4, math.sin(a) * 34.4
            add_box(bm, (1.4, 13.8, 1.2), (ix, iy, 10.6), (0, 0, deg), mat_idx=1, bevel=0.05)
            add_box(bm, (1.2, 13.8, 2.2), (ix, iy, 1.1), (0, 0, deg), mat_idx=2, bevel=0.05)
            # Glowing console/diagnostic strip
            add_box(bm, (0.28, 7.5, 0.34), (ix - math.cos(a) * 0.5, iy - math.sin(a) * 0.5, 5.2), (0, 0, deg), mat_idx=3 if i % 2 == 0 else 5, bevel=0.01)
            # Industrial turbine intake housing on alternate bays
            if i % 2 == 1:
                add_cone(bm, 16, 2.3, 2.0, 1.4, (ix, iy, 5.5), (0, 90, deg), mat_idx=2)
                add_cone(bm, 16, 1.6, 1.6, 1.5, (ix, iy, 5.5), (0, 90, deg), mat_idx=0)

        # Heavy vertical structural pilaster between every bay
        a_rib = a + (math.tau / float(bays)) * 0.5
        deg_rib = math.degrees(a_rib)
        rx0, ry0 = math.cos(a_rib) * 34.0, math.sin(a_rib) * 34.0
        add_box(bm, (2.2, 1.65, 17.5), (rx0, ry0, 8.75), (0, 0, deg_rib), mat_idx=2, bevel=0.06)

        # Giant sweeping curved double-flanged ceiling ribs arching to central reactor dome
        steps = 6
        for st in range(steps):
            t0 = st / float(steps)
            t1 = (st + 1) / float(steps)
            tm = (t0 + t1) * 0.5
            r0 = 34.2 * (1.0 - t0) + 10.5 * t0
            r1 = 34.2 * (1.0 - t1) + 10.5 * t1
            z0 = 15.8 + math.sin(t0 * math.pi * 0.5) * 10.8
            z1 = 15.8 + math.sin(t1 * math.pi * 0.5) * 10.8
            seg_len = math.hypot(r0 - r1, z1 - z0) + 0.35
            pitch = math.degrees(math.atan2(z1 - z0, r0 - r1))
            rm = (r0 + r1) * 0.5
            zm = (z0 + z1) * 0.5
            add_box(bm, (seg_len, 1.55, 1.45), (math.cos(a_rib) * rm, math.sin(a_rib) * rm, zm), (0, pitch, deg_rib), mat_idx=1, bevel=0.05)
            # Outer hull roof skin plate between ribs
            add_box(bm, (seg_len + 0.4, 14.5 * (1.0 - tm * 0.65), 0.55), (math.cos(a) * rm, math.sin(a) * rm, zm + 0.95), (0, pitch, deg), mat_idx=0, bevel=0.02)

        # Draped heavy catenary power cables sweeping from upper ceiling arches into central Reactor Core!
        if i % 2 == 0:
            for c_off, sag in [(-0.07, 4.2), (0.07, 5.4)]:
                aa = a_rib + c_off
                pts = []
                for k in range(11):
                    u = k / 10.0
                    rr = 28.0 * (1.0 - u) + 5.8 * u
                    zz = (22.5 * (1.0 - u) + 18.2 * u) - math.sin(u * math.pi) * sag
                    pts.append(Vector((math.cos(aa) * rr, math.sin(aa) * rr, zz)))
                add_tube_along_points(bm, pts, radius=0.22, segs=6, mat_idx=2)

    # Colossal Suspended Central Plasma Reactor Core (intricate armored cage silhouette around glowing cyan core, Ref 3!)
    add_cone(bm, 32, 13.0, 10.8, 2.6, (0, 0, 25.4), (0, 0, 0), mat_idx=2)
    add_cone(bm, 32, 9.4, 9.4, 0.42, (0, 0, 24.0), (0, 0, 0), mat_idx=3)
    for rz, r_out, h_r, mi in [(22.4, 7.8, 1.2, 1), (19.5, 6.6, 1.0, 2), (16.4, 5.6, 1.0, 1), (13.6, 4.4, 0.85, 2)]:
        add_cone(bm, 24, r_out, r_out * 0.94, h_r, (0, 0, rz), (0, 0, 0), mat_idx=mi)
        add_cone(bm, 24, r_out * 1.02, r_out * 1.02, 0.14, (0, 0, rz - h_r * 0.48), (0, 0, 0), mat_idx=3)
    # 12 heavy armored curved cage fins wrapping the glowing plasma orb so mechanical detail silhouettes crisply
    for k in range(12):
        a = (k / 12.0) * math.tau
        deg = math.degrees(a)
        add_box(bm, (1.15, 0.55, 11.4), (math.cos(a) * 5.2, math.sin(a) * 5.2, 18.8), (0, 14, deg), mat_idx=2, bevel=0.04)
    res_orb = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=3.2, matrix=Matrix.Translation((0, 0, 18.2)))
    for v in res_orb['verts']:
        for f in v.link_faces:
            f.material_index = 4
            f.smooth = True
    add_cone(bm, 24, 1.6, 1.1, 3.6, (0, 0, 14.5), (0, 0, 0), mat_idx=3)
    add_cone(bm, 24, 2.6, 1.8, 1.2, (0, 0, 12.9), (0, 0, 0), mat_idx=2)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "BACKDROP.glb"), uv_scale=0.18)

    # FLOOR: Circular machined titanium hangar deck driven by biome_mothership_deck.gdshader
    obj, mesh = new_scene_mesh("FLOOR", mats)
    bm = bmesh.new()
    add_cone(bm, 48, 37.5, 37.5, 0.20, (0, 0, -0.10), (0, 0, 0), mat_idx=7)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "FLOOR.glb"), uv_scale=0.28)

    # WFC TILES: Detailed tactical command consoles, plasma containment pillars, armored bulkheads, airlock frames
    for tname in ["TILE_Open", "TILE_CoverLow", "TILE_Pillar", "TILE_WallStraight", "TILE_WallCorner", "TILE_Arch"]:
        obj, mesh = new_scene_mesh(tname, mats)
        bm = bmesh.new()
        if tname == "TILE_Open":
            # Subtle flush deck cable duct & bolted seam plate
            add_box(bm, (2.4, 0.42, 0.03), (0, 1.8, 0.015), (0, 0, 0), mat_idx=2, bevel=0.01)
        elif tname == "TILE_CoverLow":
            # Tactical holographic ship command console + armored cheek shields (matching Ref 3!)
            add_box(bm, (3.25, 0.98, 0.28), (0, 0, 0.14), (0, 0, 0), mat_idx=2, bevel=0.04)
            add_box(bm, (2.90, 0.84, 0.86), (0, 0, 0.64), (0, 0, 0), mat_idx=1, bevel=0.05)
            # Dual angled glowing cyan hologram display consoles
            for sx in [-0.74, 0.74]:
                add_box(bm, (1.18, 0.50, 0.14), (sx, -0.18, 1.12), (-28, 0, 0), mat_idx=2, bevel=0.02)
                add_box(bm, (1.04, 0.38, 0.06), (sx, -0.22, 1.17), (-28, 0, 0), mat_idx=3, bevel=0.01)
            # Heavy ballistic side armor cheek guards
            for sx in [-1.52, 1.52]:
                add_box(bm, (0.34, 1.08, 1.24), (sx, 0, 0.62), (0, 0, 0), mat_idx=2, bevel=0.04)
            add_box(bm, (2.8, 0.88, 0.06), (0, 0, 0.34), (0, 0, 0), mat_idx=5, bevel=0.01)
        elif tname == "TILE_Pillar":
            # Pressurized cyan plasma fuel/coolant containment column
            add_cone(bm, 12, 1.12, 0.96, 0.55, (0, 0, 0.275), (0, 0, 15), mat_idx=2)
            add_cone(bm, 20, 0.66, 0.66, 3.85, (0, 0, 2.42), (0, 0, 0), mat_idx=3)
            # Ribbed containment rings along plasma tube
            for rz in [1.15, 2.42, 3.65]:
                add_cone(bm, 16, 0.82, 0.82, 0.24, (0, 0, rz), (0, 0, 0), mat_idx=1)
            add_cone(bm, 12, 0.96, 1.12, 0.55, (0, 0, 4.58), (0, 0, 15), mat_idx=2)
            for k in range(4):
                a = k * math.pi * 0.5 + math.pi * 0.25
                add_box(bm, (0.22, 0.28, 4.35), (math.cos(a) * 0.86, math.sin(a) * 0.86, 2.42), (0, 0, k * 90 + 45), mat_idx=2, bevel=0.02)
        elif tname == "TILE_WallStraight":
            # Heavy armored ship bulkhead barricade with deep vertical ribs & thin crisp data strips
            add_box(bm, (TILE_SIZE, 1.04, 0.42), (0, 0, 0.21), (0, 0, 0), mat_idx=2, bevel=0.04)
            add_box(bm, (TILE_SIZE, 0.84, 2.15), (0, 0, 1.42), (0, 0, 0), mat_idx=1, bevel=0.05)
            for ox in [-2.55, -0.85, 0.85, 2.55]:
                add_box(bm, (0.34, 1.06, 2.52), (ox, 0, 1.26), (0, 0, 0), mat_idx=2, bevel=0.03)
            add_box(bm, (TILE_SIZE - 0.6, 0.90, 0.065), (0, 0, 1.92), (0, 0, 0), mat_idx=3, bevel=0.01)
            add_box(bm, (TILE_SIZE - 0.6, 0.90, 0.055), (0, 0, 0.48), (0, 0, 0), mat_idx=5, bevel=0.01)
        elif tname == "TILE_WallCorner":
            add_box(bm, (3.5, 0.92, 2.48), (1.25, 0, 1.24), (0, 0, 0), mat_idx=1, bevel=0.05)
            add_box(bm, (0.92, 3.5, 2.48), (0, 1.25, 1.24), (0, 0, 0), mat_idx=1, bevel=0.05)
            add_cone(bm, 12, 1.08, 0.98, 2.95, (0, 0, 1.475), (0, 0, 15), mat_idx=2)
            add_cone(bm, 12, 1.03, 1.03, 0.08, (0, 0, 2.52), (0, 0, 15), mat_idx=3)
            add_cone(bm, 12, 0.65, 0.45, 0.42, (0, 0, 3.10), (0, 0, 15), mat_idx=1)
        elif tname == "TILE_Arch":
            # Massive chamfered sci-fi airlock corridor frame
            for sx in [-2.35, 2.35]:
                add_box(bm, (1.02, 1.24, 4.25), (sx, 0, 2.125), (0, 0, 0), mat_idx=1, bevel=0.06)
                add_box(bm, (0.36, 1.38, 3.60), (sx * 0.85, 0, 1.85), (0, 0, 0), mat_idx=2, bevel=0.03)
                # Angled chamfer shoulder
                add_box(bm, (1.15, 1.18, 0.65), (sx * 0.72, 0, 3.72), (0, 42 if sx < 0 else -42, 0), mat_idx=2, bevel=0.04)
            add_box(bm, (5.95, 1.34, 0.88), (0, 0, 4.30), (0, 0, 0), mat_idx=2, bevel=0.06)
            add_box(bm, (4.30, 1.28, 0.14), (0, 0, 3.84), (0, 0, 0), mat_idx=3, bevel=0.01)
        finalize_and_export(obj, mesh, bm, os.path.join(out, f"{tname}.glb"), uv_scale=0.55)


# ==============================================================================
# 3. ENV_CryoGlacier — GELEIRA & RUINAS CRIOGENICAS (REF 4)
# ==============================================================================
def build_cryo_glacier():
    out = os.path.join(OUT_ROOT, "ENV_CryoGlacier")

    def mats():
        return [
            make_mat("MAT_GlacierMountain", (0.72, 0.86, 0.96, 1.0), 0.04, 0.55),
            make_mat("MAT_SnowRock", (0.86, 0.92, 0.98, 1.0), 0.03, 0.72),
            make_mat("MAT_DeepGlacierIce", (0.16, 0.48, 0.78, 1.0), 0.08, 0.12),
            make_mat("MAT_CryoCrystal", (0.20, 0.92, 1.00, 1.0), 0.10, 0.06, emission=4.2),
            make_mat("MAT_IceFloor", (0.62, 0.82, 0.96, 1.0), 0.06, 0.10),
            make_mat("MAT_Aurora", (0.20, 0.95, 0.75, 1.0), 0.0, 1.0, emission=1.8, alpha=0.55),
            make_mat("MAT_OutpostSteel", (0.22, 0.26, 0.32, 1.0), 0.78, 0.40),
        ]

    # BACKDROP: High-resolution smooth sculpted alpine mountain amphitheater + grounded glacial cliffs + Aurora!
    obj, mesh = new_scene_mesh("BACKDROP", mats)
    bm = bmesh.new()
    for i in range(24):
        a = (i / 24.0) * math.tau
        is_valley = (abs(a - math.pi * 0.5) < 0.44)
        r = 48.0 + (i % 3) * 7.0
        h = (10.0 if is_valley else 18.5 + (i % 4) * 5.2)
        rad = 15.5 + (i % 3) * 4.0
        px, py = math.cos(a) * r, math.sin(a) * r
        add_sculpted_peak(bm, rad, rad * 0.22, h, (px, py, -1.2), rings=14, segs=28, seed=200 + i, mat_idx=0, ridge_amp=0.36, angular=True)
        # Grounded towering translucent blue glacial ice monoliths along inner shore rim (never floating!)
        if i % 4 == 0 and not is_valley:
            add_sculpted_peak(bm, 6.2, 0.55, 22.0 + (i % 2) * 6.5, (math.cos(a) * 40.5, math.sin(a) * 40.5, -1.5), rings=12, segs=18, seed=300 + i, mat_idx=2, ridge_amp=0.28, angular=True)

    # Distant colossal high-res snow-capped alpine peaks towering behind the valley (r = 98..140m)
    for i in range(18):
        a = (i / 18.0) * math.tau + 0.12
        r = 102.0 + (i % 3) * 18.0
        h = 46.0 + (i % 4) * 11.0
        rad = 34.0 + (i % 3) * 9.0
        px, py = math.cos(a) * r, math.sin(a) * r
        add_sculpted_peak(bm, rad, 1.0, h, (px, py, -2.0), rings=16, segs=32, seed=400 + i, mat_idx=0, ridge_amp=0.40, angular=True)
        add_sculpted_peak(bm, rad * 0.72, 1.4, h * 0.66, (px + math.cos(a + 1.2) * 20.0, py + math.sin(a + 1.2) * 20.0, -2.0), rings=12, segs=24, seed=450 + i, mat_idx=0, ridge_amp=0.38, angular=True)

    # Subtle frozen sci-fi outpost wall & sloped access bridge embedded into right-hand glacier cliff (matching Ref 4!)
    ox, oy = 30.0, 40.0
    add_box(bm, (16.0, 5.5, 8.5), (ox, oy, 7.5), (0, 0, -28), mat_idx=6, bevel=0.08)
    add_box(bm, (4.2, 16.0, 1.4), (ox - 6.5, oy - 7.5, 3.8), (-22, 0, -28), mat_idx=6, bevel=0.06)

    # Sweeping Aurora Borealis curtains high in the northern arctic sky (Blender +Y -> Godot -Z)
    for ribbon_idx, (ry, rz, rh, curve) in enumerate([(118.0, 52.0, 26.0, 0.16), (132.0, 62.0, 24.0, -0.14)]):
        segs_u, segs_v = 28, 4
        rverts = []
        for iv in range(segs_v + 1):
            tv = iv / float(segs_v)
            row = []
            for iu in range(segs_u + 1):
                tu = iu / float(segs_u)
                ang = (tu - 0.5) * 1.45
                xx = math.sin(ang) * ry
                yy = math.cos(ang) * ry + math.sin(tu * math.tau * 1.5 + ribbon_idx) * 12.0 * curve
                zz = rz + tv * rh + math.sin(tu * math.pi * 2.0) * 4.5
                row.append(bm.verts.new((xx, yy, zz)))
            rverts.append(row)
        uv_layer = bm.loops.layers.uv.verify()
        for iv in range(segs_v):
            for iu in range(segs_u):
                f = bm.faces.new((rverts[iv][iu], rverts[iv][iu + 1], rverts[iv + 1][iu + 1], rverts[iv + 1][iu]))
                f.material_index = 5
                f.smooth = True
    # Note: finalize_and_export calls apply_box_uv, so let's compute clean UV on Aurora AFTER box_uv!
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    apply_box_uv(bm, uv_scale=0.10)
    uv_layer = bm.loops.layers.uv.verify()
    for f in bm.faces:
        if f.material_index == 5:
            for l in f.loops:
                co = l.vert.co
                u = (math.atan2(co.x, max(1.0, co.y)) / 1.45) + 0.5
                v = max(0.0, min(1.0, (co.z - 48.0) / 36.0))
                l[uv_layer].uv = (u, v)
    bm.to_mesh(mesh)
    bm.free()
    os.makedirs(out, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, "BACKDROP.glb"), export_format='GLB', use_selection=False, export_materials='EXPORT', export_yup=True)

    # FLOOR: Frozen glacial lake floor driven by biome_ice_floor.gdshader
    obj, mesh = new_scene_mesh("FLOOR", mats)
    bm = bmesh.new()
    add_cone(bm, 48, 39.5, 39.5, 0.18, (0, 0, -0.09), (0, 0, 0), mat_idx=4)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "FLOOR.glb"), uv_scale=0.22)

    # WFC TILES: Sculpted glacial rock/ice + glowing faceted crystal clusters + natural stone-ice monolith arches
    for tname in ["TILE_Open", "TILE_CoverLow", "TILE_Pillar", "TILE_WallStraight", "TILE_WallCorner", "TILE_Arch"]:
        obj, mesh = new_scene_mesh(tname, mats)
        bm = bmesh.new()
        if tname == "TILE_Open":
            add_rock(bm, 0.34, (1.8, -1.6, 0.06), (1.35, 1.05, 0.36), seed=210, mat_idx=0, subdivs=2, amp=0.28)
            add_cone(bm, 6, 0.14, 0.02, 0.52, (1.95, -1.45, 0.24), (16, 14, 20), mat_idx=3)
        elif tname == "TILE_CoverLow":
            # High-res sculpted snow-capped glacial boulder + vibrant 7-prism glowing cyan crystal cluster (Ref 4!)
            add_rock(bm, 0.96, (-0.25, 0.0, 0.44), (1.68, 0.78, 0.76), seed=221, mat_idx=0, subdivs=3, amp=0.38, ridged=True, smooth=True)
            add_rock(bm, 0.66, (1.05, 0.12, 0.34), (1.10, 0.75, 0.68), seed=222, mat_idx=2, subdivs=3, amp=0.34, ridged=True, smooth=True)
            for cx, cy, ch, cr, tilt in [
                (-0.95, 0.20, 2.15, 0.34, (18, 24, 12)),
                (-0.55, -0.26, 1.65, 0.28, (-24, 18, 48)),
                (-1.28, -0.10, 1.40, 0.24, (30, -18, 82)),
                (-0.78, 0.45, 1.25, 0.22, (26, 12, -30)),
                (0.95, -0.22, 1.90, 0.30, (-16, -26, 30)),
                (1.28, 0.18, 1.40, 0.24, (24, -22, -40)),
                (0.62, 0.36, 1.20, 0.20, (-28, -12, 70)),
            ]:
                add_cone(bm, 6, cr, 0.02, ch, (cx, cy, ch * 0.44), tilt, mat_idx=3)
        elif tname == "TILE_Pillar":
            # Alien Cryo Monolith / Glacial Crystal Spire (matching Ref 4 central monolith!)
            add_rock(bm, 1.15, (0, 0, 0.35), (1.25, 1.15, 0.52), seed=231, mat_idx=0, subdivs=3, amp=0.32, smooth=True)
            add_sculpted_peak(bm, 0.92, 0.14, 4.95, (-0.32, 0.0, 0.25), rings=10, segs=16, seed=232, mat_idx=0, ridge_amp=0.30, angular=True)
            add_sculpted_peak(bm, 0.78, 0.12, 4.35, (0.38, 0.12, 0.25), rings=10, segs=16, seed=233, mat_idx=2, ridge_amp=0.30, angular=True)
            add_cone(bm, 6, 0.56, 0.03, 2.55, (0.02, -0.08, 2.55), (0, 0, 15), mat_idx=3)
            add_cone(bm, 6, 0.56, 0.03, 1.35, (0.02, -0.08, 0.78), (180, 0, 15), mat_idx=3)
            for ang_d in [0, 72, 144, 216, 288]:
                a = math.radians(ang_d)
                add_cone(bm, 6, 0.30, 0.02, 2.25, (math.cos(a) * 0.78, math.sin(a) * 0.78, 0.96), (24, -18, ang_d), mat_idx=3)
        elif tname == "TILE_WallStraight":
            for ox, sd, mi in [(-2.0, 241, 0), (-0.65, 242, 2), (0.75, 243, 0), (2.05, 244, 2)]:
                add_rock(bm, 1.18, (ox, 0.0, 1.05), (1.05, 0.76, 1.25), seed=sd, mat_idx=mi, subdivs=3, amp=0.38, ridged=True, smooth=True)
            # Prominent bioluminescent cyan crystal clusters bursting from wall sides (Ref 4!)
            for cx, cy, ch, cr, tilt in [(-1.2, 0.65, 2.2, 0.32, (26, 16, 20)), (0.0, -0.58, 2.6, 0.36, (-22, -14, 45)), (1.15, 0.62, 1.85, 0.28, (28, -20, -30))]:
                add_cone(bm, 6, cr, 0.02, ch, (cx, cy, ch * 0.45), tilt, mat_idx=3)
        elif tname == "TILE_WallCorner":
            for pos, sd, mi in [((1.45, 0, 1.05), 251, 0), ((0, 1.45, 1.05), 252, 2), ((0, 0, 1.35), 253, 0)]:
                add_rock(bm, 1.26, pos, (1.02, 1.02, 1.28), seed=sd, mat_idx=mi, subdivs=3, amp=0.36, ridged=True, smooth=True)
            for cx, cy, ch, cr, tilt in [(0.0, 0.0, 3.6, 0.44, (8, -6, 12)), (0.75, 0.72, 2.1, 0.30, (24, 22, 40)), (-0.62, 0.65, 1.7, 0.26, (-20, 26, -15))]:
                add_cone(bm, 6, cr, 0.02, ch, (cx, cy, ch * 0.50), tilt, mat_idx=3)
        elif tname == "TILE_Arch":
            # Iconic weathered natural stone-and-ice curved monolith arch (Ref 4!)
            add_organic_arch(bm, span_x=4.65, height_z=4.25, base_r=0.88, top_r=0.58, segs_arc=13, segs_ring=12, seed=260, mat_idx=0, disp=0.26)
            add_rock(bm, 0.88, (-2.30, 0.0, 0.42), (1.15, 1.05, 0.72), seed=261, mat_idx=2, subdivs=2, amp=0.26)
            add_rock(bm, 0.88, (2.30, 0.0, 0.42), (1.15, 1.05, 0.72), seed=262, mat_idx=2, subdivs=2, amp=0.26)
            add_cone(bm, 6, 0.24, 0.02, 1.35, (-1.85, 0.35, 0.65), (20, 16, 10), mat_idx=3)
        finalize_and_export(obj, mesh, bm, os.path.join(out, f"{tname}.glb"), uv_scale=0.45)


# ==============================================================================
# 4. ENV_VolcanicCaldera — CALDEIRA VULCANICA OBSIDIANA (REF 5)
# ==============================================================================
def build_volcanic_caldera():
    out = os.path.join(OUT_ROOT, "ENV_VolcanicCaldera")

    def mats():
        return [
            make_mat("MAT_ObsidianRock", (0.06, 0.055, 0.06, 1.0), 0.14, 0.62),
            make_mat("MAT_BasaltRock", (0.11, 0.095, 0.095, 1.0), 0.10, 0.72),
            make_mat("MAT_LavaSea", (1.00, 0.26, 0.02, 1.0), 0.0, 0.22, emission=4.6),
            make_mat("MAT_MagmaGlow", (1.00, 0.56, 0.08, 1.0), 0.0, 0.20, emission=5.4),
            make_mat("MAT_ObsidianFloor", (0.07, 0.06, 0.06, 1.0), 0.10, 0.68),
            make_mat("MAT_VolcanoCone", (0.08, 0.06, 0.06, 1.0), 0.08, 0.78),
        ]

    # BACKDROP: Churning molten lava sea + Colossal Erupting Stratovolcano in -Z + jagged columnar basalt caldera rim!
    obj, mesh = new_scene_mesh("BACKDROP", mats)
    bm = bmesh.new()
    # Surrounding molten lava ocean (z = -0.58m, driven by biome_lava_sea.gdshader)
    add_cone(bm, 48, 170.0, 170.0, 0.20, (0, 0, -0.68), (0, 0, 0), mat_idx=2)

    # Colossal Erupting Stratovolcano dominating horizon (jagged concave caldera rim, NO solid glowing bulb!)
    vx, vy = 16.0, 96.0
    add_sculpted_peak(bm, 66.0, 10.5, 58.0, (vx, vy, -1.0), rings=14, segs=36, seed=501, mat_idx=5, ridge_amp=0.28, angular=False, crater_depth=6.5)
    # Recessed molten magma pool deep inside caldera crater
    add_cone(bm, 24, 9.2, 8.8, 1.4, (vx, vy, 53.0), (0, 0, 0), mat_idx=3)

    # Flanking jagged columnar basalt caldera cliffs (wide open sightline toward volcano + lower under SM_Ship!)
    for i in range(22):
        a = (i / 22.0) * math.tau
        if abs(a - math.pi * 0.45) < 0.62:
            continue
        r = 50.0 + (i % 3) * 11.0
        px, py = math.cos(a) * r, math.sin(a) * r
        h = (13.0 if (px < -15.0 and py > 20.0) else 17.0 + (i % 4) * 5.5)
        add_sculpted_peak(bm, 11.0 + (i % 3) * 3.0, 3.5, h, (px, py, -1.0), rings=9, segs=18, seed=520 + i, mat_idx=1, ridge_amp=0.30)
        for k in range(3):
            ca = a + (k - 1) * 0.08
            ch = h * (0.65 + k * 0.14)
            add_cone(bm, 6, 2.8, 2.5, ch, (math.cos(ca) * (r - 6.0), math.sin(ca) * (r - 6.0), ch * 0.45), (0, 0, i * 17 + k * 25), mat_idx=0)
    finalize_and_export(obj, mesh, bm, os.path.join(out, "BACKDROP.glb"), uv_scale=0.10)

    # FLOOR: Sculpted organic circular obsidian island with rocky jagged cliff edge dropping into lava sea!
    obj, mesh = new_scene_mesh("FLOOR", mats)
    bm = bmesh.new()
    segs = 64
    center_v = bm.verts.new((0.0, 0.0, 0.0))
    rings_r = [12.0, 24.0, 33.8, 35.8]
    ring_vs = []
    for ri, rr in enumerate(rings_r):
        row = []
        for si in range(segs):
            a = (si / float(segs)) * math.tau
            jitter = noise.noise(Vector((math.cos(a) * 2.8, math.sin(a) * 2.8, ri * 1.3))) * (1.8 if ri >= 2 else 0.0)
            r_now = rr + jitter
            z = 0.0 if ri < 3 else -0.78
            row.append(bm.verts.new((math.cos(a) * r_now, math.sin(a) * r_now, z)))
        ring_vs.append(row)
    for si in range(segs):
        s2 = (si + 1) % segs
        f = bm.faces.new((center_v, ring_vs[0][si], ring_vs[0][s2]))
        f.material_index = 4
        f.smooth = True
    for ri in range(len(ring_vs) - 1):
        for si in range(segs):
            s2 = (si + 1) % segs
            f = bm.faces.new((ring_vs[ri][si], ring_vs[ri][s2], ring_vs[ri + 1][s2], ring_vs[ri + 1][si]))
            f.material_index = 4 if ri < 2 else 1
            f.smooth = True
    finalize_and_export(obj, mesh, bm, os.path.join(out, "FLOOR.glb"), uv_scale=0.25)

    # WFC TILES: Giant's Causeway hexagonal basalt columns, jagged volcanic crags, curved magma-veined obsidian arch (Ref 5!)
    for tname in ["TILE_Open", "TILE_CoverLow", "TILE_Pillar", "TILE_WallStraight", "TILE_WallCorner", "TILE_Arch"]:
        obj, mesh = new_scene_mesh(tname, mats)
        bm = bmesh.new()
        if tname == "TILE_Open":
            add_rock(bm, 0.34, (-1.7, 1.5, 0.05), (1.30, 1.00, 0.34), seed=541, mat_idx=1, subdivs=2, amp=0.30, ridged=True)
        elif tname == "TILE_CoverLow":
            # Stepped dark hexagonal basalt column cluster + sharp volcanic rock cover
            for ox, oy, h, r, m in [(-0.95, 0.05, 1.22, 0.56, 1), (-0.15, -0.10, 0.96, 0.52, 0), (0.68, 0.12, 1.10, 0.50, 1), (1.30, -0.18, 0.62, 0.44, 0)]:
                add_cone(bm, 6, r, r * 0.94, h, (ox, oy, h * 0.5), (0, 0, 18), mat_idx=m)
            add_rock(bm, 0.72, (-0.35, 0.25, 0.42), (1.35, 0.82, 0.65), seed=551, mat_idx=0, subdivs=3, amp=0.34, ridged=True)
            add_box(bm, (2.1, 0.16, 0.05), (0, 0, 0.03), (0, 0, 8), mat_idx=3, bevel=0.0)
        elif tname == "TILE_Pillar":
            # Authentic Giant's Causeway 9-column hexagonal basalt cluster (Ref 5 foreground!)
            cols = [
                (0.0, 0.0, 4.7, 0.56, 1),
                (0.84, 0.36, 3.6, 0.52, 0),
                (-0.82, 0.42, 3.2, 0.50, 1),
                (0.18, -0.88, 2.7, 0.50, 0),
                (-0.78, -0.64, 2.1, 0.46, 1),
                (0.96, -0.58, 1.8, 0.46, 0),
                (-0.08, 0.92, 2.4, 0.48, 0),
                (1.42, 0.02, 1.3, 0.42, 1),
                (-1.38, -0.08, 1.1, 0.42, 0),
            ]
            for ox, oy, h, r, m in cols:
                add_cone(bm, 6, r, r * 0.95, h, (ox, oy, h * 0.5), (0, 0, 15), mat_idx=m)
            add_cone(bm, 6, 0.95, 0.95, 0.10, (0, 0, 0.05), (0, 0, 15), mat_idx=3)
        elif tname == "TILE_WallStraight":
            # Dense wall of staggered hexagonal basalt columns + sharp volcanic boulders
            for ox, h, r, m in [(-2.4, 2.3, 0.62, 1), (-1.45, 2.6, 0.58, 0), (-0.5, 2.1, 0.60, 1), (0.45, 2.7, 0.60, 0), (1.42, 2.2, 0.58, 1), (2.38, 2.4, 0.62, 0)]:
                add_cone(bm, 6, r, r * 0.92, h, (ox, 0.0, h * 0.5), (0, 0, 15), mat_idx=m)
            add_rock(bm, 0.92, (0.0, 0.0, 0.85), (2.4, 0.72, 0.95), seed=561, mat_idx=0, subdivs=3, amp=0.35, ridged=True)
            add_box(bm, (TILE_SIZE - 0.4, 0.22, 0.06), (0, 0, 0.04), (0, 0, 0), mat_idx=3, bevel=0.0)
        elif tname == "TILE_WallCorner":
            for ox, oy, h, r, m in [(0, 0, 3.3, 0.78, 1), (1.05, 0, 2.5, 0.64, 0), (2.05, 0, 2.1, 0.58, 1), (0, 1.05, 2.6, 0.64, 0), (0, 2.05, 2.0, 0.58, 1), (0.75, 0.75, 1.7, 0.54, 0)]:
                add_cone(bm, 6, r, r * 0.93, h, (ox, oy, h * 0.5), (0, 0, 15), mat_idx=m)
        elif tname == "TILE_Arch":
            # Iconic curved scorched obsidian rock arch with glowing lava vein running underneath (Ref 5!)
            add_organic_arch(bm, span_x=4.75, height_z=3.85, base_r=0.92, top_r=0.62, segs_arc=13, segs_ring=12, seed=570, mat_idx=0, disp=0.30)
            # Glowing magma vein ribbon embedded along the inner soffit of the arch
            vein_pts = []
            for k in range(11):
                ang = math.pi * (0.08 + 0.84 * (k / 10.0))
                vein_pts.append(Vector((-math.cos(ang) * 2.05, 0.0, math.sin(ang) * 3.32)))
            add_tube_along_points(bm, vein_pts, radius=0.14, segs=6, mat_idx=3)
            add_rock(bm, 0.95, (-2.35, 0.0, 0.48), (1.10, 0.95, 0.72), seed=571, mat_idx=1, subdivs=2, amp=0.32, ridged=True)
            add_rock(bm, 0.95, (2.35, 0.0, 0.48), (1.10, 0.95, 0.72), seed=572, mat_idx=1, subdivs=2, amp=0.32, ridged=True)
        finalize_and_export(obj, mesh, bm, os.path.join(out, f"{tname}.glb"), uv_scale=0.45)


build_coast_props()
build_sand_pyramid()
build_mothership_interior()
build_cryo_glacier()
build_volcanic_caldera()
print("GENERATED_PHOTOREAL_BIOMES_OK")
