extends Control


func _on_logout_button_pressed() -> void:
	var response_code : int = await GDSync.account_logout()
	match response_code:
		ENUMS.ACCOUNT_LOGOUT_RESPONSE_CODE.SUCCESS, ENUMS.ACCOUNT_LOGOUT_RESPONSE_CODE.NOT_LOGGED_IN:
			get_tree().change_scene_to_file("res://scenes/auth/auth_background.tscn")
		ENUMS.ACCOUNT_LOGOUT_RESPONSE_CODE.NO_RESPONSE_FROM_SERVER:
			push_error("No response from server")
		ENUMS.ACCOUNT_LOGOUT_RESPONSE_CODE.DATA_CAP_REACHED:
			push_error("Data transfer cap has been reached.")
		ENUMS.ACCOUNT_LOGOUT_RESPONSE_CODE.RATE_LIMIT_EXCEEDED:
			push_error("Rate limit exceeded, please wait and try again.")
		ENUMS.ACCOUNT_LOGOUT_RESPONSE_CODE.NO_DATABASE:
			push_error("API key has no linked database.")
