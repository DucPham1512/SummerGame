extends Control

signal to_login
signal register(email, password)

@onready var mail: LineEdit = $RegisterWindow/VBoxContainer/MailContainer/MailInput
@onready var username: LineEdit = $RegisterWindow/VBoxContainer/UserNameContainer/UsernameInput
@onready var password: LineEdit = $RegisterWindow/VBoxContainer/PasswordContainer/PasswordInput
@onready var repeat_password: LineEdit = $RegisterWindow/VBoxContainer/RepeatPasswordContainer/RepeatPasswordInput


func _on_return_to_login_button_pressed() -> void:
	to_login.emit()


# Seeds the new account's elo leaderboard entry with BASE_ELO. Submission only
# works for the logged-in account and account_create does not log in, so log
# in with the just-created credentials first. If that fails (e.g. email
# verification is enabled), seeding is skipped — matchmaking already falls
# back to BASE_ELO when reading a missing score, so the account still works.
# NOTE: client-submitted scores are spoofable; accepted for now (P2P trust).
func _submit_starting_elo() -> void:
	var login_response : Dictionary = await GDSync.account_login(mail.text, password.text, Util.login_session_time)
	if int(login_response.get("Code", -1)) != ENUMS.ACCOUNT_LOGIN_RESPONSE_CODE.SUCCESS:
		push_warning("Register: could not log in to seed the starting elo; skipping.")
		return
	var submit_code : int = await GDSync.leaderboard_submit_score("elo", Util.BASE_ELO)
	if submit_code != ENUMS.LEADERBOARD_SUBMIT_SCORE_RESPONSE_CODE.SUCCESS:
		push_warning("Register: failed to submit the starting elo (error %d)." % submit_code)


func _on_register_button_pressed() -> void:
	if password.text != repeat_password.text:
		push_error("Password repetition doesn't match")
		return

	var response_code: int = await GDSync.account_create(mail.text, username.text, password.text)
	if response_code == ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.SUCCESS:
		await _submit_starting_elo()
		register.emit(mail.text, password.text)
	else:
		match response_code:
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER:
				push_error("No response from server")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.DATA_CAP_REACHED:
				push_error("Data transfer cap has been reached.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.RATE_LIMIT_EXCEEDED:
				push_error("Rate limit exceeded, please wait and try again.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.NO_DATABASE:
				push_error("API key has no linked database.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.STORAGE_FULL:
				push_error("Database is full.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.INVALID_EMAIL:
				push_error("Invalid email address.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.INVALID_USERNAME:
				push_error("Username contains illegal characters.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.EMAIL_ALREADY_EXISTS:
				push_error("An account with this email address already exists.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.USERNAME_ALREADY_EXISTS:
				push_error("An account with this username already exists.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.USERNAME_TOO_SHORT:
				push_error("Username is too short.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.USERNAME_TOO_LONG:
				push_error("Username is too long.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.PASSWORD_TOO_SHORT:
				push_error("Password is too short.")
			ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.PASSWORD_TOO_LONG:
				push_error("Password is too long.")
