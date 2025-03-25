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

# Create new electric system that updates 10 times a second.
var e_system = e.System.new("dr400",0.1);


# Starter and Main Bus
#
# Battery -- | Starter | -- [battery breaker] -- (battery-switch) -- | Main |
# Ext Pwr -- |   Bus   | -- {starter}                                | Bus  |
#
var starter_bus = e.Bus.new("starter-bus");
var main_bus = e.Bus.new("main-bus");


# Battery (12v 32a/h 240 CCA as per POH)
# connected to the starter bus to feed the starter directly.
# connected to the main bus from the starter bus via a 40A fuse and the battery switch.
# 
var battery = e.Battery.new("battery",12,32.0,cc_amps=240.0,charge_amps=2.0);
var battery_breaker = e.Breaker.new("battery",40.0);
var battery_switch = e.Switch.new("battery-switch","/controls/electric/battery-switch");

# System.connect support chaining.
e_system.connect(battery,starter_bus,battery_breaker, battery_switch, main_bus);

# Reverse connection for loading the battery...
e_system.connect(main_bus,battery_switch,battery_breaker,starter_bus,battery);


# Alternator (12v 50a/h as per POH)
# Connected to the main bus via a 50A fuse and a switch
#                                                              | Main|
# Alternator -- [alternator breaker] -- (alternator-switch) -- | Bus |
#

var alternator = e.Alternator.new("alternator","/engines/engine[0]/rpm",14.0,50.0);
var alternator_breaker = e.Breaker.new("alternator",50.0);
var alternator_switch = e.Switch.new("alternator-switch","/controls/engines/engine[0]/master-alt");
e_system.connect(alternator,alternator_breaker, alternator_switch,main_bus);

# External source
# Connected directly to the starter bus, but we add a switch to obey the
var external_source = e.Alternator.new("external",false,14.0,100.0);
e_system.connect(external_source,e.Switch.new("external-power","/controls/electric/external-power"),starter_bus);



### Engine related loads

# Starter engine draws 80A while cranking.
e_system.connect(starter_bus,e.Load.new("starter",80.0,"/controls/engines/engine[0]/starter_cmd"));

# The ignition coil draws a max average of 4A at full RPM.
# Override to adjust the load with the RPMs of the engine, and connect it to 
# the main bus with a 10A breaker.
var coil = e.Load.new("ignition-coil",5,"/controls/engines/engine[0]/faults/spark-plugs-serviceable");
coil.get_amps = func(volts) {
    var rpms = getprop("/engines/engine[0]/rpm");
    var factor = rpms /2500;
    return me.amps * factor;
}
e_system.connect(main_bus, e.Breaker.new("ignition-coil",10.0),coil);

# carb heat is not electric, but somehow it needs an electric output set...
e_system.connect(main_bus, e.Load.new("carb-heat",0.01,"/controls/anti-ice/engine/carb-heat"));

# 4A Fuel pump with 5A breaker.
e_system.connect(
    main_bus,
    e.Breaker.new("fuel-pump",5.0.0),
    e.Load.new("fuel-pump",4.0,"/controls/fuel/tank/boost-pump")
);


### Exterior lights

# landing light 250w @28v
e_system.connect(main_bus, e.Breaker.new("landing-lights",10.0), e.Light.new("landing-lights",9.0));
# Taxi light 100w @28v
e_system.connect(main_bus, e.Breaker.new("taxi-lights",5.0), e.Light.new("taxi-lights",3.6));
# 7w average led strobe light
e_system.connect(main_bus, e.Breaker.new("strobe-lights",1.0), e.Light.new("strobe-lights",0.25));
# 2x 15w led nav lights
e_system.connect(main_bus, e.Breaker.new("nav-lights",2.0), e.Light.new("nav-lights",1.1));

### Annunciators

# All annunciator lights are connected to a single 1A breaker.
var annunciators_breaker = e_system.connect(main_bus, e.Breaker.new("annunciators",1.0));

