extends GutTest

func test_version_code():
	var cf = ConfigFile.new()
	cf.load("res://addons/MultiplayCore/plugin.cfg")
	assert_eq(MultiPlayCore.MP_VERSION, cf.get_value("plugin", "version"), "Version Matched")
