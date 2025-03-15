var load_garmin196 = func() {
    
}
# Avoid loading the garmin nasal if is not selected...
var loader = func(n){
	var loaded = props.globals.getNode("/instrumentation/garmin196/loaded").getBoolValue();
	if (n.getValue() == "bendix" and !loaded){	
			load_garmin196();
    } elsif (loaded) {
        # TODO: unload the nasal or something
		print("Garmin196 should unload now...");
    }
}
setprop("/instrumentation/garmin196/loaded",false);
setlistener("sim/model/config/radio-setup", loader,1);