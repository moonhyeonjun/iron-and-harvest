extends GatherTarget
## Test-only GatherTarget: records begin/end and runs `on_begin` inside try_begin right after
## the command was prepared, to exercise cancellation before commit. Grants nothing itself.

var journal: Array = []
var on_begin: Callable = Callable()


func try_begin(request_id: int) -> bool:
	var began: bool = super(request_id)
	journal.append("begin")
	if began and on_begin.is_valid():
		on_begin.call()
	return began


func end_interaction(request_id: int, cancelled: bool) -> void:
	journal.append("end:%s" % ("cancelled" if cancelled else "done"))
	super(request_id, cancelled)
