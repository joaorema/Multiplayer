#include "voxel_blocky_model_cube.h"
#include "../../util/containers/container_funcs.h"
#include "../../util/math/conv.h"
#include "blocky_material_indexer.h"
#include "blocky_model_baking_context.h"
#include "voxel_blocky_model_mesh.h"

namespace zylann::voxel {

VoxelBlockyModelCube::VoxelBlockyModelCube() {
	_atlas_size_in_tiles = Vector2i(16, 16);
	_surface_count = 1;
	_collision_aabbs.push_back(AABB(Vector3(0, 0, 0), Vector3(1, 1, 1)));
}

Cube::Side VoxelBlockyModelCube::name_to_side(const String &s) {
	if (s == "left") {
		return Cube::SIDE_LEFT;
	}
	if (s == "right") {
		return Cube::SIDE_RIGHT;
	}
	if (s == "top") {
		return Cube::SIDE_TOP;
	}
	if (s == "bottom") {
		return Cube::SIDE_BOTTOM;
	}
	if (s == "front") {
		return Cube::SIDE_FRONT;
	}
	if (s == "back") {
		return Cube::SIDE_BACK;
	}
	return Cube::SIDE_COUNT; // Invalid
}

void VoxelBlockyModelCube::set_tile(VoxelBlockyModel::Side side, Vector2i pos) {
	pos.x = math::max(pos.x, 0);
	pos.y = math::max(pos.y, 0);
	if (_tiles[side] != pos) {
		_tiles[side] = pos;
		emit_changed();
	}
}

bool VoxelBlockyModelCube::_set(const StringName &p_name, const Variant &p_value) {
	const String property_name = p_name;

	if (property_name.begins_with("tile_")) {
		String s = property_name.substr(string_literal_length("tile_"), property_name.length());
		Cube::Side side = name_to_side(s);
		if (side != Cube::SIDE_COUNT) {
			Vector2i v = p_value;
			set_tile(VoxelBlockyModel::Side(side), v);
			return true;
		}
	}

	return false;
}

bool VoxelBlockyModelCube::_get(const StringName &p_name, Variant &r_ret) const {
	const String property_name = p_name;

	if (property_name.begins_with("tile_")) {
		String s = property_name.substr(string_literal_length("tile_"), property_name.length());
		Cube::Side side = name_to_side(s);
		if (side != Cube::SIDE_COUNT) {
			r_ret = get_tile(VoxelBlockyModel::Side(side));
			return true;
		}
	}

	return false;
}

void VoxelBlockyModelCube::_get_property_list(List<PropertyInfo> *p_list) const {
	p_list->push_back(PropertyInfo(Variant::NIL, "Cube tiles", PROPERTY_HINT_NONE, "tile_", PROPERTY_USAGE_GROUP));

	p_list->push_back(PropertyInfo(Variant::VECTOR2I, "tile_left"));
	p_list->push_back(PropertyInfo(Variant::VECTOR2I, "tile_right"));
	p_list->push_back(PropertyInfo(Variant::VECTOR2I, "tile_bottom"));
	p_list->push_back(PropertyInfo(Variant::VECTOR2I, "tile_top"));
	p_list->push_back(PropertyInfo(Variant::VECTOR2I, "tile_back"));
	p_list->push_back(PropertyInfo(Variant::VECTOR2I, "tile_front"));
}

void VoxelBlockyModelCube::set_height(float h) {
	_height = math::clamp(h, 0.01f, 1.f);

	if (get_collision_aabb_count() > 0) {
		// Make collision box match
		set_collision_aabb(0, AABB(Vector3(0, 0, 0), Vector3(1, _height, 1)));
	}

	emit_changed();
}

// Allow to specify AtlasTextures?

void VoxelBlockyModelCube::set_atlas_size_in_tiles(Vector2i s) {
	ZN_ASSERT_RETURN(s.x > 0);
	ZN_ASSERT_RETURN(s.y > 0);
	if (s != _atlas_size_in_tiles) {
		_atlas_size_in_tiles = s;
		emit_changed();
	}
}

Vector2i VoxelBlockyModelCube::get_atlas_size_in_tiles() const {
	return _atlas_size_in_tiles;
}

float VoxelBlockyModelCube::get_height() const {
	return _height;
}

void make_cube_side_vertices(StdVector<Vector3f> &positions, const unsigned int side_index, const float height) {
	positions.resize(4);
	for (unsigned int i = 0; i < 4; ++i) {
		const int corner = Cube::g_side_corners[side_index][i];
		Vector3f p = Cube::g_corner_position[corner];
		if (p.y > 0.9) {
			p.y = height;
		}
		positions[i] = p;
	}
}

void make_cube_side_indices(StdVector<int> &indices, const unsigned int side_index) {
	indices.resize(6);
	for (unsigned int i = 0; i < 6; ++i) {
		indices[i] = Cube::g_side_quad_triangles[side_index][i];
	}
}

void make_cube_side_tangents(StdVector<float> &tangents, const unsigned int side_index) {
	for (unsigned int i = 0; i < 4; ++i) {
		for (unsigned int j = 0; j < 4; ++j) {
			tangents.push_back(Cube::g_side_tangents[side_index][j]);
		}
	}
}

namespace {

void add(Span<Vector3f> vecs, Vector3f a) {
	for (Vector3f &v : vecs) {
		v += a;
	}
}

} // namespace

namespace blocky {

void make_cube_sides_vertices_tangents(
		Span<FixedArray<BakedModel::SideSurface, MAX_SURFACES>> sides_surfaces,
		const float height,
		const bool bake_tangents
) {
	for (unsigned int side = 0; side < Cube::SIDE_COUNT; ++side) {
		BakedModel::SideSurface &side_surface = sides_surfaces[side][0];
		make_cube_side_vertices(side_surface.positions, side, height);
		make_cube_side_indices(side_surface.indices, side);
		if (bake_tangents) {
			make_cube_side_tangents(side_surface.tangents, side);
		}
	}
}

Cube::Side get_rotated_side(const Cube::Side src_side, const math::OrthoBasis ortho_basis) {
	const Vector3i dir = ortho_basis.xform(Cube::g_side_normals[src_side]);
	return Cube::dir_to_side(dir);
}

void rotate_ortho(
		FixedArray<FixedArray<BakedModel::SideSurface, VoxelBlockyModel::MAX_SURFACES>, Cube::SIDE_COUNT>
				&sides_surfaces,
		const unsigned int ortho_rotation_index
) {
	const math::OrthoBasis ortho_basis = math::get_ortho_basis_from_index(ortho_rotation_index);
	const Basis3f basis(to_vec3f(ortho_basis.x), to_vec3f(ortho_basis.y), to_vec3f(ortho_basis.z));

	FixedArray<FixedArray<BakedModel::SideSurface, MAX_SURFACES>, Cube::SIDE_COUNT> rotated_sides_surfaces;

	for (unsigned int side = 0; side < Cube::SIDE_COUNT; ++side) {
		FixedArray<BakedModel::SideSurface, MAX_SURFACES> &surfaces = sides_surfaces[side];

		FixedArray<Vector3f, 4> normals;
		for (Vector3f &n : normals) {
			n = to_vec3f(Cube::g_side_normals[side]);
		}

		unsigned int surface_index = 0;
		for (BakedModel::SideSurface &surface : surfaces) {
			// Move mesh to origin for easier rotation, since the baked mesh spans 0..1 instead of -0.5..0.5
			add(to_span(surface.positions), Vector3f(-0.5));
			rotate_mesh_arrays(to_span(surface.positions), to_span(normals), to_span(surface.tangents), basis);
			add(to_span(surface.positions), Vector3f(0.5));

			const Cube::Side dst_side = get_rotated_side(static_cast<Cube::Side>(side), ortho_basis);
			rotated_sides_surfaces[dst_side][surface_index] = std::move(surface);
			++surface_index;
		}
	}

	sides_surfaces = std::move(rotated_sides_surfaces);
}

void bake_cube_geometry(
		const VoxelBlockyModelCube &config,
		BakedModel &baked_data,
		Vector2i p_atlas_size,
		MaterialIndexer &material_indexer,
		bool bake_tangents
) {
	const float height = config.get_height();

	baked_data.model.surface_count = 1;

	BakedModel::Surface &surface = baked_data.model.surfaces[0];
	// The only way to specify materials in this model is via "material overrides", since there is no base mesh.
	// Even if none are specified, we should at least index the "empty" material.
	surface.material_id = material_indexer.get_or_create_index(config.get_material_override(0));

	make_cube_sides_vertices_tangents(to_span(baked_data.model.sides_surfaces), config.get_height(), bake_tangents);

	const float e = 0.001;
	// Winding is the same as the one chosen in Cube:: vertices
	// I am confused. I read in at least 3 OpenGL tutorials that texture coordinates start at bottom-left (0,0).
	// But even though Godot is said to follow OpenGL's convention, the engine starts at top-left!
	// And now in Godot 4 it's flipped again?
	const Vector2f uv_norm_top_bottom[4] = {
		Vector2f(e, 1.f - e),
		Vector2f(1.f - e, 1.f - e),
		Vector2f(1.f - e, e),
		Vector2f(e, e),
	};
	const float uv_top_y = Math::lerp(1.f - e, e, height);
	const Vector2f uv_norm_side[4] = {
		Vector2f(e, 1.f - e),
		Vector2f(1.f - e, 1.f - e),
		Vector2f(1.f - e, uv_top_y),
		Vector2f(e, uv_top_y),
	};

	const Vector2f atlas_size = to_vec2f(p_atlas_size);
	ZN_ASSERT_RETURN(atlas_size.x > 0);
	ZN_ASSERT_RETURN(atlas_size.y > 0);
	const Vector2f s = Vector2f(1.0f) / atlas_size;

	for (unsigned int side = 0; side < Cube::SIDE_COUNT; ++side) {
		blocky::BakedModel::SideSurface &side_surface = baked_data.model.sides_surfaces[side][0];
		StdVector<Vector2f> &uvs = side_surface.uvs;
		uvs.resize(4);

		const Vector2f *uv_norm = Cube::g_side_normals[side].y != 0 ? uv_norm_top_bottom : uv_norm_side;

		for (unsigned int i = 0; i < 4; ++i) {
			uvs[i] = (to_vec2f(config.get_tile(VoxelBlockyModel::Side(side))) + uv_norm[i]) * s;
		}
	}

	if (config.get_mesh_ortho_rotation_index() != 0) {
		rotate_ortho(baked_data.model.sides_surfaces, config.get_mesh_ortho_rotation_index());
	}

	baked_data.empty = false;
}

} // namespace blocky

void VoxelBlockyModelCube::bake(blocky::ModelBakingContext &ctx) const {
	blocky::BakedModel &baked_data = ctx.model;

	baked_data.clear();

	bake_cube_geometry(*this, baked_data, _atlas_size_in_tiles, ctx.material_indexer, ctx.tangents_enabled);
	VoxelBlockyModel::bake(ctx);
}

bool VoxelBlockyModelCube::is_empty() const {
	return false;
}

Ref<Mesh> VoxelBlockyModelCube::get_preview_mesh() const {
	const bool bake_tangents = false;

	blocky::BakedModel baked_data;
	baked_data.color = get_color();
	StdVector<Ref<Material>> materials;
	blocky::MaterialIndexer material_indexer{ materials };
	bake_cube_geometry(*this, baked_data, _atlas_size_in_tiles, material_indexer, bake_tangents);

	Ref<Mesh> mesh = make_mesh_from_baked_data(baked_data, bake_tangents);

	for (unsigned int surface_index = 0; surface_index < _surface_count; ++surface_index) {
		Ref<Material> material = get_material_override(surface_index);
		mesh->surface_set_material(surface_index, material);
	}

	return mesh;
}

void VoxelBlockyModelCube::rotate_tiles_90(const math::Axis axis, const bool clockwise) {
	FixedArray<Vector2i, Cube::SIDE_COUNT> rotated_tiles;

	for (unsigned int src_side = 0; src_side < Cube::SIDE_COUNT; ++src_side) {
		const Vector3i dir = math::rotate_90(Cube::g_side_normals[src_side], axis, clockwise);
		Cube::Side dst_side = Cube::dir_to_side(dir);
		rotated_tiles[dst_side] = _tiles[src_side];
	}

	_tiles = rotated_tiles;

	// Collision boxes don't change with this kind of model. Height is always vertical.
	// VoxelBlockyModel::rotate_90(axis, clockwise);

	// Can't do that, it causes the sub-inspector to be entirely rebuilt, which fucks up the state of custom editors in
	// it...
	// notify_property_list_changed();

	emit_changed();
}

void VoxelBlockyModelCube::rotate_tiles_ortho(const math::OrthoBasis ortho_basis) {
	FixedArray<Vector2i, Cube::SIDE_COUNT> rotated_tiles;

	for (unsigned int src_side = 0; src_side < Cube::SIDE_COUNT; ++src_side) {
		const Cube::Side dst_side = blocky::get_rotated_side(static_cast<Cube::Side>(src_side), ortho_basis);
		rotated_tiles[dst_side] = _tiles[src_side];
	}

	_tiles = rotated_tiles;

	// Collision boxes don't change with this kind of model. Height is always vertical.
	// VoxelBlockyModel::rotate_90(axis, clockwise);

	// Can't do that, it causes the sub-inspector to be entirely rebuilt, which fucks up the state of custom editors in
	// it...
	// notify_property_list_changed();

	emit_changed();
}

void VoxelBlockyModelCube::_bind_methods() {
	ClassDB::bind_method(D_METHOD("set_height", "h"), &VoxelBlockyModelCube::set_height);
	ClassDB::bind_method(D_METHOD("get_height"), &VoxelBlockyModelCube::get_height);

	ClassDB::bind_method(D_METHOD("set_tile", "side", "position"), &VoxelBlockyModelCube::set_tile);
	ClassDB::bind_method(D_METHOD("get_tile", "side"), &VoxelBlockyModelCube::get_tile);

	ClassDB::bind_method(D_METHOD("set_atlas_size_in_tiles", "ts"), &VoxelBlockyModelCube::set_atlas_size_in_tiles);
	ClassDB::bind_method(D_METHOD("get_atlas_size_in_tiles"), &VoxelBlockyModelCube::get_atlas_size_in_tiles);

	ADD_PROPERTY(
			PropertyInfo(Variant::FLOAT, "height", PROPERTY_HINT_RANGE, "0.001,1,0.001"), "set_height", "get_height"
	);
	ADD_PROPERTY(
			PropertyInfo(Variant::VECTOR2I, "atlas_size_in_tiles"), "set_atlas_size_in_tiles", "get_atlas_size_in_tiles"
	);

	// ADD_GROUP("Rotation", "");

	ADD_PROPERTY(
			PropertyInfo(Variant::INT, "mesh_ortho_rotation_index", PROPERTY_HINT_RANGE, "0,24"),
			"set_mesh_ortho_rotation_index",
			"get_mesh_ortho_rotation_index"
	);
}

} // namespace zylann::voxel
