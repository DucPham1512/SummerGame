extends Control

@export var Login : PackedScene
@export var Register : PackedScene
@export var Verify : PackedScene
@export var MainScene : PackedScene
var _login
var _register
var _verify
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_login = Login.instantiate()
	_register = Register.instantiate()
	_verify = Verify.instantiate()
	_login.to_register.connect(show_register)
	_register.to_login.connect(show_login)
	_login.login.connect(to_main_scene)
	_register.register.connect(show_verify)
	_verify.verify.connect(to_main_scene)
	add_child(_login)
	add_child(_register)
	add_child(_verify)
	show_login()


func show_login():
	_login.visible = true
	_register.visible = false
	_verify.visible = false

func show_register():
	_login.visible = false
	_register.visible = true
	_verify.visible = false

func show_verify(email: String, password: String):
	_verify.email = email
	_verify.password = password
	_login.visible = false
	_register.visible = false
	_verify.visible = true

func to_main_scene():
	get_tree().change_scene_to_packed(MainScene)
