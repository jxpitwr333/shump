package rat
import "core:fmt"

Id :: u32

ID_INDEX_BITS :: 20
ID_INDEX_MASK :: (1 << ID_INDEX_BITS) - 1
MAX_ENTITIES :: 10000

EntityManager :: struct {
	free_indices: []u32,
	free_count:   u32,
	next_index:   u32,
	generations:  []u32,
}

entity_index :: #force_inline proc(i: Id) -> u32 {
	return i & ID_INDEX_MASK
}

entity_gen :: #force_inline proc(i: Id) -> u32 {
	return i >> ID_INDEX_BITS
}

make_entity :: #force_inline proc(idx: u32, gen: u32) -> Id {
	return (gen << ID_INDEX_BITS) | (idx & ID_INDEX_MASK)
}

create_entity_manager :: proc() -> EntityManager {
	return EntityManager {
		free_count = 0,
		next_index = 0,
		free_indices = make([]u32, MAX_ENTITIES),
		generations = make([]u32, MAX_ENTITIES),
	}
}

entity_create :: proc(em: ^EntityManager) -> (Id, bool) {
	idx: u32

	if em.free_count > 0 {
		em.free_count -= 1
		idx = em.free_indices[em.free_count]

		gen := em.generations[idx]
		return make_entity(idx, gen), true
	}

	if em.next_index < MAX_ENTITIES {
		idx = em.next_index
		em.next_index += 1

		gen := em.generations[idx]
		return make_entity(idx, gen), true
	}

	fmt.eprintln("Error: Out of entities!")
	return Id(0), false
}

entity_destroy :: proc(em: ^EntityManager, i: Id) {
	idx := entity_index(i)

	em.generations[idx] += 1

	em.free_indices[em.free_count] = idx
	em.free_count += 1
}
