@tool
extends EditorImportPlugin

enum Mode { MERGED, LAYER_FILES, LAYER_ATLAS}

const TILE_SIZE := 64

const MANIFEST_SUFFIX := "layers.json"
const ATLAS_SUFFIX := "atlas.png"

func _get_importer_name():
	return "kra.importer"

func _get_visible_name():
	return "Krita importer"

func _get_recognized_extensions():
	return ["kra"]

func _get_save_extension():
	return "res"

func _get_resource_type():
	return "ImageTexture"

func _get_preset_count() -> int:
	return 1

func _get_preset_name(preset_index: int) -> String:
	return "Default"

func _get_import_options(path: String, preset_index: int) -> Array[Dictionary]:
	return [
		{
			"name": "mode",
			"default_value" : Mode.MERGED,
			"property_hint": PROPERTY_HINT_ENUM,
			"hint_string": "Imagem final,Layers em arquivos,Layers em atlas"
		},
		{
			"name": "layers/include_hidden", "default_value": false
		},
		{
			"name": "layers/crop_to_content", "default_value": true
		},
		{
			"name": "atlas/columns",
			"default_value": 0,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,64,1"
		},
		{
			"name": "atlas/padding",
			"default_value": 2,
			"property_hint": PROPERTY_HINT_RANGE,
			"hint_string": "0,64,1"
		}
	]

func _get_option_visibility(path: String, option_name: StringName, options: Dictionary) -> bool:
	var mode : int = options.get("mode", Mode.MERGED)
	
	if option_name.begins_with("layers/"):
		return mode != Mode.MERGED
	if option_name.begins_with("atlas/"):
		return mode != Mode.LAYER_ATLAS
	
	return true

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array[String], gen_files: Array[String]) -> Error:
	var zip := ZIPReader.new()
	
	var err := zip.open(source_file)
	
	if err != OK:
		push_error("Nao deu pra abrir %s: %s" % [source_file, error_string(err)])
		return err
	
	var png_data := zip.read_file("mergedimage.png")
	
	if png_data.is_empty():
		zip.close()
		push_error("Merged image not found: " + source_file)
		return ERR_FILE_NOT_FOUND
	
	var image := Image.new()
	err = image.load_png_from_buffer(png_data)
	
	if err != OK:
		zip.close()
		return err
	
	var prefix := source_file.get_basename() + "."
	_clean_generated(prefix)
	
	var mode: int = options.get("mode", Mode.MERGED)
	if mode != Mode.MERGED:
		err = _export_layers(zip, source_file, prefix, mode, options, gen_files)
	zip.close()
	
	if err != OK:
		return err
	
	var texture := ImageTexture.create_from_image(image)
	return ResourceSaver.save(texture, save_path + ".res")

func _clean_generated(prefix: String) -> void:
	var dir := DirAccess.open(prefix.get_base_dir())
	if dir == null:
		return
	var file_prefix := prefix.get_file()
	for file in dir.get_files():
		if not file.begins_with(file_prefix):
			continue
		if file == file_prefix + MANIFEST_SUFFIX or file.ends_with(".png") or file.ends_with(".png.import"):
			dir.remove(file)

func _export_layers(zip: ZIPReader, source_file: String, prefix: String, mode: int, options: Dictionary, gen_files: Array[String]) -> Error:
	var doc := _read_document(zip)
	if doc.is_empty():
		push_error("maindoc.xml invalido: " + source_file)
		return ERR_PARSE_ERROR
	
	var canvas_size := Vector2i(doc.width, doc.height)
	var include_hidden: bool = options.get("layers/include_hidden", false)
	var crop: bool = options.get("layers/crop_to_content", true)
	
	var layers: Array[Dictionary] = []
	for info: Dictionary in doc.layers:
		if not info.visible and not include_hidden:
			continue
		var canvas := _read_layer_image(zip, doc.image_name, info, canvas_size)
		if canvas == null:
			continue
		var used := canvas.get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		var rect := used if crop else Rect2i(Vector2i.ZERO, canvas_size)
		info.image = canvas.get_region(rect)
		info.offset = rect.position
		layers.append(info)
	
	if layers.is_empty():
		push_warning("Nenhum layer exportavel em " + source_file)
		return OK
	
	_assign_file_names(layers)
	
	var manifest := {
		"source": source_file,
		"canvas_size": [canvas_size.x, canvas_size.y],
		"layers": [],
	}
	
	if mode == Mode.LAYER_FILES:
		for info in layers:
			var path: String = prefix + info.file_name + ".png"
			var err := _write_png(info.image, path, gen_files)
			if err != OK:
				return err
			manifest.layers.append(_manifest_entry(info, { "file": path }))
	else:
		var columns: int = options.get("atlas/columns", 0)
		var padding: int = options.get("atlas/padding", 2)
		var atlas := _pack_atlas(layers, columns, padding)
		var path := prefix + ATLAS_SUFFIX
		var err := _write_png(atlas, path, gen_files)
		if err != OK:
			return err
		manifest.atlas = path
		for info in layers:
			var region: Rect2i = info.region
			manifest.layers.append(_manifest_entry(info, {
				"region": [region.position.x, region.position.y, region.size.x, region.size.y],
			}))
	
	var manifest_path := prefix + MANIFEST_SUFFIX
	var file := FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	gen_files.append(manifest_path)
	return OK

