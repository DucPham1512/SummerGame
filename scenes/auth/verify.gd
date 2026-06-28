extends Control

signal verify

@onready var verification_code : LineEdit = $VerifyWindow/VBoxContainer/VerificationContainer/VerificationInput

# Set by auth_background when navigating here from register.
# password is kept only because the resend endpoint requires it, and is
# cleared the moment verification succeeds to minimise its lifetime in memory.
var email: String
var password: String


func _on_verify_button_pressed() -> void:
	var response_code: int = await GDSync.account_verify(email, verification_code.text, Util.login_session_time)
	if response_code == ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.SUCCESS:
		password = ""
		verify.emit()
	else:
		match response_code:
			ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER:
				push_error("No response from server")
			ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.DATA_CAP_REACHED:
				push_error("Data transfer cap has been reached.")
			ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.RATE_LIMIT_EXCEEDED:
				push_error("Rate limit exceeded, please wait and try again.")
			ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.NO_DATABASE:
				push_error("API key has no linked database.")
			ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.INCORRECT_CODE:
				push_error("Verification code is incorrect.")
			ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.CODE_EXPIRED:
				push_error("Verification code has expired.")
			ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.ALREADY_VERIFIED:
				push_error("This account is already verified.")
			ENUMS.ACCOUNT_VERIFICATION_RESPONSE_CODE.BANNED:
				push_error("This account is banned.")


func _on_resend_button_pressed() -> void:
	var response_code: int = await GDSync.account_resend_verification_code(email, password)
	match response_code:
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.SUCCESS:
			print("A new verification code has been sent.")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER:
			push_error("No response from server")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.DATA_CAP_REACHED:
			push_error("Data transfer cap has been reached.")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.RATE_LIMIT_EXCEEDED:
			push_error("Rate limit exceeded, please wait and try again.")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.NO_DATABASE:
			push_error("API key has no linked database.")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.VERIFICATION_DISABLED:
			push_error("Email verification is disabled.")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.ON_COOLDOWN:
			push_error("Please wait before requesting another code.")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.ALREADY_VERIFIED:
			push_error("This account is already verified.")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.EMAIL_OR_PASSWORD_INCORRECT:
			push_error("Email or password incorrect.")
		ENUMS.ACCOUNT_RESEND_VERIFICATION_RESPONSE_CODE.BANNED:
			push_error("This account is banned.")
