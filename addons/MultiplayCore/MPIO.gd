extends Node
class_name MultiPlayIO

var plr_id = 0

func logdata(data):
	var roles = ""
	
	roles = roles + "[" + str(plr_id) + "] "
	
	print_rich(roles + str(data))

func logwarn(data):
	logdata("[[color=yellow]WARN[/color]] " + str(data))

func logerr(data):
	logdata("[[color=red]ERR[/color]] " + str(data))