func _write_png(image: Image, path: String, gen_files: Array[String]) -> Error:
	var err := image.save_png(path)
	if err != OK:
		push_error("Nao deu pra salvar %s: %s" % [path, error_string(err)])
		return err
	# Register the new file so the editor can import it right away.
	EditorInterface.get_resource_filesystem().update_file(path)
	append_import_external_resource(path)
	gen_files.append(path)
	return OK

func _manifest_entry(info: Dictionary, extra: Dictionary) -> Dictionary:
	var image: Image = info.image
	var entry := {
		"name": info.name,
		"group": info.group,
		"offset": [info.offset.x, info.offset.y],
		"size": [image.get_width(), image.get_height()],
		"z_index": info.z_index,
		"visible": info.visible,
		"opacity": info.opacity,
	}
	entry.merge(extra)
	return entry

# "Braco/Mao" -> "Braco-Mao"; repeated names get a numeric suffix.
func _assign_file_names(layers: Array[Dictionary]) -> void:
	var used := {}
	for info in layers:
		var base: String = (info.group + "-" + info.name) if info.group != "" else info.name
		base = base.replace("/", "-").validate_filename()
		var name := base
		var n := 2
		while used.has(name):
			name = "%s_%d" % [base, n]
			n += 1
		used[name] = true
		info.file_name = name

# Uniform grid: every cell is the size of the largest layer, so a layer's cell
# is predictable from its index.
func _pack_atlas(layers: Array[Dictionary], columns: int, padding: int) -> Image:
	if columns <= 0:
		columns = ceili(sqrt(layers.size()))
	var cell := Vector2i.ZERO
	for info in layers:
		var image: Image = info.image
		cell = Vector2i(maxi(cell.x, image.get_width()), maxi(cell.y, image.get_height()))
	var rows := ceili(float(layers.size()) / columns)
	var atlas_size := Vector2i(
		columns * cell.x + (columns + 1) * padding,
		rows * cell.y + (rows + 1) * padding)
	var atlas := Image.create_empty(atlas_size.x, atlas_size.y, false, Image.FORMAT_RGBA8)
	for i in layers.size():
		var info := layers[i]
		var image: Image = info.image
		var pos := Vector2i(
			padding + (i % columns) * (cell.x + padding),
			padding + (i / columns) * (cell.y + padding))
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), pos)
		info.region = Rect2i(pos, image.get_size())
	return atlas

# --- .kra parsing -------------------------------------------------------------

# Returns { image_name, width, height, layers: [{ name, group, filename, x, y,
# visible, opacity, colorspace, z_index }] } with paint layers bottom-to-top.
func _read_document(zip: ZIPReader) -> Dictionary:
	var xml := zip.read_file("maindoc.xml")
	if xml.is_empty():
		return {}
	var parser := XMLParser.new()
	if parser.open_buffer(xml) != OK:
		return {}
	
	var doc := { "layers": [] }
	# One entry per open (non self-closing) <layer>; groups contribute their name.
	var stack: Array[Dictionary] = []
	var top_down: Array[Dictionary] = []
	
	while parser.read() == OK:
		var node_type := parser.get_node_type()
		if node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "layer":
				stack.pop_back()
			continue
		if node_type != XMLParser.NODE_ELEMENT:
			continue
	
		var tag := parser.get_node_name()
		if tag == "IMAGE" and not doc.has("image_name"):
			doc.image_name = parser.get_named_attribute_value_safe("name")
			doc.width = parser.get_named_attribute_value_safe("width").to_int()
			doc.height = parser.get_named_attribute_value_safe("height").to_int()
			continue
		if tag != "layer":
			continue
	
		var node_type_attr := parser.get_named_attribute_value_safe("nodetype")
		var name := parser.get_named_attribute_value_safe("name")
		var visible := parser.get_named_attribute_value_safe("visible") != "0"
		var groups: PackedStringArray = []
		for parent in stack:
			visible = visible and parent.visible
			if parent.is_group:
				groups.append(parent.name)
	
		if node_type_attr == "paintlayer":
			top_down.append({
				"name": name,
				"group": "/".join(groups),
				"filename": parser.get_named_attribute_value_safe("filename"),
				"x": parser.get_named_attribute_value_safe("x").to_int(),
				"y": parser.get_named_attribute_value_safe("y").to_int(),
				"visible": visible,
				"opacity": parser.get_named_attribute_value_safe("opacity").to_int() / 255.0,
				"colorspace": parser.get_named_attribute_value_safe("colorspacename"),
			})
		elif node_type_attr != "grouplayer":
			push_warning("Layer '%s' (%s) ignorado: so paint layers sao exportados" % [name, node_type_attr])
	
		if not parser.is_empty():
			stack.append({ "name": name, "visible": visible, "is_group": node_type_attr == "grouplayer" })
	
	# maindoc.xml lists layers top-first; z_index 0 is the bottom-most.
	top_down.reverse()
	for i in top_down.size():
		top_down[i].z_index = i
	doc.layers = top_down
	return doc if doc.has("image_name") else {}

