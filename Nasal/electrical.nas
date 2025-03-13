###############################################################################
##
##  Electrical management for DR400-dauphin
##
##  Julio Santa Cruz (Barta)
##  
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Shorthand
var e = electric;

var system = e.System.new("dr400");

# Main bus
var main_bus = e.Bus.new("main", "/systems/electrical/serviceable");
var starter_bus = e.Bus.new("starter", "/systems/electrical/serviceable");

# Battery (12v 32a/h 240 CCA as per POH)
# connected to the starter bus 
# connected to the main bus from the starter bus via a 40A fuse.
var battery = e.Battery.new("battery","/controls/electric/battery-switch",12,32.0,cc_amps=240.0,charge_amps=2.0);
var battery_breaker = e.Breaker.new("battery",40.0);
system.connect(battery,starter_bus);
system.connect(starter_bus,battery_breaker);
system.connect(battery_breaker,main_bus);

# Alternator (12v 50a/h as per POH)
# Connected to the main bus via a 50A fuse
var alternator = e.Alternator.new("alternator","/controls/engines/engine[0]/master-alt","/engines/engine[0]/rpm",14.0,50.0);
var alternator_breaker = e.Breaker.new("alternator",50.0);
system.connect(alternator,alternator_breaker);
system.connect(alternator_breaker,main_bus);

# External source
# Connected directly to the starter bus
var external_source = e.Alternator.new("external","/controls/electric/external-power",false,14.0,100.0);
system.connect(external_source,starter_bus);



### Engine related loads

# Starter engine draws 80A while cranking.
system.connect(starter_bus,e.Load.new("starter",80.0,"/controls/engines/engine[0]/starter_cmd"));

# The ignition coil draws a max average of 4A at full RPM
# Override to adjust the load with the RPMs of the engine.
var coil = e.Load.new("ignition-coil",5,"/controls/engines/engine[0]/faults/spark-plugs-serviceable");
coil.get_amps = func(volts) {
    var rpms = getprop("/engines/engine[0]/rpm");
    var factor = rpms /2500;
    return me.amps * factor;
}
var coil_breaker = system.connect(main_bus, e.Breaker.new("ignition-coil",10.0));
system.connect(main_bus,coil_breaker);
system.connect(coil_breaker,coil);


# carb heat is not electric, but somehow it needs an electric output set.
system.connect(main_bus, e.Load.new("carb-heat",0.01,"/controls/anti-ice/engine/carb-heat"));
var pump_breaker = system.connect(main_bus, e.Breaker.new("fuel-pump",10.0));
system.connect(pump_breaker, e.Load.new("fuel-pump",5.0,"/controls/fuel/tank/boost-pump"));


# Exterior lights
# landing light 250w @28v
system.connect(main_bus, e.Breaker.new("landing-lights",10.0), e.Light.new("landing-lights",9.0));
# Taxi light 100w @28v
system.connect(main_bus, e.Breaker.new("taxi-lights",5.0), e.Light.new("taxi-lights",3.6));
# 7w average led strobe light
system.connect(main_bus, e.Breaker.new("strobe-lights",1.0), e.Light.new("strobe-lights",0.25));
# 2x 15w led nav lights
system.connect(main_bus, e.Breaker.new("nav-lights",2.0), e.Light.new("nav-lights",1.1));

# Annunciators
var annunciators_breaker = system.connect(main_bus, e.Breaker.new("annunciators",1.0));
system.connect(annunciators_breaker,e.Load.new("annunciator-battery-charge",0.036,"/instrumentation/annunciators/systems/electric/battery-charge"));
system.connect(annunciators_breaker,e.Load.new("annunciator-oil-pressure",0.036,"/instrumentation/annunciators/engines/oil-pressure-low"));
system.connect(annunciators_breaker,e.Load.new("annunciator-fuel-pressure",0.036,"/instrumentation/annunciators/systems/fuel/pressure-low"));
system.connect(annunciators_breaker,e.Load.new("annunciator-fuel-low",0.036,"/instrumentation/annunciators/systems/fuel/fuel-low"));
system.connect(annunciators_breaker,e.Load.new("annunciator-starter",0.036,"/instrumentation/annunciators/engines/engine[0]/starter"));
system.connect(annunciators_breaker,e.Load.new("annunciator-flaps",0.036,"/instrumentation/annunciators/flaps"));

