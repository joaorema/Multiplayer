extends MeshInstance3D

func draw_raycast_line(from: Vector3, to: Vector3) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(Color(1, 0, 0)) # Red
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()
	self.mesh = mesh

func draw_shotgun_rays_from_data(lines_data: Array) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(Color(1, 1, 0)) # Yellow lines for shotgun
	
	for line_data in lines_data:
		mesh.surface_add_vertex(line_data.from)
		mesh.surface_add_vertex(line_data.to)
	
	mesh.surface_end()
	self.mesh = mesh

# Method to clear the mesh
func clear_mesh():
	self.mesh = null

# Alternative: Draw lines to actual hit points with distance calculation
func draw_shotgun_rays(from: Vector3, base_dir: Vector3, pellet_count: int = 8, spread_angle: float = 5.0, max_distance: float = 1000.0) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(Color(1, 1, 0)) # Yellow lines for shotgun
	
	for i in range(pellet_count):
		# Random spread (degrees -> radians)
		var spread_x = deg_to_rad(randf_range(-spread_angle, spread_angle))
		var spread_y = deg_to_rad(randf_range(-spread_angle, spread_angle))
		# Start with base direction and rotate slightly
		var dir = base_dir.rotated(Vector3.UP, spread_x)
		dir = dir.rotated(Vector3.RIGHT, spread_y)
		var to = from + dir * max_distance # ray length
		# Add line
		mesh.surface_add_vertex(from)
		mesh.surface_add_vertex(to)

	mesh.surface_end()
	self.mesh = mesh
