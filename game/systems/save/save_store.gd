class_name SaveStore
extends RefCounted
## One manual save slot kept as two generations in two bank files (IH-112):
## <root>/slot_01.a.json and slot_01.b.json. The newest is chosen by the generation inside
## each verified file, never by file time or name. A save always replaces the older (or
## damaged, or empty) bank: the new bytes go to that bank's own .pending file, are flushed,
## closed, read back and fully decoded, both banks are checked to be unchanged since they
## were inspected, and only then a same-directory rename replaces the bank. A valid bank is
## never opened for writing and never deleted first. The rename returning OK is the commit.
## Paths are fixed by the app; root is injected only by configuration and tests.
## One writer per root; concurrent processes are not supported.

const OK: StringName = &"OK"
const NO_SAVE: StringName = &"NO_SAVE"
const IO_ERROR: StringName = &"IO_ERROR"
const FILE_CHANGED: StringName = &"FILE_CHANGED"
const CORRUPT_SAVE: StringName = &"CORRUPT_SAVE"
const INCOMPATIBLE_SAVE: StringName = &"INCOMPATIBLE_SAVE"
const RECOVERY_AVAILABLE: StringName = &"RECOVERY_AVAILABLE"
const AMBIGUOUS_SAVE: StringName = &"AMBIGUOUS_SAVE"
const NUMBER_OUT_OF_RANGE: StringName = &"NUMBER_OUT_OF_RANGE"
const COMMIT_UNCERTAIN: StringName = &"COMMIT_UNCERTAIN"
const NO_RECOVERY: StringName = &"NO_RECOVERY"

const BANK_MISSING: StringName = &"missing"
const BANK_VALID: StringName = &"valid"
const BANK_CORRUPT: StringName = &"corrupt"
const BANK_INCOMPATIBLE: StringName = &"incompatible"
const BANK_IO_ERROR: StringName = &"io_error"

const SLOT: String = "slot_01"
const BANKS: Array[String] = ["a", "b"]
const SOURCE_LATEST: StringName = &"latest"
const SOURCE_RECOVERY: StringName = &"recovery"


## Independent outcome value. `payload` is the normalized v1 payload for a load.
class Result extends RefCounted:
	var ok: bool = false
	var code: StringName = &""
	## Codec/adapter code behind a summary code (e.g. CHECKSUM_MISMATCH behind CORRUPT_SAVE).
	var cause: StringName = &""
	var detail: String = ""
	var source_bank: String = ""
	var generation: int = 0
	var committed: bool = false
	var recovered: bool = false
	var migrated_from: int = -1
	var payload: Dictionary = {}
	var warning: String = ""

	static func make(result_code: StringName, result_detail: String = "") -> Result:
		var result: Result = Result.new()
		result.ok = result_code == OK
		result.code = result_code
		result.detail = result_detail
		return result


## Called with a stage name at each step of a save: "pending_written", "pending_verified",
## "before_rename", "after_rename". Diagnostics and tests (failure/kill injection) only.
var stage_hook: Callable = Callable()
## Asked right before the rename; anything but &"" refuses the commit with that code
## (the coordinator's cancel/lifetime latch).
var commit_guard: Callable = Callable()

var _root: String
var _manifest: Dictionary
var _files: SaveFileAdapter


func _init(root: String, manifest: Dictionary, files: SaveFileAdapter = null) -> void:
	_root = root.trim_suffix("/")
	_manifest = manifest
	_files = files if files != null else SaveFileAdapter.new()


func get_root() -> String:
	return _root


func bank_path(bank: String) -> String:
	return "%s/%s.%s.json" % [_root, SLOT, bank]


func pending_path(bank: String) -> String:
	return "%s/%s.%s.pending" % [_root, SLOT, bank]


## Reads and fully verifies both banks and decides what Load and Save would do. Pending
## files are never read. A missing root is NO_SAVE and is not created here.
## {"banks": {"a": info, "b": info}, "code", "latest", "recovery", "target", "next_generation"}
## info = {state, cause, detail, generation, payload, migrated_from, fingerprint}.
func inspect() -> Dictionary:
	var banks: Dictionary = {}
	for bank: String in BANKS:
		banks[bank] = _inspect_bank(bank)
	var status: Dictionary = _decide(banks.a, banks.b)
	status["banks"] = banks
	return status


