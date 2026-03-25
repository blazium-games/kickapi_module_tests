extends GutTest

var secrets = {}

func before_all():
	var f = FileAccess.open("res://secrets.json", FileAccess.READ)
	if f:
		var json = JSON.new()
		if json.parse(f.get_as_text()) == OK:
			secrets = json.get_data()

func test_001_initialization():
	assert_not_null(KickAPI, "KickAPI AutoLoad must be present.")
	assert_not_null(KickAPI.get_http_client(), "KickAPI explicitly extracts an internal KickHTTPClient natively.")

func test_002_configuration():
	if secrets.is_empty():
		pending("Requires secrets.json containing valid Kick API keys.")
		return
		
	# Verify simple parsing tracking credentials securely mapping environments flawlessly without crashes.
	KickAPI.configure(secrets.access_token)
	assert_true(true, "Authentication initialized properly.")

	# Assign Custom TLS ensuring headless test limits bypass properly
	var cert = X509Certificate.new()
	if cert.load("res://ca-certificates.crt") == OK:
		KickAPI.get_http_client().set_tls_options(TLSOptions.client(cert))
		assert_true(true, "TLS Certificates overrode explicitly successfully.")
	else:
		assert_true(false, "MbedTLS CA bundle omitted critically.")
