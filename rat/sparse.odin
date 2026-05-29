package rat

import "core:slice"

U32_MAX :: 4_294_967_295

SparseSet :: struct($T: typeid) {
	sparse: []u32,
	dense:  []Id,
	data:   []T,
	count:  u32,
}

// Quick bit-mask to pull the raw slot index out of a packed Id
get_idx :: #force_inline proc(id: Id) -> u32 {
	return entity_index(id)
}

create_sparse_set :: proc($T: typeid, max: u32) -> SparseSet(T) {
	s := SparseSet(T) {
		sparse = make([]u32, max),
		dense  = make([]Id, max),
		data   = make([]T, max),
		count  = 0,
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

get :: proc(set: ^SparseSet($T), id: Id) -> (^T, bool) {
	slot := get_idx(id)
	assert(slot < u32(len(set.sparse)), "Sparse Set: ID out of range.")

	idx := set.sparse[slot]
	if idx == max(u32) || idx >= set.count do return {}, false

	// stale reference, return empty
	if set.dense[idx] != id do return {}, false

	return &set.data[idx], true
}
