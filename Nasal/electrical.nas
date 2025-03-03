##
# Procedural model of a Cessna 172S electrical system.  Includes a
# preliminary battery charge/discharge model and realistic ammeter
# gauge modeling.
#


##
# Initialize the electric system
#


# Battery (12v 32a/h 240 CCA as per POH)
#var battery = Electric.Battery.new("a","/controls/electric/battery-switch",13.5,240.0,32.0,32.0);
var battery = Electric.Battery.new("a","/controls/electric/battery-switch",24.0,120.0,32.0,32.0);

# Alternator (12v 50a/h as per POH)
var alternator = Electric.Alternator.new("/controls/engines/engine[0]/master-alt","/engines/engine[0]/rpm",28.0,50.0);

# External source
var external_source = Electric.Alternator.new("/controls/electric/external-power",false,28.0,100.0);

# Main bus
var main_bus = Electric.Bus.new("main", "/systems/electrical/serviceable");

# Avionics bus
var avionics_bus = Electric.Bus.new("avionics","controls/switches/master-avionics" );

# Engine related loads
main_bus.add_load(Electric.Load.new("starter",50.0,"/controls/engines/engine[0]/starter_cmd"));
main_bus.add_load(Electric.Load.new("carb-heat",2.0,"/controls/anti-ice/engine/carb-heat"));
main_bus.add_load(Electric.Load.new("fuel-pump",1.0,"/controls/fuel/tank/boost-pump"));

# Exterior lights
main_bus.add_load(Electric.Load.new("landing-light",10.0,"/controls/lighting/landing-lights"));
main_bus.add_load(Electric.Load.new("strobe-lights",5.0,"/controls/lighting/strobe-lights"));
main_bus.add_load(Electric.Load.new("nav-lights",5.0,"/controls/lighting/nav-lights"));
main_bus.add_load(Electric.Load.new("taxi-lights",8.0,"/controls/lighting/taxi-lights"));

# Instrument lights (1A)
main_bus.add_load(Electric.Load.new("instrument-lights[0]",1.0,"/controls/lighting/instrument-lights[0]"));
main_bus.add_load(Electric.Load.new("instrument-lights[1]",1.0,"/controls/lighting/instrument-lights[1]"));
main_bus.add_load(Electric.Load.new("instrument-lights[2]",1.0,"/controls/lighting/instrument-lights[2]"));

# The avionics bus is connected to the master bus
main_bus.add_load(avionics_bus);

# AVionics
avionics_bus.add_load(Electric.Load.new("turn-indicator",2.0,"/instrumentation/turn-indicator/power-btn"));
var panel = getprop("/sim/model/config/panel");
if (panel == "traditional") {
    avionics_bus.add_load(Electric.Load.new("transponder",3.0,"/instrumentation/transponder/power-btn"));
    avionics_bus.add_load(Electric.Load.new("comm[0]",3.0,"/instrumentation/comm[0]/power-btn"));
    avionics_bus.add_load(Electric.Load.new("nav[0]",3.0,"/instrumentation/nav[0]/power-btn"));
    avionics_bus.add_load(Electric.Load.new("adf",3.0,"/instrumentation/adf/power-btn"));
} elsif (panel == "fg1000") {
    # avionics_bus.add_load(Electric.Load.new("comm[0]",3.0,"/instrumentation/comm[0]/power-btn"));
    # avionics_bus.add_load(Electric.Load.new("nav[0]",3.0,"/instrumentation/nav[0]/power-btn"));
    # avionics_bus.add_load(Electric.Load.new("comm[1]",3.0,"/instrumentation/comm[1]/power-btn"));
    # avionics_bus.add_load(Electric.Load.new("nav[1]",3.0,"/instrumentation/nav[1]/power-btn"));
    avionics_bus.add_load(Electric.Load.new("fg1000",1.0,"controls/switches/master-avionics"));
} elsif (panel == "GNS530") {
    avionics_bus.add_load(Electric.Load.new("adf",3.0,"/instrumentation/adf/power-btn"));
    avionics_bus.add_load(Electric.Load.new("transponder",3.0,"/instrumentation/transponder/power-btn"));
    avionics_bus.add_load(Electric.Load.new("gns530",6.0,"controls/switches/master-avionics"));
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
        var draw = main_bus.get_load(source.volts()); # in Watts
        load_amps = draw / source.volts(); # convert to Amps
        # apply load and get remaining amps for battery charging purposes.
        remaining_amps = source.apply_load( load_amps, dt, "a");
        # charge the battery
        if (source != battery and  source.volts() >= battery.volts()) {
            charge_amps = std.min(battery.charge_amps, remaining_amps);
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
            ammeter = battery.charge_amps;
        }
    }
    setprop("/systems/electrical/amps", ammeter);
    setprop("/systems/electrical/volts", source.volts());
    setprop("/systems/electrical/source", source_label);
    setprop("/systems/electrical/amps_charging", charge_amps);
    setprop("/systems/electrical/amps_remaining", remaining_amps);
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

