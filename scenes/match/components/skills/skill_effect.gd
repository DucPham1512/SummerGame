class_name SkillEffect
extends RefCounted

# The resolved result of activating a skill: authoritative, declarative data that
# a combat resolver applies to game state. The skill computes *intent* here; it
# never mutates players/dice directly. This keeps resolution deterministic and
# testable (same input -> same SkillEffect), which the netcode needs.

## Damage dealt to the opponent.
var damage : int = 0

## Whether `damage` is undefendable (skips the defender's Defensive Ability).
## Carried for the defense gating; ignored where defense isn't modelled yet.
var undefendable : bool = false

## HP restored to the caster's companion (Nyra heals).
var heal_companion : int = 0

## Status effects inflicted on the opponent.
var inflict_on_opponent : Array[StatusEffect] = []

## Status effects the caster gains.
var grant_to_self : Array[StatusEffect] = []

## Runtime change to a status's stack limit, as status_id -> delta
## (e.g. {"tactical_advantage": 1} raises the limit by one for this player).
var stack_limit_delta : Dictionary = {}

## Status ids to set to the caster's current stack limit ("gain max ...").
## Applied after stack_limit_delta so a freshly-raised limit is respected.
var max_out_self : Array[String] = []
