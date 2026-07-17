extends Node

var new_match := false

## How the last match ended, from the LOCAL player's point of view. Set by the
## match right before it swaps to the result screen, which reads it once and
## puts it back to NONE — same consume-then-reset discipline as new_match, so a
## stale outcome can't leak into the next match.
enum Outcome { NONE, VICTORY, DEFEAT, DRAW }
var match_outcome : Outcome = Outcome.NONE
