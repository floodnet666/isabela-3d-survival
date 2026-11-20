class_name WFCSolver
extends RefCounted
## Deterministic 2D Wave Function Collapse (WFC) solver with socket matching, rotations, safe clearing, and guaranteed doorway connectivity.

const DX := [0, 1, 0, -1]
const DZ := [-1, 0, 1, 0]
const OPP := [2, 3, 0, 1]


static func solve(grid_size: int, tiles_cfg: Array, rng_seed: int, clear_center_radius: int = 1, max_attempts: int = 10, forced_open_cells: Array[Vector2i] = []) -> Dictionary:
	var n := maxi(3, grid_size)
	var states := _expand_states(tiles_cfg)
	if states.is_empty():
		return {"ok": false, "grid": [], "attempts": 0}
	var open_idx := _find_open_state(states)
	var compat := _build_compat_table(states)
	var center := int(n / 2)
	for attempt in range(maxi(1, max_attempts)):
		var rng := RandomNumberGenerator.new()
		rng.seed = rng_seed + attempt * 7919
		var cells := _run_once(n, states, compat, open_idx, center, clear_center_radius, rng, forced_open_cells)
		if not cells.is_empty():
			var out_grid: Array = []
			for z in range(n):
				var row: Array = []
				for x in range(n):
					var st: Dictionary = states[int(cells[z * n + x][0])]
					row.append({"id": str(st["id"]), "rot": int(st["rot"]), "sockets": st["sockets"]})
				out_grid.append(row)
			ensure_connectivity_and_doors(out_grid)
			return {"ok": true, "grid": out_grid, "attempts": attempt + 1}
	return {"ok": false, "grid": [], "attempts": max_attempts}


static func validate_adjacency(grid: Array) -> bool:
	var n := grid.size()
	for z in range(n):
		for x in range(n):
			var sock: Array = (grid[z][x] as Dictionary).get("sockets", [])
			if sock.size() < 4: return false
			if x + 1 < n and str(sock[1]) != str((grid[z][x + 1] as Dictionary).get("sockets", [])[3]): return false
			if z + 1 < n and str(sock[2]) != str((grid[z + 1][x] as Dictionary).get("sockets", [])[0]): return false
	return true


static func ensure_connectivity_and_doors(grid: Array) -> void:
	var n := grid.size()
	if n == 0: return
	var c := int(n / 2)
	_clear_arch_adjacent_props(grid, n)
	for _guard in range(n * n):
		var visited := _bfs_visited(grid, n, c, c)
		var unvis := _collect_unvisited(grid, n, visited)
		if unvis.is_empty(): break
		if not _open_bridging_wall_straight(grid, n, visited, unvis):
			_open_separating_wall_cycle(grid, n, unvis)
		_clear_arch_adjacent_props(grid, n)

	for z in range(1, n - 1):
		for x in range(1, n - 1):
			if _is_solid_wall(grid[z][x]) or _is_arch(grid[z][x]): continue
			var wall_dirs: Array[int] = []; var arch_dirs: Array[int] = []; var open_dir := -1
			for d in range(4):
				var nb: Dictionary = grid[z + DZ[d]][x + DX[d]]
				if _is_solid_wall(nb): wall_dirs.append(d)
				elif _is_arch(nb) and str((nb["sockets"] as Array)[OPP[d]]) == "open": arch_dirs.append(d)
				else: open_dir = d
			if wall_dirs.size() >= 3 and arch_dirs.is_empty():
				for wd in wall_dirs:
					var wx: int = x + DX[wd]; var wz: int = z + DZ[wd]; var wcell: Dictionary = grid[wz][wx]
					if str(wcell.get("id", "")) != "TILE_WallStraight": continue
					var fx: int = wx + DX[wd]; var fz: int = wz + DZ[wd]
					if fx >= 0 and fx < n and fz >= 0 and fz < n and not _is_solid_wall(grid[fz][fx]):
						wcell["id"] = "TILE_Arch"
						if _is_prop_obstacle(grid[fz][fx]): grid[fz][fx] = _make_open_cell()
						break
				if open_dir != -1 and _is_prop_obstacle(grid[z + DZ[open_dir]][x + DX[open_dir]]):
					grid[z + DZ[open_dir]][x + DX[open_dir]] = _make_open_cell()
	_clear_arch_adjacent_props(grid, n)


