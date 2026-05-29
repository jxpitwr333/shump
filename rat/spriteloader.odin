package rat

import "core:encoding/json"
import "core:fmt"
import "core:os"

Sprite_Config_Entry :: struct {
	name:   string,
	path:   string,
	frames: int,
}

load_sprite_manifest :: proc(lib: ^SpriteLibrary, manifest_path: string) -> bool {
	data, ok := os.read_entire_file_from_path(manifest_path, context.allocator)
	if ok != nil {
		fmt.eprintln("Failed to read manifest:", manifest_path)
		return false
	}
	defer delete(data)

	entries: []Sprite_Config_Entry
	err := json.unmarshal(data, &entries)
	if err != nil {
		fmt.eprintln("JSON Error:", err)
		return false
	}

	//defer {
	//	for e in entries {
	//			delete(e.name)
	//			delete(e.path)
	//		}
	//	}
	defer delete(entries)

	for entry in entries {
		s := Sprite {
			path         = entry.path,
			total_frames = i32(entry.frames),
		}

		id := i32(lib.count)
		lib.sprites[id] = s
		lib.path_to_id[entry.name] = id
		lib.count += 1
	}

	return true
}
