extends Control

signal to_login
signal register(email, password)

@onready var mail: LineEdit = $RegisterWindow/VBoxContainer/MailContainer/MailInput
@onready var username: LineEdit = $RegisterWindow/VBoxContainer/UserNameContainer/UsernameInput
@onready var password: LineEdit = $RegisterWindow/VBoxContainer/PasswordContainer/PasswordInput
@onready var repeat_password: LineEdit = $RegisterWindow/VBoxContainer/RepeatPasswordContainer/RepeatPasswordInput


func _on_return_to_login_button_pressed() -> void:
	to_login.emit()


func _on_register_button_pressed() -> void:
	if password.text != repeat_password.text:
		push_error("Password repetition doesn't match")
		return

	var response_code: int = await GDSync.account_create(mail.text, username.text, password.text)
	if response_code == ENUMS.ACCOUNT_CREATION_RESPONSE_CODE.SUCCESS:
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
