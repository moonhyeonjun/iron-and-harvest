extends InteractionTarget
## Test-only target that counts calls and can refuse or remove itself during try_begin.
## It grants nothing; it exists so the IH-102 runner can observe the controller contract.
## `journal` is shared with the runner so calls stay readable after the node is freed.
## `on_begin` lets a case change the world from inside try_begin (re-entrancy checks).

var begin_calls: int = 0
var end_calls: int = 0
var end_cancelled: Array = []
var begin_result: bool = true
var queue_free_on_begin: bool = false
var journal: Array = []
var on_begin: Callable = Callable()


func try_begin(request_id: int) -> bool:
	begin_calls += 1
	journal.append("begin")
	if on_begin.is_valid():
		on_begin.call()
	var began: bool = begin_result and super(request_id)
	if queue_free_on_begin:
		queue_free()
	return began


func end_interaction(request_id: int, cancelled: bool) -> void:
	end_calls += 1
	end_cancelled.append(cancelled)
	journal.append("end")
	super(request_id, cancelled)
