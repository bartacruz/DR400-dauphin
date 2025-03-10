###############################################################################
##
##  Electrical management for DR400-dauphin
##
##  Julio Santa Cruz (Barta)
##  
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

# Battery (12v 32a/h 240 CCA as per POH)
#var battery = Electric.Battery.new("a","/controls/electric/battery-switch",13.5,240.0,32.0,32.0);

var battery = Electric.Battery.new("a","/controls/electric/battery-switch",24.0,32.0,120.0);

# Alternator (12v 50a/h as per POH)
var alternator = Electric.Alternator.new("/controls/engines/engine[0]/master-alt","/engines/engine[0]/rpm",28.0,50.0);

# External source
var external_source = Electric.Alternator.new("/controls/electric/external-power",false,28.0,50.0);

# Main bus
var main_bus = Electric.Bus.new("main", "/systems/electrical/serviceable");

# Avionics bus
var avionics_bus = Electric.Bus.new("avionics","controls/switches/master-avionics" );

# Engine related loads
main_bus.add_load(Electric.Load.new("starter",80.0,"/controls/engines/engine[0]/starter_cmd"));
# carb heat is not electric, but somehow it needs an electric output set.
main_bus.add_load(Electric.Load.new("carb-heat",0.01,"/controls/anti-ice/engine/carb-heat"));
main_bus.add_load(Electric.Load.new("fuel-pump",5.0,"/controls/fuel/tank/boost-pump"));




# Exterior lights
# landing light 250w @28v
main_bus.add_load(Electric.Load.new("landing-light",9.0,"/controls/lighting/landing-lights"));
# Taxi light 100w @28v
main_bus.add_load(Electric.Load.new("taxi-lights",3.6,"/controls/lighting/taxi-lights"));
# 7w average led strobe light
main_bus.add_load(Electric.Load.new("strobe-lights",0.25,"/controls/lighting/strobe-lights"));
# 2x 15w led nav lights
main_bus.add_load(Electric.Load.new("nav-lights",1.1,"/controls/lighting/nav-lights"));

# Annunciators
main_bus.add_load(Electric.Load.new("annunciator-battery-charge",0.036,"/instrumentation/annunciators/systems/electric/battery-charge"));
main_bus.add_load(Electric.Load.new("annunciator-oil-pressure",0.036,"/instrumentation/annunciators/engines/oil-pressure-low"));
main_bus.add_load(Electric.Load.new("annunciator-fuel-pressure",0.036,"/instrumentation/annunciators/systems/fuel/pressure-low"));
main_bus.add_load(Electric.Load.new("annunciator-fuel-low",0.036,"/instrumentation/annunciators/systems/fuel/fuel-low"));
main_bus.add_load(Electric.Load.new("annunciator-starter",0.036,"/instrumentation/annunciators/engines/engine[0]/starter"));
main_bus.add_load(Electric.Load.new("annunciator-flaps",0.036,"/instrumentation/annunciators/flaps"));

# Instrument lights (led 3w each)
main_bus.add_load(Electric.Load.new("instrument-lights[0]",0.11,"/controls/lighting/instrument-lights[0]"));
main_bus.add_load(Electric.Load.new("instrument-lights[1]",0.11,"/controls/lighting/instrument-lights[1]"));
main_bus.add_load(Electric.Load.new("instrument-lights[2]",0.11,"/controls/lighting/instrument-lights[2]"));

# The avionics bus is connected to the master bus
main_bus.add_load(avionics_bus);

# Avionics

