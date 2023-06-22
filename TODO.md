# TODO

## General
- [ ] use matrix thing for UVManager (linear algebra is hard)
- [ ] Add action wheel icons
- [ ] add separate function for updating relevant state variables instead of
	  sending full state to save bandwidth
- [ ] add function that gets total health with absoprtion
- [ ] retractable wipers when it rains

## Rewrite
- [ ] fix data api
	- [ ] ConfigAPI
- [ ] reimplement avatar settings
- [ ] fix sound
- [ ] fix Blockbench animations
- [ ] fix or disable custom commands (can probably use `/figura run`)
- [ ] fix armor, won't re-enable until cleanup

## Cleanup
- [ ] Rewrite state management and synchronization code to be less horrifying
	- [ ] one library for syncing state
		- [ ] sender side: allow syncing entire state (EXPENSIVE) or just
			  single values
			- [ ] internally map variable names to a number deterministically
				  to reduce unnecessary data transfer
				  i.e. t["this_is_a_very_long_but_readable_variable_name"]=42 ->
				  t[6]=42
			- [ ] use a lookup table/array based on order added
			- [ ] user should never see this, variable name to number
				  translation should be completely transparent
		- [ ] alternatively no manual syncing; state should be implicitly
			  "shared" and can only be written to/read from via functions to
			  prevent bad programming from desyncing state
		- [ ] receiver side: register handler function that has access to both
			  old and new state
			- [ ] receive value -> run handler function -> replace old value with current
		- [ ] i think figura has a shared storage thing but it's not real time,
			  mirror values to this so newly initialized players load with
			  correct state
	- [ ] one library for storing configs and their default values
		- [ ] this will insert values into the shared state using the other library
- [ ] potentailly rework shared state variables
- [ ] rework appropriate action wheel items as ToggleAction instead of ClickAction
- [ ] split off large snippets of code into separate files
	- [.] PartsManager
	- [.] UVManager
	- [.] utility functions
- [ ] cleanup tick functions, timers
- [ ] cleanup armor code to make less redundant

# Low priority
- [ ] reimplement partial vanilla as texture swap
	- [x] remove partial_vanilla stuff from PartsManager
	- [ ] fix UVManager with matrices or something
	- [ ] add swap to skin texture

# Done
- [x] fix pings
- [x] fix action wheel
