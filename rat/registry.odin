package rat

// User component registry.
//
// The engine's own components live as typed fields on World. Your game's
// components don't need to — register them once and the World stores the set
// for you, keyed by type. You still get back a normal, typed ^SparseSet(T) and
// use it exactly like an engine set (add / get / must / entities); registration
// only hands the World the bookkeeping it needs to manage lifecycle:
//
//   * destroy_object / queue_destroy automatically remove the entity from every
//     registered set — no manual per-set cleanup.
//   * delete_world frees every registered set.
//
// Example:
//   game.projectiles = rat.register_component(world, Projectile)
//   rat.add(game.projectiles, id, Projectile{...})
//   ...
//   rat.queue_destroy(world, id)   // the Projectile component goes with it

// Type-erased view of a registered SparseSet so the World can remove from and
// free it without knowing its element type. The procs are monomorphized per T
// at registration.
ComponentStore :: struct {
	set:     rawptr, // ^SparseSet(T)
	remove:  proc(set: rawptr, id: Id),
	destroy: proc(set: rawptr),
}

// Registers component type T with the world and returns its (heap-allocated)
// typed sparse set. Keep the pointer and use it directly. Capacity defaults to
// MAX_ENTITIES; pass a smaller value for components only a few entities ever have.
register_component :: proc(world: ^World, $T: typeid, capacity: u32 = MAX_ENTITIES) -> ^SparseSet(T) {
	set := new(SparseSet(T))
	set^ = create_sparse_set(T, capacity)

	world.components[T] = ComponentStore {
		set = set,
		remove = proc(s: rawptr, id: Id) {
			remove(cast(^SparseSet(T))s, id)
		},
		destroy = proc(s: rawptr) {
			ss := cast(^SparseSet(T))s
			delete_sparse_set(ss)
			free(ss)
		},
	}

	return (^SparseSet(T))(set)
}

// Retrieves a previously-registered component set by type. Asserts it was
// registered. Most code caches the pointer from register_component instead.
get_store :: proc(world: ^World, $T: typeid) -> ^SparseSet(T) {
	store, ok := world.components[T]
	assert(ok, "get_store: component type was not registered")
	return (^SparseSet(T))(store.set)
}