static func validate_connectivity(grid: Array) -> bool:
	var n := grid.size()
	if n == 0: return false
	var c := int(n / 2)
	var visited := _bfs_visited(grid, n, c, c)
	for z in range(n):
		for x in range(n):
			var cell: Dictionary = grid[z][x]
			if _is_arch(cell):
				var sock: Array = cell.get("sockets", [])
				for d in range(4):
					if str(sock[d]) == "open":
						var nx: int = x + DX[d]; var nz: int = z + DZ[d]
						if nx >= 0 and nx < n and nz >= 0 and nz < n and _is_prop_obstacle(grid[nz][nx]): return false
			if _is_solid_wall(cell): continue
			if not bool(visited[z * n + x]): return false
			if not _is_arch(cell):
				var walls := 0; var open_blocked := false; var has_arch := false
				for d in range(4):
					var nx: int = x + DX[d]; var nz: int = z + DZ[d]
					if nx < 0 or nx >= n or nz < 0 or nz >= n: continue
					var nb: Dictionary = grid[nz][nx]
					if _is_solid_wall(nb): walls += 1
					elif _is_arch(nb) and str((nb["sockets"] as Array)[OPP[d]]) == "open": has_arch = true
					elif _is_prop_obstacle(nb): open_blocked = true
				if walls >= 4 or (walls >= 3 and open_blocked and not has_arch): return false
	return true


static func _is_solid_wall(cell: Dictionary) -> bool:
	var tid := str(cell.get("id", "")); return tid == "TILE_WallStraight" or tid == "TILE_WallCorner"

static func _is_arch(cell: Dictionary) -> bool:
	return str(cell.get("id", "")) == "TILE_Arch"

static func _is_prop_obstacle(cell: Dictionary) -> bool:
	var tid := str(cell.get("id", "")); return tid == "TILE_Pillar" or tid == "TILE_CoverLow"

static func _make_open_cell() -> Dictionary:
	return {"id": "TILE_Open", "rot": 0, "sockets": PackedStringArray(["open", "open", "open", "open"])}


static func _can_step(grid: Array, n: int, cx: int, cz: int, d: int) -> bool:
	var nx: int = cx + DX[d]; var nz: int = cz + DZ[d]
	if nx < 0 or nx >= n or nz < 0 or nz >= n: return false
	var a: Dictionary = grid[cz][cx]; var b: Dictionary = grid[nz][nx]
	if _is_solid_wall(a) or _is_solid_wall(b): return false
	if _is_arch(a) and str((a["sockets"] as Array)[d]) != "open": return false
	if _is_arch(b) and str((b["sockets"] as Array)[OPP[d]]) != "open": return false
	return true


static func _bfs_visited(grid: Array, n: int, sx: int, sz: int) -> PackedByteArray:
	var vis := PackedByteArray(); vis.resize(n * n)
	if _is_solid_wall(grid[sz][sx]): return vis
	var q: Array[int] = [sz * n + sx]; vis[sz * n + sx] = 1; var head := 0
	while head < q.size():
		var cur := q[head]; head += 1; var cx := cur % n; var cz := int(cur / n)
		for d in range(4):
			if not _can_step(grid, n, cx, cz, d): continue
			var ni: int = (cz + DZ[d]) * n + (cx + DX[d])
			if vis[ni] == 0: vis[ni] = 1; q.append(ni)
	return vis


