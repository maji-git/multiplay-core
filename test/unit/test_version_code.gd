extends GutTest

func test_version_code():
	var cf = ConfigFile.new()
	cf.load("res://addons/MultiplayCore/plugin.cfg")
	assert_eq(cf.get_value("plugin", "version"), MultiPlayCore.MP_VERSION, "Version Matching")