# Instrument lights (led 3w each)
system.connect(main_bus,e.Light.new("instrument-lights[0]",0.11));
system.connect(main_bus,e.Light.new("instrument-lights[1]",0.11));
system.connect(main_bus,e.Light.new("instrument-lights[2]",0.11));



### Avionics

# Avionics bus - connected to main bus.
var avionics_bus = e.Bus.new("avionics","controls/switches/master-avionics" );
system.connect(main_bus,avionics_bus);

var check_radio_setup = func(n) {
    var radio_setup = n.getValue();
    avionics_bus.loads = [];
    
    system.connect(avionics_bus, e.Load.new("turn-coordinator",1.0,"controls/switches/master-avionics"));

    var radio_breaker = system.connect(avionics_bus, e.Breaker.new("radio",10.0));
    if (radio_setup == "bendix") {
        system.connect(avionics_bus,e.Breaker.new("transponder",10.0), e.Load.new("transponder",3.0,"/instrumentation/transponder/power-btn"));
        system.connect(radio_breaker, e.Load.new("comm[0]",0.5,"/instrumentation/comm[0]/power-btn"));
        system.connect(radio_breaker, e.Load.new("nav[0]",0.5,"/instrumentation/nav[0]/power-btn"));
        system.connect(avionics_bus, e.Breaker.new("adf",2.0), e.Load.new("adf",1.0,"/instrumentation/adf/power-btn"));
        system.connect(avionics_bus, e.Load.new("gps",0.5,"controls/switches/master-avionics"));
        print("### Bendix avionics connected to bus");
    } elsif (radio_setup == "garmin") {
        system.connect(avionics_bus, e.Load.new("ipad",0.5,"controls/switches/master-avionics"));
        system.connect(avionics_bus, e.Load.new("comm[0]",1.0,"controls/switches/master-avionics"));
        system.connect(avionics_bus, e.Load.new("nav[0]",1.0,"controls/switches/master-avionics"));
        system.connect(avionics_bus, e.Load.new("transponder",3.0,"controls/switches/master-avionics"));
        print("### Garmin avionics connected to bus");
    } elsif (radio_setup == "gns530") {
        var aux_batt = e.Battery.new("gns530batt","controls/switches/master-avionics",12,7.0,10.0);
        var auxbattbus = e.Bus.new("auxbattbus","controls/switches/master-avionics");
        var gns530 = e.Load.new("gns530",3.0,"controls/switches/master-avionics");

        system.connect(avionics_bus, e.Breaker.new("gps",10.0),gns530);
        system.connect(aux_batt, auxbattbus, gns530);
        # Comms are tricky b/c they use a lot only when transmitting.
        # TODO: add a "peak use" to e.Load
        system.connect(radio_breaker, e.Load.new("comm[0]",0.5,"controls/switches/master-avionics"));
        system.connect(radio_breaker, e.Load.new("nav[0]",0.5,"controls/switches/master-avionics"));
        system.connect(avionics_bus,e.Breaker.new("transponder",10.0), e.Load.new("transponder",3.0,"/instrumentation/transponder/power-btn"));
        print("### GNS530 avionics connected to bus");
    } else {
        print("### WARNING: NO avionics connected to bus");
    }
    
}

var panel = getprop("/sim/model/config/panel");
if (panel == "traditional") {
    setlistener("sim/model/config/radio-setup", check_radio_setup,1);
    
} elsif (panel == "fg1000") {
    # separate this into MDF/PDF/Audio panel??
    system.connect(avionics_bus, e.Load.new("fg1000",9.0,"controls/switches/master-avionics"));
    
}
    


##
# Initialize the electrical system
#
system.enable();

# checking if battery should be automatically recharged
if (!getprop("/systems/electrical/save-battery-charge")) {
    battery.reset_to_full_charge();
};

print("electrical system initialized");
