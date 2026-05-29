package rat
import "core:fmt"

Id :: u32

ID_INDEX_BITS :: 20
ID_INDEX_MASK :: (1 << ID_INDEX_BITS) - 1
// Upper bound on simultaneously-live entities. Every sparse set (and the grid's
// `seen` array) allocates its backing arrays at this size up front, so memory
// scales linearly with it — keep it close to what the game actually needs.
// Bump it if you ever hit "Out of entities!".
MAX_ENTITIES :: 2048

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

	// Generation guard: ignore stale / already-destroyed ids. Without this a
	// double destroy would push the same index onto the free list twice and
	// later hand out two live entities sharing one slot.
	if em.generations[idx] != entity_gen(i) do return

	em.generations[idx] += 1

	em.free_indices[em.free_count] = idx
	em.free_count += 1
}

// Is this id still the current occupant of its slot? (generation match)
entity_alive :: #force_inline proc(em: ^EntityManager, i: Id) -> bool {
	return em.generations[entity_index(i)] == entity_gen(i)
}

free_entity_manager :: proc(em: ^EntityManager) {
	delete(em.free_indices)
	delete(em.generations)
}
