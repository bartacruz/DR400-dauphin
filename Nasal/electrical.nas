###############################################################################
##
##  Electrical management for DR400-dauphin
##
##  Julio Santa Cruz (Barta)
##  
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

var system = electric.System.new("dr400");

# Battery (12v 32a/h 240 CCA as per POH)
var battery = electric.Battery.new("battery","/controls/electric/battery-switch",12,32.0,240.0);

# Alternator (12v 50a/h as per POH)
var alternator = electric.Alternator.new("alternator","/controls/engines/engine[0]/master-alt","/engines/engine[0]/rpm",14.0,50.0);

# External source
var external_source = electric.Alternator.new("external","/controls/electric/external-power",false,14.0,100.0);

# Main bus
var main_bus = electric.Bus.new("main", "/systems/electrical/serviceable");

system.connect(battery,main_bus);
system.connect(alternator,main_bus);
system.connect(external_source,main_bus);

# Avionics bus
var avionics_bus = electric.Bus.new("avionics","controls/switches/master-avionics" );
var avionics_breaker = electric.Breaker.new("avionics",15);

### Engine related loads

# Starter engine draws 80A while cranking.
system.connect(main_bus,electric.Load.new("starter",80.0,"/controls/engines/engine[0]/starter_cmd"));

# The ignition coil draws a max average of 4A at full RPM
# Override to adjust the load with the RPMs of the engine.
var coil = electric.Load.new("ignition-coil",5,"/controls/engines/engine[0]/faults/spark-plugs-serviceable");
coil.get_amps = func(volts) {
    var rpms = getprop("/engines/engine[0]/rpm");
    var factor = rpms /2500;
    return me.amps * factor;
}
system.connect(main_bus,coil);


# carb heat is not electric, but somehow it needs an electric output set.
system.connect(main_bus, electric.Load.new("carb-heat",0.01,"/controls/anti-ice/engine/carb-heat"));
system.connect(main_bus, electric.Load.new("fuel-pump",5.0,"/controls/fuel/tank/boost-pump"));


# Exterior lights
# landing light 250w @28v
var landing_breaker = system.connect(main_bus, electric.Breaker.new("landing-lights",10.0));
system.connect(landing_breaker,electric.Light.new("landing-lights",9.0));
# Taxi light 100w @28v
var taxi_breaker = system.connect(main_bus, electric.Breaker.new("taxi-lights",5.0));
system.connect(taxi_breaker,electric.Light.new("taxi-lights",3.6));
# 7w average led strobe light
var strobe_breaker = system.connect(main_bus, electric.Breaker.new("strobe-lights",1.0));
system.connect(strobe_breaker,electric.Light.new("strobe-lights",0.25));
# 2x 15w led nav lights
var nav_breaker = system.connect(main_bus, electric.Breaker.new("nav-lights",2.0));
system.connect(nav_breaker,electric.Light.new("nav-lights",1.1));

# Annunciators
var annunciators_breaker = system.connect(main_bus, electric.Breaker.new("annunciators",1.0));
system.connect(annunciators_breaker,electric.Load.new("annunciator-battery-charge",0.036,"/instrumentation/annunciators/systems/electric/battery-charge"));
system.connect(annunciators_breaker,electric.Load.new("annunciator-oil-pressure",0.036,"/instrumentation/annunciators/engines/oil-pressure-low"));
system.connect(annunciators_breaker,electric.Load.new("annunciator-fuel-pressure",0.036,"/instrumentation/annunciators/systems/fuel/pressure-low"));
system.connect(annunciators_breaker,electric.Load.new("annunciator-fuel-low",0.036,"/instrumentation/annunciators/systems/fuel/fuel-low"));
system.connect(annunciators_breaker,electric.Load.new("annunciator-starter",0.036,"/instrumentation/annunciators/engines/engine[0]/starter"));
system.connect(annunciators_breaker,electric.Load.new("annunciator-flaps",0.036,"/instrumentation/annunciators/flaps"));

# Instrument lights (led 3w each)
system.connect(main_bus,electric.Light.new("instrument-lights[0]",0.11));
system.connect(main_bus,electric.Light.new("instrument-lights[1]",0.11));
system.connect(main_bus,electric.Light.new("instrument-lights[2]",0.11));



# Avionics

var check_radio_setup = func(n) {
    var radio_setup = n.getValue();
    avionics_bus.clear();
    # The avionics bus is connected to the main bus
    system.connect(main_bus,avionics_bus);
    system.connect(avionics_bus, electric.Load.new("turn-coordinator",1.0,"controls/switches/master-avionics"));

    if (radio_setup == "bendix") {
        system.connect(avionics_bus, electric.Load.new("transponder",1.0,"/instrumentation/transponder/power-btn"));
        system.connect(avionics_bus, electric.Load.new("comm[0]",0.5,"/instrumentation/comm[0]/power-btn"));
        system.connect(avionics_bus, electric.Load.new("nav[0]",0.5,"/instrumentation/nav[0]/power-btn"));
        system.connect(avionics_bus, electric.Load.new("adf",1.0,"/instrumentation/adf/power-btn"));
        system.connect(avionics_bus, electric.Load.new("gps",0.5,"controls/switches/master-avionics"));
        print("### Bendix avionics connected to bus");
    } elsif (radio_setup == "garmin") {
        system.connect(avionics_bus, electric.Load.new("ipad",0.5,"controls/switches/master-avionics"));
        system.connect(avionics_bus, electric.Load.new("comm[0]",1.0,"controls/switches/master-avionics"));
        system.connect(avionics_bus, electric.Load.new("nav[0]",1.0,"controls/switches/master-avionics"));
        system.connect(avionics_bus, electric.Load.new("transponder",30.0,"controls/switches/master-avionics"));
        print("### Garmin avionics connected to bus");
    } elsif (radio_setup == "gns530") {
        var aux_batt = electric.Battery.new("gns530batt","controls/switches/master-avionics",12,7.0,10.0);
        var auxbattbus = electric.Bus.new("auxbattbus","controls/switches/master-avionics");
        var gns530 = electric.Load.new("gns530",3.0,"controls/switches/master-avionics");

        system.connect(avionics_bus, gns530);
        system.connect(aux_batt, auxbattbus);
        system.connect(auxbattbus, gns530);
        # Comms are tricky b/c they use a lot only when transmitting.
        # TODO: add a "peak use" to electric.Load
        system.connect(avionics_bus, electric.Load.new("comm[0]",0.5,"controls/switches/master-avionics"));
        system.connect(avionics_bus, electric.Load.new("nav[0]",0.5,"controls/switches/master-avionics"));
        system.connect(avionics_bus, electric.Load.new("transponder",3.0,"/instrumentation/transponder/power-btn"));
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
    system.connect(avionics_bus, electric.Load.new("fg1000",9.0,"controls/switches/master-avionics"));
    
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