## Loads the newest valid generation, or with SOURCE_RECOVERY the previous one the status
## offers (never chosen automatically). Files are not modified by a load.
func load_slot(source: StringName = SOURCE_LATEST) -> Result:
	var status: Dictionary = inspect()
	var bank: String = ""
	if source == SOURCE_RECOVERY:
		bank = status.recovery
		if bank.is_empty():
			var none: Result = Result.make(NO_RECOVERY, "no previous generation is available (%s)" % status.code)
			none.cause = status.code
			return none
	elif status.code == OK:
		bank = status.latest
	else:
		var refused: Result = Result.make(status.code, _summary(status))
		refused.cause = _first_cause(status)
		return refused
	var info: Dictionary = status.banks[bank]
	var result: Result = Result.make(OK)
	result.source_bank = bank
	result.generation = info.generation
	result.payload = (info.payload as Dictionary).duplicate(true)
	result.migrated_from = info.migrated_from
	result.recovered = source == SOURCE_RECOVERY
	return result


## Saves `payload` (v1, without generation) as the next generation into the bank the status
## table chooses. Nothing before the rename changes either bank's bytes.
func save_slot(payload: Dictionary) -> Result:
	var status: Dictionary = inspect()
	if status.target.is_empty():
		var refused: Result = Result.make(status.code, "save refused: %s" % _summary(status))
		refused.cause = _first_cause(status)
		return refused
	var generation: int = status.next_generation
	if generation > SaveCodec.MAX_SAFE_INT:
		return Result.make(NUMBER_OUT_OF_RANGE, "generation limit reached")
	var full: Dictionary = payload.duplicate(true)
	full["schema_version"] = SaveCodec.SCHEMA_VERSION
	full["content_version"] = SaveCodec.CONTENT_VERSION
	full["generation"] = generation
	var encoded: SaveCodec.Result = SaveCodec.encode(full, _manifest)
	if not encoded.ok:
		var invalid: Result = Result.make(encoded.code, encoded.detail)
		invalid.cause = encoded.code
		return invalid
	var bytes: PackedByteArray = (encoded.value as String).to_utf8_buffer()
	var target: String = status.target
	var pending: String = pending_path(target)
	if not _files.dir_exists(_root) and _files.make_dir(_root) != SaveFileAdapter.OK:
		return Result.make(IO_ERROR, "cannot create %s" % _root)
	var written: Dictionary = _files.write(pending, bytes)
	if written.code != SaveFileAdapter.OK:
		return _abort(pending, IO_ERROR, "pending write: %s" % written.detail)
	_stage("pending_written")
	var back: Dictionary = _files.read(pending, SaveCodec.MAX_FILE_BYTES)
	if back.code != SaveFileAdapter.OK or back.bytes != bytes:
		return _abort(pending, IO_ERROR, "pending read-back differs (%s, %d/%d bytes)" % [back.code, back.bytes.size(), bytes.size()])
	var check: SaveCodec.Result = SaveCodec.decode(back.bytes, _manifest)
	if not check.ok or int(check.value.generation) != generation:
		return _abort(pending, IO_ERROR, "pending does not decode: %s" % check.detail)
	_stage("pending_verified")
	for bank: String in BANKS:
		if _fingerprint(bank) != status.banks[bank].fingerprint:
			return _abort(pending, FILE_CHANGED, "bank %s changed since it was inspected" % bank)
	var guard: StringName = commit_guard.call() if commit_guard.is_valid() else &""
	if not guard.is_empty():
		return _abort(pending, guard, "commit refused before rename")
	_stage("before_rename")
	var old_fingerprint: String = status.banks[target].fingerprint
	if _files.rename(pending, bank_path(target)) != SaveFileAdapter.OK:
		var now: String = _fingerprint(target)
		if now == old_fingerprint:
			return _abort(pending, IO_ERROR, "rename failed; bank %s unchanged" % target)
		# The bank changed although rename reported failure: the outcome is unknown and
		# is not retried; the next inspect decides what is on disk.
		var unsure: Result = Result.make(COMMIT_UNCERTAIN, "rename failed but bank %s changed" % target)
		unsure.source_bank = target
		unsure.generation = generation
		return unsure
	var result: Result = Result.make(OK)
	result.committed = true
	result.source_bank = target
	result.generation = generation
	_stage("after_rename")
	# Diagnostics after the commit never turn it into a failure or a retry.
	var after: Dictionary = _files.read(bank_path(target), SaveCodec.MAX_FILE_BYTES)
	if after.code != SaveFileAdapter.OK or after.bytes != bytes:
		result.warning = "post-commit read of bank %s differs (%s)" % [target, after.code]
	return result


