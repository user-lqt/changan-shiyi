extends SceneTree
## Run with a real renderer and --disable-vsync; headless cannot measure draw cost.
## Temporary progress only, with repeatable street/overview camera positions.

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	game.fast_dialogue = true
	game.transient_save = true
	game.reset_progress()
	game._switch("ch4")
	game.overlay.close_panel()
	var night = game.scene
	var solver_start := Time.get_ticks_usec()
	var route: Array = night.solve(night.DAWN)
	print("NIGHT_SOLVER ", (Time.get_ticks_usec() - solver_start) / 1000.0, " ms; ", route.size(), " moves")
	RenderingServer.viewport_set_measure_render_time(night.vp.get_viewport_rid(), true)
	var results := []
	for stage in ["start", "street", "overview"]:
		if stage != "start":
			night.state["p"] = Vector2i(13, 6)
			night._sync_3d(true)
		night.force_overview = stage == "overview"
		var warm_until := Time.get_ticks_msec() + 1200
		while Time.get_ticks_msec() < warm_until:
			await process_frame
		var times := []
		var calls := 0.0
		var triangles := 0.0
		var render_cpu_ms := 0.0
		var render_gpu_ms := 0.0
		var stamp := Time.get_ticks_usec()
		for i in range(120):
			await process_frame
			var now := Time.get_ticks_usec()
			times.append((now - stamp) / 1000.0)
			stamp = now
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			triangles += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
			render_cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(night.vp.get_viewport_rid())
			render_gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(night.vp.get_viewport_rid())
		times.sort()
		var mean: float = times.reduce(func(a, b): return a + b, 0.0) / times.size()
		var entry := {"stage": stage, "mean_ms": mean, "p95_ms": times[113],
			"fps": 1000.0 / mean, "draw_calls": calls / 120,
			"primitives": triangles / 120, "render_cpu_ms": render_cpu_ms / 120,
			"render_gpu_ms": render_gpu_ms / 120}
		results.append(entry)
		print("NIGHT_BENCH ", JSON.stringify(entry))
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--bench-out="):
				var prefix := arg.trim_prefix("--bench-out=")
				root.get_texture().get_image().save_png(prefix + "-" + stage + ".png")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bench-out="):
			var file := FileAccess.open(arg.trim_prefix("--bench-out=") + ".json", FileAccess.WRITE)
			file.store_string(JSON.stringify(results, "\t"))
	for child in game.get_children():
		if child is AudioStreamPlayer:
			child.stop()
	await create_timer(0.06).timeout
	game.queue_free()
	await process_frame
	quit()
