extends Node

static func run():
	var for_address = "127.0.0.1"
	
	print("Creating certificate for address " + str(for_address))
	var crypto = Crypto.new()
	var key = crypto.generate_rsa(4096)
	var cert = crypto.generate_self_signed_certificate(key, "CN=" + str(for_address) + ",O=myorganisation,C=IT")
	
	key.save("res://private_key.key")
	cert.save("res://cert.crt")
	
	print("Created self signed certificate! These are for development uses only.")
	print("res://private_key.key")
	print("res://cert.crt")