static func _collect_unvisited(grid: Array, n: int, visited: PackedByteArray) -> Dictionary:
	var unvis := {}
	for z in range(n):
		for x in range(n):
			if not _is_solid_wall(grid[z][x]) and visited[z * n + x] == 0: unvis[z * n + x] = true
	return unvis


static func _open_bridging_wall_straight(grid: Array, n: int, visited: PackedByteArray, unvis: Dictionary) -> bool:
	for z in range(1, n - 1):
		for x in range(1, n - 1):
			var cell: Dictionary = grid[z][x]
			if str(cell.get("id", "")) != "TILE_WallStraight": continue
			var open_dirs: Array[int] = []
			for d in range(4):
				if str((cell["sockets"] as Array)[d]) == "open": open_dirs.append(d)
			if open_dirs.size() < 2: continue
			var i0: int = (z + DZ[open_dirs[0]]) * n + (x + DX[open_dirs[0]])
			var i1: int = (z + DZ[open_dirs[1]]) * n + (x + DX[open_dirs[1]])
			if (visited[i0] == 1 and unvis.has(i1)) or (visited[i1] == 1 and unvis.has(i0)):
				cell["id"] = "TILE_Arch"; return true
	return false


static func _open_separating_wall_cycle(grid: Array, n: int, unvis: Dictionary) -> void:
	for k in unvis.keys():
		var idx := int(k); var ux := idx % n; var uz := int(idx / n)
		for d in range(4):
			var wx: int = ux + DX[d]; var wz: int = uz + DZ[d]
			if wx < 0 or wx >= n or wz < 0 or wz >= n or not _is_solid_wall(grid[wz][wx]): continue
			var cq: Array[int] = [wz * n + wx]; var seen := {wz * n + wx: true}; var head := 0
			while head < cq.size():
				var cur := cq[head]; head += 1; var cx := cur % n; var cz := int(cur / n)
				var socks: Array = (grid[cz][cx] as Dictionary).get("sockets", [])
				for sd in range(4):
					if str(socks[sd]) != "wall": continue
					var nx: int = cx + DX[sd]; var nz: int = cz + DZ[sd]; var ni := nz * n + nx
					if nx >= 0 and nx < n and nz >= 0 and nz < n and not seen.has(ni):
						seen[ni] = true; cq.append(ni)
			for ci in cq: grid[int(ci / n)][ci % n] = _make_open_cell()
			return


static func _clear_arch_adjacent_props(grid: Array, n: int) -> void:
	for z in range(n):
		for x in range(n):
			var cell: Dictionary = grid[z][x]
			if not _is_arch(cell): continue
			var socks: Array = cell.get("sockets", [])
			for d in range(4):
				if str(socks[d]) != "open": continue
				var nx: int = x + DX[d]; var nz: int = z + DZ[d]
				if nx >= 0 and nx < n and nz >= 0 and nz < n and _is_prop_obstacle(grid[nz][nx]):
					grid[nz][nx] = _make_open_cell()


