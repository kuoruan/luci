--[[
luci for Gargoyle QoS
]]--

local sys = require "luci.sys"
local uci = require "luci.model.uci".cursor()

local m, s, o
local upload_classes = {}
local download_classes = {}
local qos_gargoyle_enabled = sys.init.enabled("qos_gargoyle")

uci:foreach("qos_gargoyle", "upload_class", function(s)
	local class_alias = s.name
	if class_alias then
		upload_classes[#upload_classes + 1] = {name = s[".name"], alias = class_alias}
	end
end)

uci:foreach("qos_gargoyle", "download_class", function(s)
	local class_alias = s.name
	if class_alias then
		download_classes[#download_classes + 1] = {name = s[".name"], alias = class_alias}
	end
end)

m = Map("qos_gargoyle", translate("Gargoyle QoS"), translate("Quality of Service (QoS) provides a way to control how available bandwidth is allocated."))

s = m:section(TypedSection, "global", translate("Global Settings"))
s.anonymous = true

o = s:option(Button, "_switch", nil, translate("QoS Switch"))
o.render = function(...)
	if qos_gargoyle_enabled then
		self.title = translate("Disable QoS")
		self.inputstyle = "reset"
	else
		self.title = translate("Enable QoS")
		self.inputstyle = "apply"
	end
	Button.render(...)
end

o.write = function(...)
	if qos_gargoyle_enabled then
		qos_gargoyle_enabled = false
		sys.call("/etc/init.d/qos_gargoyle stop >/dev/null")
		return sys.init.disable("qos_gargoyle")
	else
		qos_gargoyle_enabled = true
		sys.call("/etc/init.d/qos_gargoyle restart >/dev/null")
		return sys.init.enable("qos_gargoyle")
	end
end

s = m:section(TypedSection, "upload", translate("Upload Settings"))
s.anonymous = true

o = s:option(Value, "default_class", translate("Default Service Class"), translate("The <em>Default Service Class</em> specifies how packets that do not match any rule should be classified."))
for _, s in ipairs(upload_classes) do o:value(s.name, s.alias) end

o = s:option(Value, "total_bandwidth", translate("Total Upload Bandwidth"), translate("<em>Total Upload Bandwidth</em> should be set to around 98% of your available upload bandwidth. Entering a number which is too high will result in QoS not meeting its class requirements. Entering a number which is too low will needlessly penalize your upload speed. You should use a speed test program (with QoS off) to determine available upload bandwidth. Note that bandwidth is specified in kbps. There are 8 kilobits per kilobyte."))
o.datatype = "uinteger"


s = m:section(TypedSection, "download", translate("Download Settings"))
s.anonymous = true

o = s:option(Value, "default_class", translate("Default Service Class"), translate("The <em>Default Service Class</em> specifies how packets that do not match any rule should be classified."))
for _, s in ipairs(download_classes) do o:value(s.name, s.alias) end

o = s:option(Value, "total_bandwidth", translate("Total Download Bandwidth"), translate("Specifying <em>Total Download Bandwidth</em> correctly is crucial to making QoS work.Note that bandwidth is specified in kbps. There are 8 kilobits per kilobyte."))
o.datatype = "uinteger"

qos_monenabled = s:option(Flag, "qos_monenabled", translate("Enable Active Congestion Control"),
	translate("<p>The active congestion control (ACC) observes your download activity and automatically adjusts your download link limit to maintain proper QoS performance. ACC automatically compensates for changes in your ISP's download speed and the demand from your network adjusting the link speed to the highest speed possible which will maintain proper QoS function. The effective range of this control is between 15% and 100% of the total download bandwidth you entered above.</p>") ..
	translate("<p>While ACC does not adjust your upload link speed you must enable and properly configure your upload QoS for it to function properly.</p>") ..
	translate("<p><em>Ping Target-</em> The segment of network between your router and the ping target is where congestion is controlled. By monitoring the round trip ping times to the target congestion is detected. By default ACC uses your WAN gateway as the ping target. If you know that congestion on your link will occur in a different segment then you can enter an alternate ping target.</p>") ..
	translate("<p><em>Manual Ping Limit</em> Round trip ping times are compared against the ping limits. ACC controls the link limit to maintain ping times under the appropriate limit. By default ACC attempts to automatically select appropriate target ping limits for you based on the link speeds you entered and the performance of your link it measures during initialization. You cannot change the target ping time for the minRTT mode but by entering a manual time you can control the target ping time of the active mode. The time you enter becomes the increase in the target ping time between minRTT and active mode.")
	)
qos_monenabled.enabled  = "true"
qos_monenabled.disabled = "false"

o = s:option(Value, "ptarget_ip", translate("Use non-standard ping target"),translate("Specify a custom ping target here if you want.Leave empty to use the default settings."))
o:depends("qos_monenabled", "true")
o.datatype = "ipaddr"

o = s:option(Value, "pinglimit", translate("Manual Ping Limit"),translate("Specify a custom ping time limit here if you want.Leave empty to use the default settings."))
o:depends("qos_monenabled", "true")
o.datatype = "range(100, 2000)"

return m
