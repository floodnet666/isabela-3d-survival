class_name WFCSolver
extends RefCounted
## Deterministic 2D Wave Function Collapse (WFC) solver with socket matching, rotations, and safe center spawn clearing.

# Directions: 0 = N (-Z), 1 = E (+X), 2 = S (+Z), 3 = W (-X)
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
			return {"ok": true, "grid": out_grid, "attempts": attempt + 1}

	return {"ok": false, "grid": [], "attempts": max_attempts}


static func validate_adjacency(grid: Array) -> bool:
	var n := grid.size()
	for z in range(n):
		for x in range(n):
			var c: Dictionary = grid[z][x]
			var sock: Array = c.get("sockets", [])
			if sock.size() < 4:
				return false
			if x + 1 < n:
				var e_sock: Array = (grid[z][x + 1] as Dictionary).get("sockets", [])
				if str(sock[1]) != str(e_sock[3]):
					return false
			if z + 1 < n:
				var s_sock: Array = (grid[z + 1][x] as Dictionary).get("sockets", [])
				if str(sock[2]) != str(s_sock[0]):
					return false
	return true


static func _expand_states(tiles_cfg: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t_var in tiles_cfg:
		if not (t_var is Dictionary):
			continue
		var t: Dictionary = t_var as Dictionary
		var tid := str(t.get("id", ""))
		var base_s: Array = t.get("sockets", ["open", "open", "open", "open"])
		if tid.is_empty() or base_s.size() < 4:
			continue
		var weight := maxf(0.01, float(t.get("weight", 1.0)))
		var allow_rot := bool(t.get("allow_rotate", true))
		var seen := {}
		var max_r := 4 if allow_rot else 1
		for r in range(max_r):
			var rot_s := _rotate_sockets(base_s, r)
			var key := ",".join(rot_s)
			if seen.has(key):
				continue
			seen[key] = true
			out.append({"id": tid, "rot": r, "sockets": rot_s, "weight": weight})
	return out


static func _rotate_sockets(s: Array, steps: int) -> PackedStringArray:
	var res := PackedStringArray([str(s[0]), str(s[1]), str(s[2]), str(s[3])])
	for _i in range(steps % 4):
		res = PackedStringArray([res[3], res[0], res[1], res[2]])
	return res


static func _find_open_state(states: Array[Dictionary]) -> int:
	for i in range(states.size()):
		var s: PackedStringArray = states[i]["sockets"]
		if s[0] == "open" and s[1] == "open" and s[2] == "open" and s[3] == "open" and str(states[i]["id"]) == "TILE_Open":
			return i
	return 0


static func _build_compat_table(states: Array[Dictionary]) -> Array:
	var m := states.size()
	var table: Array = []
	for i in range(m):
		var dirs: Array = [[], [], [], []]
		var si: PackedStringArray = states[i]["sockets"]
		for d in range(4):
			var need := si[d]
			var opp_d: int = OPP[d]
			for j in range(m):
				if (states[j]["sockets"] as PackedStringArray)[opp_d] == need:
					(dirs[d] as Array).append(j)
		table.append(dirs)
	return table


static func _run_once(n: int, states: Array[Dictionary], compat: Array, open_idx: int, center: int, clear_r: int, rng: RandomNumberGenerator, forced_open_cells: Array[Vector2i] = []) -> Array:
	var all_idx: Array[int] = []
	for i in range(states.size()):
		all_idx.append(i)
	var cells: Array = []
	cells.resize(n * n)
	for i in range(n * n):
		cells[i] = all_idx.duplicate()

	var forced_set := {}
	for fc in forced_open_cells:
		forced_set[fc] = true

	var queue: Array[int] = []
	# Pre-collapse center safe zone, forced open zones (e.g. elevators), and outer border ring to open tiles
	for z in range(n):
		for x in range(n):
			var is_center := absi(x - center) <= clear_r and absi(z - center) <= clear_r
			var is_edge := x == 0 or z == 0 or x == n - 1 or z == n - 1
			if is_center or is_edge or forced_set.has(Vector2i(x, z)):
				var idx := z * n + x
				cells[idx] = [open_idx]
				queue.append(idx)

	if not _propagate(n, cells, compat, queue):
		return []

	while true:
		var pick_cell := _pick_lowest_entropy(cells, rng)
		if pick_cell == -1:
			return cells
		var opts: Array = cells[pick_cell]
		var chosen := _weighted_choice(opts, states, rng)
		cells[pick_cell] = [chosen]
		if not _propagate(n, cells, compat, [pick_cell]):
			return []
	return []


static func _pick_lowest_entropy(cells: Array, rng: RandomNumberGenerator) -> int:
	var best_len := 999999
	var ties: Array[int] = []
	for i in range(cells.size()):
		var cnt: int = (cells[i] as Array).size()
		if cnt <= 1:
			continue
		if cnt < best_len:
			best_len = cnt
			ties = [i]
		elif cnt == best_len:
			ties.append(i)
	if ties.is_empty():
		return -1
	return ties[rng.randi_range(0, ties.size() - 1)]


static func _weighted_choice(opts: Array, states: Array[Dictionary], rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for idx in opts:
		total += float(states[int(idx)]["weight"])
	var r := rng.randf_range(0.0, maxf(0.001, total))
	var acc := 0.0
	for idx in opts:
		acc += float(states[int(idx)]["weight"])
		if r <= acc:
			return int(idx)
	return int(opts[opts.size() - 1])


static func _propagate(n: int, cells: Array, compat: Array, queue: Array[int]) -> bool:
	var head := 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		var cx := cur % n
		var cz := int(cur / n)
		var cur_opts: Array = cells[cur]
		for d in range(4):
			var nx: int = cx + int(DX[d])
			var nz: int = cz + int(DZ[d])
			if nx < 0 or nx >= n or nz < 0 or nz >= n:
				continue
			var nidx := nz * n + nx
			var allowed := {}
			for st_i in cur_opts:
				for ok_j in compat[int(st_i)][d]:
					allowed[int(ok_j)] = true
			var n_opts: Array = cells[nidx]
			var kept: Array = []
			for st_j in n_opts:
				if allowed.has(int(st_j)):
					kept.append(st_j)
			if kept.size() < n_opts.size():
				if kept.is_empty():
					return false
				cells[nidx] = kept
				queue.append(nidx)
	return true