e_system.connect(annunciators_breaker,e.Annunciator.new("battery-charge"));
e_system.connect(annunciators_breaker,e.Annunciator.new("oil-pressure-low"));
e_system.connect(annunciators_breaker,e.Annunciator.new("fuel-pressure-low"));
e_system.connect(annunciators_breaker,e.Annunciator.new("fuel-low"));
e_system.connect(annunciators_breaker,e.Annunciator.new("starter"));
e_system.connect(annunciators_breaker,e.Annunciator.new("flaps"));

# Instrument lights (led 3w each)
e_system.connect(main_bus,e.Light.new("instrument-lights[0]",0.11));
e_system.connect(main_bus,e.Light.new("instrument-lights[1]",0.11));
e_system.connect(main_bus,e.Light.new("instrument-lights[2]",0.11));

# Flood Light
e_system.connect(main_bus,e.Light.new("flood-light-left",0.3));

### Avionics

# Avionics bus - connected to main bus.
var avionics_switch = e.Switch.new("master-avionics","controls/switches/master-avionics" );
var avionics_bus = e.Bus.new("avionics-bus");
e_system.connect(main_bus,avionics_switch,avionics_bus);

# Manages different radio panel options.
# Connects the avionics loads according to the sim/model/config/radio-setup prop.
var check_radio_setup = func(n) {
    var radio_setup = n.getValue();
    # TODO: is this enough? maybe we need to disconnect the loads first.
    avionics_bus.loads = [];
    
    e_system.connect(avionics_bus, e.Load.new("turn-coordinator",1.0,"controls/switches/master-avionics"));

    var radio_breaker = e_system.connect(avionics_bus, e.Breaker.new("radio",10.0));
    if (radio_setup == "bendix") {
        e_system.connect(avionics_bus,e.Breaker.new("transponder",10.0), e.Load.new("transponder",3.0,"/instrumentation/transponder/power-btn"));
        e_system.connect(radio_breaker, e.Load.new("comm[0]",0.5,"/instrumentation/comm[0]/power-btn"));
        e_system.connect(radio_breaker, e.Load.new("nav[0]",0.5,"/instrumentation/nav[0]/power-btn"));
        e_system.connect(avionics_bus, e.Breaker.new("adf",2.0), e.Load.new("adf",1.0,"/instrumentation/adf/power-btn"));
        e_system.connect(avionics_bus, e.Load.new("gps",0.5,"controls/switches/master-avionics"));
        print("### Bendix avionics connected to bus");
    } elsif (radio_setup == "garmin") {
        e_system.connect(avionics_bus, e.Load.new("ipad",0.5,"controls/switches/master-avionics"));
        e_system.connect(avionics_bus, e.Load.new("comm[0]",1.0,"controls/switches/master-avionics"));
        e_system.connect(avionics_bus, e.Load.new("nav[0]",1.0,"controls/switches/master-avionics"));
        e_system.connect(avionics_bus, e.Load.new("transponder",3.0,"controls/switches/master-avionics"));
        print("### Garmin avionics connected to bus");
    } elsif (radio_setup == "gns530") {
        var gns530 = e.Load.new("gns530",3.0,"controls/switches/master-avionics");
        e_system.connect(avionics_bus, e.Breaker.new("gps",10.0),gns530);
        
        # Comms are tricky b/c they use a lot only when transmitting.
        # TODO: add a "peak use" to e.Load or create a Radio class that manages that.
        e_system.connect(radio_breaker, e.Load.new("comm[0]",0.5,"controls/switches/master-avionics"));
        e_system.connect(radio_breaker, e.Load.new("nav[0]",0.5,"controls/switches/master-avionics"));
        e_system.connect(avionics_bus,e.Breaker.new("transponder-breaker",10.0), e.Load.new("transponder",3.0,"/instrumentation/transponder/power-btn"));
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
    e_system.connect(avionics_bus, e.Load.new("fg1000",9.0,"controls/switches/master-avionics"));
    
}

e_system.enable();
print("DR400 electrical system started");