func _inspect_bank(bank: String) -> Dictionary:
	var info: Dictionary = {"state": BANK_MISSING, "cause": &"", "detail": "", "generation": 0, "payload": {},
		"migrated_from": -1, "fingerprint": "missing"}
	var read: Dictionary = _files.read(bank_path(bank), SaveCodec.MAX_FILE_BYTES)
	if read.code == SaveFileAdapter.MISSING:
		return info
	if read.code == SaveFileAdapter.TOO_LARGE:
		info.state = BANK_CORRUPT
		info.cause = CORRUPT_SAVE
		info.detail = "too large: " + read.detail
		info.fingerprint = "too_large:" + read.detail
		return info
	if read.code != SaveFileAdapter.OK:
		info.state = BANK_IO_ERROR
		info.cause = IO_ERROR
		info.detail = read.detail
		info.fingerprint = "io_error"
		return info
	info.fingerprint = _hash(read.bytes)
	var decoded: SaveCodec.Result = SaveCodec.decode(read.bytes, _manifest)
	info.cause = decoded.code
	info.detail = decoded.detail
	if decoded.ok:
		info.state = BANK_VALID
		info.generation = int(decoded.value.generation)
		info.payload = decoded.value
		info.migrated_from = decoded.migrated_from
	elif SaveCodec.is_incompatible(decoded.code):
		info.state = BANK_INCOMPATIBLE
	else:
		info.state = BANK_CORRUPT
	return info


## The A/B table of SAVE_LOAD.md. latest/recovery/target are bank names or "".
func _decide(a: Dictionary, b: Dictionary) -> Dictionary:
	var out: Dictionary = {"code": OK, "latest": "", "recovery": "", "target": "", "next_generation": 0}
	var states: Array = [a.state, b.state]
	if states.has(BANK_IO_ERROR):
		out.code = IO_ERROR
		return out
	if states.has(BANK_INCOMPATIBLE):
		out.code = INCOMPATIBLE_SAVE
		return out
	var valid: Array[String] = []
	for bank: String in BANKS:
		if (a if bank == "a" else b).state == BANK_VALID:
			valid.append(bank)
	if valid.is_empty():
		if states == [BANK_MISSING, BANK_MISSING]:
			out.code = NO_SAVE
			out.target = "a"
			out.next_generation = 1
		else:
			# Damaged with no valid generation: nothing is loaded and nothing is written
			# over it (not even into the other, empty bank).
			out.code = CORRUPT_SAVE
		return out
	if valid.size() == 1:
		var good: String = valid[0]
		var other: String = "b" if good == "a" else "a"
		var other_state: StringName = (a if other == "a" else b).state
		var good_generation: int = (a if good == "a" else b).generation
		out.target = other
		out.next_generation = good_generation + 1
		if other_state == BANK_MISSING:
			out.latest = good
		else:
			out.code = RECOVERY_AVAILABLE
			out.recovery = good
		return out
	if a.generation == b.generation:
		if JSON.stringify(a.payload, "", true, true) == JSON.stringify(b.payload, "", true, true):
			out.latest = "a"
			out.target = "b"
			out.next_generation = a.generation + 1
		else:
			out.code = AMBIGUOUS_SAVE
		return out
	var newer: String = "a" if a.generation > b.generation else "b"
	var older: String = "b" if newer == "a" else "a"
	out.latest = newer
	out.recovery = older
	out.target = older
	out.next_generation = maxi(a.generation, b.generation) + 1
	return out


func _fingerprint(bank: String) -> String:
	var read: Dictionary = _files.read(bank_path(bank), SaveCodec.MAX_FILE_BYTES)
	if read.code == SaveFileAdapter.MISSING:
		return "missing"
	if read.code == SaveFileAdapter.TOO_LARGE:
		return "too_large:" + read.detail
	if read.code == SaveFileAdapter.OK:
		return _hash(read.bytes)
	return "io_error"


func _hash(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


## A failure before the commit: only this bank's own pending file is removed; the banks
## are untouched. A cleanup failure is reported as a warning, never as a deletion of data.
func _abort(pending: String, code: StringName, detail: String) -> Result:
	var result: Result = Result.make(code, detail)
	result.cause = code
	if _files.remove(pending) != SaveFileAdapter.OK:
		result.warning = "could not remove %s" % pending.get_file()
	return result


func _stage(stage: String) -> void:
	if stage_hook.is_valid():
		stage_hook.call(stage)


func _summary(status: Dictionary) -> String:
	var parts: PackedStringArray = []
	for bank: String in BANKS:
		var info: Dictionary = status.banks[bank]
		parts.append("%s=%s%s" % [bank, info.state, "" if info.cause == &"" or info.state == BANK_VALID else "(%s)" % info.cause])
	return "%s [%s]" % [status.code, ", ".join(parts)]


func _first_cause(status: Dictionary) -> StringName:
	for bank: String in BANKS:
		var info: Dictionary = status.banks[bank]
		if info.state != BANK_VALID and info.state != BANK_MISSING:
			return info.cause
	return status.code
