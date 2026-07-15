extends Control

signal to_register
signal login

@onready var email: LineEdit = $LoginWindow/VBoxContainer/MailContainer/MailInput
@onready var password: LineEdit = $LoginWindow/VBoxContainer/PasswordContainer/PasswordInput
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await Util.ensure_gdsync_connected()
	# ---- DEBUG ONLY: local two-instance testing -----------------------------
	# Both instances share user://, so the saved GD-Sync session token would
	# log them into the SAME account. An instance launched with a --profile=*
	# user arg (Debug -> Customize Run Instances, args after "++") skips the
	# session auto-login and always shows the manual form. REMOVE this block
	# when done debugging.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--profile"):
			return
	# ---- END DEBUG ONLY ------------------------------------------------------
	var response_code: int = await GDSync.account_login_from_session(Util.login_session_time)
	if response_code == ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
		Util.active_username = GDSync.player_get_username()
		login.emit()


func _on_to_register_button_pressed() -> void:
	to_register.emit()


func _on_login_button_pressed() -> void:
	# The connection can still be mid-handshake (or have dropped) when the
	# player clicks — reconnect and wait rather than failing the request.
	await Util.ensure_gdsync_connected()
	var response : Dictionary = await GDSync.account_login(email.text, password.text, Util.login_session_time)
	var response_code : int = response["Code"]
	
	if response_code == ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
		Util.active_username = GDSync.player_get_username()
		login.emit()
	else:
		match(response_code):
			ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER:
				push_error("No response from server")
			ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.DATA_CAP_REACHED:
				push_error("Data transfer cap has been reached.")
			ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.RATE_LIMIT_EXCEEDED:
				push_error("Rate limit exceeded, please wait and try again.")
			ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.NO_DATABASE:
				push_error("API key has no linked database.")
			ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT:
				push_error("Email or password incorrect.")
			ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.NOT_VERIFIED:
				push_error("Email is not verified.")
			ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.BANNED:
				var ban_time : int = response["BanTime"]
				
				if ban_time == -1:
					push_error("Account is permanently banned.")
				else:
					var ban_time_string : String = Time.get_datetime_string_from_unix_time(ban_time, true)
					push_error("Account is banned until "+ban_time_string+".")
