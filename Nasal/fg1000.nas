var nasal_dir = nil;
var interfaceController = nil;


var load_fg1000 = func() {
	
	
	nasal_dir = getprop("/sim/fg-root") ~ "/Aircraft/Instruments-3d/FG1000/Nasal/";
	io.load_nasal(nasal_dir ~ 'FG1000.nas', "fg1000");
	io.load_nasal(nasal_dir ~ 'Interfaces/GenericInterfaceController.nas', "fg1000");
	
	interfaceController = fg1000.GenericInterfaceController.getOrCreateInstance();
	interfaceController.start();
	
	# Create the FG1000
	var fg1000system = fg1000.FG1000.getOrCreateInstance();
	
	# Create a PFD as device 1, MFD as device 2
	fg1000system.addPFD(1);
	fg1000system.addMFD(2);
	
	# Display the devices
	fg1000system.display(1);
	fg1000system.display(2);
	setprop("/instrumentation/fg1000/loaded",true);
	print("FG1000 panel: loaded");
	dr400.fg1000system = fg1000system;
}
# Turn on/off the displays 
var fg1000_power = func(n) {
	var fg1000system = dr400.fg1000system;
	if (n.getValue() > 6) {
		# Show the device
		fg1000system.show(index:1);
		fg1000system.show(index:2);
		
		# Turn on the radios and navs
		setprop("/instrumentation/comm/power-btn",1);
		setprop("/instrumentation/comm[1]/power-btn",1);
		setprop("/instrumentation/nav/power-btn",1);
		setprop("/instrumentation/nav[1]/power-btn",1);
	} elsif (fg1000system) {
		fg1000system.hide(index:1);
		fg1000system.hide(index:2);
		# Turn off the radios and navs
		setprop("/instrumentation/comm/power-btn",0);
		setprop("/instrumentation/comm[1]/power-btn",0);
		setprop("/instrumentation/nav/power-btn",0);
		setprop("/instrumentation/nav[1]/power-btn",0);
    }
};

var loader = func(n){
	var loaded = props.globals.getNode("/instrumentation/fg1000/loaded").getBoolValue();
	print("FG1000 panel panel=" ~ n.getValue() ~ ", loaded? "~ loaded);
	if (n.getValue() == "fg1000"){	
		if (!loaded) {
			load_fg1000();
		}
		power_listener = setlistener("/systems/electrical/outputs/fg1000", fg1000_power);
		print("FG1000 panel: power listener hooked");
    } elsif (loaded) {
        # TODO: can't unload the nasal, but we should destroy the MFD...
		if (dr400.fg1000system) {
			dr400.fg1000system.hide(index:1);
			dr400.fg1000system.hide(index:2);
		};
		removelistener(power_listener);
		print("FG1000 panel: power listener UNhooked");
    }
}
setlistener("sim/model/config/panel", loader,1);
print("FG1000 panel: power listener UNhooked");


