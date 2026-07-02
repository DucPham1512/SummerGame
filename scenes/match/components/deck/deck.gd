class_name Deck
extends Node

var deck_card : Array[String] = []
var deck_hash : String = ""
#Deck building logic: Open deck -> deck hash is loaded to Deck object, to deck_card array
# modify deck = modify the array -> save deck = reconstruct deck hash from array, save, then remove the deck object

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func add_card(card_id : String):
	deck_card.append(card_id)

func remove_card(card_id : String):
	var index = deck_card.find(card_id)
	deck_card.remove_at(index)
	
func construct_from_hash():
	pass
	
func construct_hash():
	return hash(deck_card)
		