# Rebuilds one paint layer as a canvas-sized RGBA8 image.
# Layer file format: text header ("VERSION 2", "TILEWIDTH 64", ..., "DATA <n>"),
# then <n> tiles, each "<x>,<y>,LZF,<size>\n" + <size> bytes. The first byte
# is 1 for LZF-compressed planar (BGRA planes) data, 0 for raw interleaved BGRA.
func _read_layer_image(zip: ZIPReader, image_name: String, info: Dictionary, canvas_size: Vector2i) -> Image:
	if info.colorspace != "RGBA":
		push_warning("Layer '%s' ignorado: so RGBA 8-bit e suportado (era %s)" % [info.name, info.colorspace])
		return null
	var data := zip.read_file(image_name.path_join("layers").path_join(info.filename))
	if data.is_empty():
		push_warning("Pixels do layer '%s' nao encontrados" % info.name)
		return null
	
	var canvas := Image.create_empty(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	var pos := 0
	var tile_count := 0
	var pixel_size := 4
	while true:
		var line := _read_line(data, pos)
		pos = line.next
		var parts: PackedStringArray = line.text.split(" ")
		if parts[0] == "PIXELSIZE":
			pixel_size = parts[1].to_int()
		elif parts[0] == "DATA":
			tile_count = parts[1].to_int()
			break
		elif line.text == "":
			return null
	if pixel_size != 4:
		push_warning("Layer '%s' ignorado: PIXELSIZE %d nao suportado" % [info.name, pixel_size])
		return null
	
	var tile_bytes := TILE_SIZE * TILE_SIZE * pixel_size
	for t in tile_count:
		var line := _read_line(data, pos)
		pos = line.next
		var header: PackedStringArray = line.text.split(",")
		var tile_x := header[0].to_int()
		var tile_y := header[1].to_int()
		var size := header[3].to_int()
		var pixels: PackedByteArray
		if data[pos] == 1:
			pixels = _delinearize_bgra(_lzf_decompress(data, pos + 1, pos + size), TILE_SIZE * TILE_SIZE)
		else:
			pixels = _bgra_to_rgba(data.slice(pos + 1, pos + 1 + tile_bytes))
		pos += size
		var tile := Image.create_from_data(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8, pixels)
		canvas.blit_rect(tile, Rect2i(0, 0, TILE_SIZE, TILE_SIZE), Vector2i(tile_x + info.x, tile_y + info.y))
	return canvas

func _read_line(data: PackedByteArray, pos: int) -> Dictionary:
	var end := data.find(10, pos)
	if end == -1:
		return { "text": "", "next": data.size() }
	return { "text": data.slice(pos, end).get_string_from_ascii(), "next": end + 1 }

# Standard LZF (liblzf) decompression of src[from, to).
func _lzf_decompress(src: PackedByteArray, from: int, to: int) -> PackedByteArray:
	var out := PackedByteArray()
	var ip := from
	while ip < to:
		var ctrl := src[ip]
		ip += 1
		if ctrl < 32:
			out.append_array(src.slice(ip, ip + ctrl + 1))
			ip += ctrl + 1
			continue
		var length := ctrl >> 5
		if length == 7:
			length += src[ip]
			ip += 1
		var ref := out.size() - ((ctrl & 0x1f) << 8) - 1 - src[ip]
		ip += 1
		length += 2
		if ref + length <= out.size():
			out.append_array(out.slice(ref, ref + length))
		else:
			# Overlapping run: must copy byte by byte.
			for i in length:
				out.append(out[ref + i])
	return out

# Planar BBBB..GGGG..RRRR..AAAA -> interleaved RGBA.
func _delinearize_bgra(planar: PackedByteArray, pixel_count: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(pixel_count * 4)
	var g := pixel_count
	var r := pixel_count * 2
	var a := pixel_count * 3
	for i in pixel_count:
		var o := i * 4
		out[o] = planar[r + i]
		out[o + 1] = planar[g + i]
		out[o + 2] = planar[i]
		out[o + 3] = planar[a + i]
	return out

func _bgra_to_rgba(bgra: PackedByteArray) -> PackedByteArray:
	for o in range(0, bgra.size(), 4):
		var b := bgra[o]
		bgra[o] = bgra[o + 2]
		bgra[o + 2] = b
	return bgra