static func _expand_states(tiles_cfg: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t_var in tiles_cfg:
		if not (t_var is Dictionary): continue
		var t: Dictionary = t_var as Dictionary
		var tid := str(t.get("id", "")); var base_s: Array = t.get("sockets", ["open", "open", "open", "open"])
		if tid.is_empty() or base_s.size() < 4: continue
		var weight := maxf(0.01, float(t.get("weight", 1.0))); var seen := {}
		for r in range(4 if bool(t.get("allow_rotate", true)) else 1):
			var rot_s := _rotate_sockets(base_s, r); var key := ",".join(rot_s)
			if not seen.has(key):
				seen[key] = true; out.append({"id": tid, "rot": r, "sockets": rot_s, "weight": weight})
	return out


static func _rotate_sockets(s: Array, steps: int) -> PackedStringArray:
	var res := PackedStringArray([str(s[0]), str(s[1]), str(s[2]), str(s[3])])
	for _i in range(steps % 4): res = PackedStringArray([res[3], res[0], res[1], res[2]])
	return res

static func _find_open_state(states: Array[Dictionary]) -> int:
	for i in range(states.size()):
		var s: PackedStringArray = states[i]["sockets"]
		if s[0] == "open" and s[1] == "open" and s[2] == "open" and s[3] == "open" and str(states[i]["id"]) == "TILE_Open": return i
	return 0

static func _build_compat_table(states: Array[Dictionary]) -> Array:
	var table: Array = []
	for i in range(states.size()):
		var dirs: Array = [[], [], [], []]; var si: PackedStringArray = states[i]["sockets"]
		for d in range(4):
			var need := si[d]; var opp_d: int = OPP[d]
			for j in range(states.size()):
				if (states[j]["sockets"] as PackedStringArray)[opp_d] == need: (dirs[d] as Array).append(j)
		table.append(dirs)
	return table


static func _run_once(n: int, states: Array[Dictionary], compat: Array, open_idx: int, center: int, clear_r: int, rng: RandomNumberGenerator, forced_open_cells: Array[Vector2i] = []) -> Array:
	var all_idx: Array[int] = []; for i in range(states.size()): all_idx.append(i)
	var cells: Array = []; cells.resize(n * n)
	for i in range(n * n): cells[i] = all_idx.duplicate()
	var forced_set := {}; for fc in forced_open_cells: forced_set[fc] = true
	var queue: Array[int] = []
	for z in range(n):
		for x in range(n):
			var outside := n >= 9 and Vector2(float(x - center), float(z - center)).length() > float(center) - 0.6
			if (absi(x - center) <= clear_r and absi(z - center) <= clear_r) or x == 0 or z == 0 or x == n - 1 or z == n - 1 or outside or forced_set.has(Vector2i(x, z)):
				var idx := z * n + x; cells[idx] = [open_idx]; queue.append(idx)
	if not _propagate(n, cells, compat, queue): return []
	while true:
		var pick_cell := _pick_lowest_entropy(cells, rng)
		if pick_cell == -1: return cells
		cells[pick_cell] = [_weighted_choice(cells[pick_cell] as Array, states, rng)]
		if not _propagate(n, cells, compat, [pick_cell]): return []
	return []

static func _pick_lowest_entropy(cells: Array, rng: RandomNumberGenerator) -> int:
	var best_len := 999999; var ties: Array[int] = []
	for i in range(cells.size()):
		var cnt: int = (cells[i] as Array).size()
		if cnt <= 1: continue
		if cnt < best_len: best_len = cnt; ties = [i]
		elif cnt == best_len: ties.append(i)
	return -1 if ties.is_empty() else ties[rng.randi_range(0, ties.size() - 1)]

static func _weighted_choice(opts: Array, states: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	var total := 0.0; for idx in opts: total += float(states[int(idx)]["weight"])
	var r := rng.randf_range(0.0, maxf(0.001, total)); var acc := 0.0
	for idx in opts:
		acc += float(states[int(idx)]["weight"])
		if r <= acc: return int(idx)
	return int(opts[opts.size() - 1])

static func _propagate(n: int, cells: Array, compat: Array, queue: Array[int]) -> bool:
	var head := 0
	while head < queue.size():
		var cur := queue[head]; head += 1; var cx := cur % n; var cz := int(cur / n); var cur_opts: Array = cells[cur]
		for d in range(4):
			var nx: int = cx + int(DX[d]); var nz: int = cz + int(DZ[d])
			if nx < 0 or nx >= n or nz < 0 or nz >= n: continue
			var nidx := nz * n + nx; var allowed := {}
			for st_i in cur_opts:
				for ok_j in compat[int(st_i)][d]: allowed[int(ok_j)] = true
			var n_opts: Array = cells[nidx]; var kept: Array = []
			for st_j in n_opts:
				if allowed.has(int(st_j)): kept.append(st_j)
			if kept.size() < n_opts.size():
				if kept.is_empty(): return false
				cells[nidx] = kept; queue.append(nidx)
	return true
