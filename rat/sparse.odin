package rat

import "core:slice"

U32_MAX :: 4_294_967_295

SparseSet :: struct($T: typeid) {
	sparse:  []u32,
	dense:   []Id,
	data:    []T,
	count:   u32,
	pending: [dynamic]Id, // ids queued for deferred removal (see queue_remove)
}

// Quick bit-mask to pull the raw slot index out of a packed Id
get_idx :: #force_inline proc(id: Id) -> u32 {
	return entity_index(id)
}

create_sparse_set :: proc($T: typeid, max: u32) -> SparseSet(T) {
	s := SparseSet(T) {
		sparse  = make([]u32, max),
		dense   = make([]Id, max),
		data    = make([]T, max),
		count   = 0,
		pending = make([dynamic]Id, 0, 16),
	}

	slice.fill(s.sparse, U32_MAX)
	return s
}

add :: proc(set: ^SparseSet($T), id: Id, value: T) {
	slot := get_idx(id)

	is_valid := set.count < u32(len(set.dense)) && slot < u32(len(set.sparse))
	assert(is_valid, "SparseSet: Out of bounds or capacity reached")

	set.sparse[slot] = set.count
	set.dense[set.count] = id
	set.data[set.count] = value
	set.count += 1
}

remove :: proc(set: ^SparseSet($T), id: Id) {
	slot := get_idx(id)
	assert(slot < u32(len(set.sparse)), "SparseSet: ID out of Range.")

	idx := set.sparse[slot]
	if idx == max(u32) do return // component doesn't exist for this slot

	// generation check: don't let a stale id delete a new component
	if set.dense[idx] != id do return

	last_idx := set.count - 1
	last_id := set.dense[last_idx]
	last_slot := get_idx(last_id)

	set.data[idx] = set.data[last_idx]
	set.dense[idx] = last_id

	set.sparse[last_slot] = idx
	set.sparse[slot] = max(u32) // reset the removed slot to empty sentinel

	set.count -= 1
}

// Returns a pointer to the entity's component, or (nil, false) if absent.
// WARNING: the pointer is only valid until the next `remove`/`add` on this set.
// `remove` swap-fills the freed slot, so a held pointer can silently start
// referring to a different entity's data. Re-`get` after any mutation; never
// cache component pointers across a destroy.
get :: proc(set: ^SparseSet($T), id: Id) -> (^T, bool) {
	slot := get_idx(id)
	assert(slot < u32(len(set.sparse)), "Sparse Set: ID out of range.")

	idx := set.sparse[slot]
	if idx == max(u32) || idx >= set.count do return {}, false

	// stale reference, return empty
	if set.dense[idx] != id do return {}, false

	return &set.data[idx], true
}

// Like get, but asserts the component exists and returns just the pointer.
// Use when the component is guaranteed present (e.g. an entity you just made);
// use get when it may be absent.
must :: proc(set: ^SparseSet($T), id: Id) -> ^T {
	ptr, ok := get(set, id)
	assert(ok, "must: entity is missing this component")
	return ptr
}

// Queue an id for removal without mutating the set now — safe to call while
// looping over entities(set). Apply the whole batch later with flush_removes.
queue_remove :: proc(set: ^SparseSet($T), id: Id) {
	append(&set.pending, id)
}

// Applies all queued removals. remove() is by-id and order-independent, so a
// batched flush is safe regardless of swap-remove reshuffling.
flush_removes :: proc(set: ^SparseSet($T)) {
	for id in set.pending do remove(set, id)
	clear(&set.pending)
}

// Does this set hold a (live) component for `id`?
has :: proc(set: ^SparseSet($T), id: Id) -> bool {
	slot := get_idx(id)
	if slot >= u32(len(set.sparse)) do return false
	idx := set.sparse[slot]
	return idx != max(u32) && idx < set.count && set.dense[idx] == id
}

// Active entity ids in this set, for read-only iteration:
//   for eid in entities(&world.transforms) { ... }
// Do NOT add/remove from the set while iterating the returned slice. If you
// need to remove during iteration, loop the dense array backwards by index.
entities :: #force_inline proc(set: ^SparseSet($T)) -> []Id {
	return set.dense[:set.count]
}

delete_sparse_set :: proc(set: ^SparseSet($T)) {
	delete(set.data)
	delete(set.dense)
	delete(set.sparse)
	delete(set.pending)
}

clear_sparse_set :: proc(set: ^SparseSet($T)) {
	set.count = 0
	slice.fill(set.sparse, U32_MAX)
	clear(&set.pending)
}
