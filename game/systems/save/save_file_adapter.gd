class_name SaveFileAdapter
extends RefCounted
## The only place SaveStore touches the file system (IH-112): bounded whole-file reads,
## whole-file writes with flush and error checks, same-directory rename and single-file
## removal of an app-owned path. No recursive delete, no directory listing decisions.
## Tests subclass it to inject read/write/flush/rename failures and short writes; the
## real files under a test-only user:// root are still used for everything else.
##
## Durability scope: FileAccess.flush() hands the bytes to the OS (it is not an fsync of
## the file or its directory). A completed rename survives a process kill; surviving a
## power cut is not claimed here.

const OK: StringName = &"OK"
const MISSING: StringName = &"MISSING"
const TOO_LARGE: StringName = &"TOO_LARGE"
const IO_ERROR: StringName = &"IO_ERROR"


func dir_exists(path: String) -> bool:
	return DirAccess.dir_exists_absolute(path)


func make_dir(path: String) -> StringName:
	return OK if DirAccess.make_dir_recursive_absolute(path) == Error.OK else IO_ERROR


## {code, bytes, detail}. The size is checked before anything is read.
func read(path: String, max_bytes: int) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"code": MISSING, "bytes": PackedByteArray(), "detail": ""}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"code": IO_ERROR, "bytes": PackedByteArray(), "detail": "open error %d" % FileAccess.get_open_error()}
	var length: int = file.get_length()
	if length > max_bytes:
		file.close()
		return {"code": TOO_LARGE, "bytes": PackedByteArray(), "detail": "%d bytes" % length}
	var bytes: PackedByteArray = file.get_buffer(length)
	var error: Error = file.get_error()
	file.close()
	if bytes.size() != length or error != Error.OK:
		return {"code": IO_ERROR, "bytes": PackedByteArray(), "detail": "read %d/%d error %d" % [bytes.size(), length, error]}
	return {"code": OK, "bytes": bytes, "detail": ""}


## Writes the whole buffer to `path` (only ever a pending file), flushes and closes.
## close() returns nothing, so the caller verifies by reading the file back.
func write(path: String, bytes: PackedByteArray) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"code": IO_ERROR, "detail": "open error %d" % FileAccess.get_open_error()}
	var stored: bool = file.store_buffer(bytes)
	if not stored or file.get_error() != Error.OK:
		file.close()
		return {"code": IO_ERROR, "detail": "store error %d" % file.get_error()}
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != Error.OK:
		return {"code": IO_ERROR, "detail": "flush error %d" % error}
	return {"code": OK, "detail": ""}


## Same-directory rename that replaces an existing target (checked on macOS APFS and
## Linux ext4 in IH-112; other platforms are recorded as unverified).
func rename(from_path: String, to_path: String) -> StringName:
	return OK if DirAccess.rename_absolute(from_path, to_path) == Error.OK else IO_ERROR


func remove(path: String) -> StringName:
	if not FileAccess.file_exists(path):
		return OK
	return OK if DirAccess.remove_absolute(path) == Error.OK else IO_ERROR
