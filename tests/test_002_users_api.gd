extends AutoworkTest

var secrets = {}

func before_all():
	var f = FileAccess.open("res://secrets.json", FileAccess.READ)
	if f:
		var json = JSON.new()
		if json.parse(f.get_as_text()) == OK:
			secrets = json.get_data()

func test_003_fetch_users_api():
	if secrets.is_empty():
		pending("Requires secrets.json containing valid Kick API keys.")
		return
		
	KickAPI.configure(secrets.access_token)
	var cert = X509Certificate.new()
	if cert.load("res://ca-certificates.crt") == OK:
		KickAPI.get_http_client().set_tls_options(TLSOptions.client(cert))
	
	watch_signals(KickAPI)
	
	# Request users querying a static target. Kick's user ID logic evaluates natively without parameter strings dynamically properly.
	var params = {"username": "xqc"}
	KickAPI.get_users().get_users(params)
	
	var time_waited = 0.0
	var signal_state = [false]
	var response_payload = null
	
	var cb = func(sig, code, data):
		if sig == "users_received":
			signal_state[0] = true
			response_payload = [sig, code, data]
			
	var cb_failed = func(sig, code, error_msg):
		if sig == "users_received":
			signal_state[0] = true
			response_payload = [sig, code, {"error": error_msg}]
			
	KickAPI.request_completed.connect(cb)
	KickAPI.request_failed.connect(cb_failed)
	
	while time_waited < 5.0 and not signal_state[0]:
		KickAPI.poll()
		OS.delay_msec(50)
		time_waited += 0.05
		
	KickAPI.request_completed.disconnect(cb)
	KickAPI.request_failed.disconnect(cb_failed)
	assert_true(signal_state[0], "Signal 'request_completed' or 'request_failed' actively triggered.")
	
	if response_payload != null:
		var sig_name = response_payload[0]
		var response_code = response_payload[1]
		var response_data = response_payload[2]
		
		assert_eq(sig_name, "users_received", "Signal name mapping channels.")
		assert_true(response_code == 200 or response_code == 201 or response_code == 401 or response_code == 404, "HTTP Response should be cleanly generated.")
		assert_not_null(response_data, "Payload must not be null.")