var check_radio_setup = func(n) {
    var radio_setup = n.getValue();
    avionics_bus.clear();
    avionics_bus.add_load(Electric.Load.new("turn-coordinator",.0,"controls/switches/master-avionics"));

    if (radio_setup == "bendix") {
        avionics_bus.add_load(Electric.Load.new("transponder",1.0,"/instrumentation/transponder/power-btn"));
        avionics_bus.add_load(Electric.Load.new("comm[0]",0.5,"/instrumentation/comm[0]/power-btn"));
        avionics_bus.add_load(Electric.Load.new("nav[0]",0.5,"/instrumentation/nav[0]/power-btn"));
        avionics_bus.add_load(Electric.Load.new("adf",1.0,"/instrumentation/adf/power-btn"));
        avionics_bus.add_load(Electric.Load.new("gps",0.5,"controls/switches/master-avionics"));
        print("### Bendix avionics connected to bus");
    } elsif (radio_setup == "garmin") {
        avionics_bus.add_load(Electric.Load.new("ipad",0.5,"controls/switches/master-avionics"));
        avionics_bus.add_load(Electric.Load.new("comm[0]",1.0,"controls/switches/master-avionics"));
        avionics_bus.add_load(Electric.Load.new("nav[0]",1.0,"controls/switches/master-avionics"));
        avionics_bus.add_load(Electric.Load.new("transponder",30.0,"controls/switches/master-avionics"));
        print("### Garmin avionics connected to bus");
    } elsif (radio_setup == "gns530") {
        avionics_bus.add_load(Electric.Load.new("gns530",3.0,"controls/switches/master-avionics"));
        # Comms are tricky b/c they use a lot only when transmitting.
        # TODO: add a "peak use" to Electric.Load
        avionics_bus.add_load(Electric.Load.new("comm[0]",0.5,"controls/switches/master-avionics"));
        avionics_bus.add_load(Electric.Load.new("nav[0]",0.5,"controls/switches/master-avionics"));
        avionics_bus.add_load(Electric.Load.new("transponder",3.0,"/instrumentation/transponder/power-btn"));
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
    avionics_bus.add_load(Electric.Load.new("fg1000",9.0,"controls/switches/master-avionics"));
    
}
    

##
# Model the system of relays and connections that join the battery,
# alternator, starter, master/alt switches, external power supply.
#
var update_virtual_bus = func (dt) {
    var serviceable = getprop("/systems/electrical/serviceable");
    var load_amps = 0.0;
    var remaining_amps = 0.0;
    var charge_amps = 0.0;
    var source = nil;
    var source_label = nil; # for debugging.


    if (! serviceable) {
        return load_amps;
    }

    
    if (external_source.volts()) {
        source = external_source;
        source_label = "external";
    } elsif (alternator.volts() and alternator.volts() > battery.volts()) {
        source = alternator;
        source_label = "alternator";
    } else {
        source = battery;
        source_label = "battery";
    }
    # 
    if (source.volts() > 0) {
        var load_amps = main_bus.get_load(source.volts());
        # apply load and get remaining amps for battery charging purposes.
        remaining_amps = source.apply_load( load_amps, dt, "a");
        
        
        # charge the battery
        # TODO: if the load surpasses the alternator current, should the battery
        # be discharged then??
        if (source != battery and  source.volts() >= battery.volts()) {
            charge_amps = std.min(battery.ideal_amps, remaining_amps);
            battery.apply_load(-1*charge_amps, dt, "a");
        }
    }

    # outputs to fg1000 EIS
    # system loads and ammeter gauge master bat
    var ammeter = 0.0;
    if ( source.volts() > 1.0 ) {
        # ammeter gauge
        if ( source == battery) {
            ammeter = -load_amps;
        } else {
            ammeter = charge_amps
        }
    }
    Electric.setpropr(4,"/systems/electrical/amps", ammeter);
    Electric.setpropr(4,"/systems/electrical/volts", source.volts());
    setprop("/systems/electrical/source", source_label);
    Electric.setpropr(4,"/systems/electrical/amps_charging", charge_amps);
    Electric.setpropr(4,"/systems/electrical/amps_remaining", remaining_amps);
    return load_amps;
}

##
# This is the main electrical system update function.
#
var ElectricalSystemUpdater = {
    new : func {
        var m = {
            parents: [ElectricalSystemUpdater]
        };
        # Request that the update function be called each frame
        m.loop = updateloop.UpdateLoop.new(components: [m], update_period: 0.0, enable: 0);
        return m;
    },

    enable: func {
        me.loop.reset();
        me.loop.enable();
    },

    disable: func {
        me.loop.disable();
    },

    reset: func {
        # Do nothing
    },

    update: func (dt) {
        update_virtual_bus(dt);
    }
};

##
# Initialize the electrical system
#

var system_updater = ElectricalSystemUpdater.new();

# checking if battery should be automatically recharged
if (!getprop("/systems/electrical/save-battery-charge")) {
    battery.reset_to_full_charge("a");
};

system_updater.enable();

print("Electrical system initialized");

