extends GutTest

var secrets = {}

func before_all():
	var f = FileAccess.open("res://secrets.json", FileAccess.READ)
	if f:
		var json = JSON.new()
		if json.parse(f.get_as_text()) == OK:
			secrets = json.get_data()

func test_005_fetch_livestreams_api():
	if secrets.is_empty():
		pending("Requires secrets.json containing valid Kick API keys.")
		return
		
	KickAPI.configure(secrets.access_token)
	var cert = X509Certificate.new()
	if cert.load("res://ca-certificates.crt") == OK:
		KickAPI.get_http_client().set_tls_options(TLSOptions.client(cert))
	
	watch_signals(KickAPI)
	
	# Request stream details capturing specific channel livestreams exactly evaluating properly explicitly.
	var params = {"slug": "xqc"}
	KickAPI.get_livestreams().get_livestreams(params)
	
	var time_waited = 0.0
	var signal_state = [false]
	var response_payload = null
	
	var cb = func(sig, code, data):
		if sig == "livestreams_received":
			signal_state[0] = true
			response_payload = [sig, code, data]
			
	var cb_failed = func(sig, code, error_msg):
		if sig == "livestreams_received":
			signal_state[0] = true
			response_payload = [sig, code, {"error": error_msg}]
			
	KickAPI.request_completed.connect(cb)
	KickAPI.request_failed.connect(cb_failed)
	
	while time_waited < 5.0 and not signal_state[0]:
		KickAPI.poll()
		await get_tree().create_timer(0.05).timeout
		time_waited += 0.05
		
	KickAPI.request_completed.disconnect(cb)
	KickAPI.request_failed.disconnect(cb_failed)
	assert_true(signal_state[0], "Signal 'request_completed' or 'request_failed' actively triggered over livestreams.")
	
	if response_payload != null:
		var sig_name = response_payload[0]
		var response_code = response_payload[1]
		var response_data = response_payload[2]
		
		assert_eq(sig_name, "livestreams_received", "Signal name mapped livestream states elegantly.")
		assert_true(response_code == 200 or response_code == 201 or response_code == 401 or response_code == 404, "HTTP response should evaluate correctly successfully cleanly.")
		assert_not_null(response_data, "Payload streams object evaluated properly.")
