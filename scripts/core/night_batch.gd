extends RefCounted
## Chunk repeated static geometry while retaining the imported mesh/materials.
## Six-tile chunks allow camera culling; actors, doors and lantern rigs stay live.

static func combine(world: Node3D, roots: Array) -> Dictionary:
	var groups := {}
	var meshes: Array[MeshInstance3D] = []
	for source in roots:
		_collect(source, meshes)
	var inverse := world.global_transform.affine_inverse()
	for mi in meshes:
		var at := inverse * mi.global_transform
		var chunk := Vector2i(floori(at.origin.x / 6.0), floori(at.origin.z / 6.0))
		var mat_id := mi.material_override.get_instance_id() if mi.material_override else 0
		var key := "%d:%d:%d:%d:%d" % [chunk.x, chunk.y, mi.mesh.get_instance_id(), mat_id, mi.cast_shadow]
		if not groups.has(key):
			groups[key] = {"source": mi, "transforms": []}
		groups[key]["transforms"].append(at)
	for group in groups.values():
		var source: MeshInstance3D = group["source"]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = source.mesh
		multi.instance_count = group["transforms"].size()
		for i in range(multi.instance_count):
			multi.set_instance_transform(i, group["transforms"][i])
		var batch := MultiMeshInstance3D.new()
		batch.name = "StreetBatch"
		batch.multimesh = multi
		batch.material_override = source.material_override
		batch.cast_shadow = source.cast_shadow
		batch.layers = source.layers
		world.add_child(batch)
	for source in roots:
		world.remove_child(source)
		source.free()
	return {"instances": meshes.size(), "batches": groups.size()}


static func _collect(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and node.mesh:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)
