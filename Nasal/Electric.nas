##
# Battery model class.
#

var Battery = {};

Battery.new = func (x, switch, volts,amps,ah,charge_amps, charge_percent=0) {
    var obj = { parents : [Battery],
      switch: switch,
      ideal_volts : volts,
      ideal_amps : amps,
      amp_hours : ah,
      charge_percent : charge_percent or getprop("/systems/electrical/battery-charge-percent-"~x) or 1.0,
      charge_amps : charge_amps };
    setprop("/systems/electrical/battery-charge-percent-"~x, obj.charge_percent);
    return obj;
}

##
# Passing in positive amps means the battery will be discharged.
# Negative amps indicates a battery charge.
#
Battery.apply_load = func (amps, dt, x) {
    var old_charge_percent = getprop("/systems/electrical/battery-charge-percent-"~x);

    if (getprop("/sim/freeze/replay-state"))
        return me.amp_hours * old_charge_percent;

    var amphrs_used = amps * dt / 3600.0;
    var percent_used = amphrs_used / me.amp_hours;

    var new_charge_percent = std.max(0.0, std.min(old_charge_percent - percent_used, 1.0));

    if (new_charge_percent < 0.1 and old_charge_percent >= 0.1)
        gui.popupTip("Warning: Low battery! Enable alternator or apply external power to recharge battery!", 10);
    me.charge_percent = new_charge_percent;
    setprop("/systems/electrical/battery-charge-percent-"~x, new_charge_percent);
    setprop("/systems/electrical/battery-volts-"~x, me.volts());
    setprop("/systems/electrical/battery-amps-"~x, me.amps());
    return me.amp_hours * new_charge_percent;
}

##
# Return output volts based on percent charged.  Currently based on a simple
# polynomial percent charge vs. volts function.
#
Battery.volts = func {
    if (! getprop( me.switch )) {
        return 0;
    }
    var x = 1.0 - me.charge_percent;
    var tmp = -(3.0 * x - 1.0);
    var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_volts * factor;
}


##
# Return output amps available.  This function is totally wrong and should be
# fixed at some point with a more sensible function based on charge percent.
# There is probably some physical limits to the number of instantaneous amps
# a battery can produce (cold cranking amps?)
#
Battery.amps = func {
    if (! getprop( me.switch )) {
        return 0;
    }
    
    var x = 1.0 - me.charge_percent;
    var tmp = -(3.0 * x - 1.0);
    var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    return me.ideal_amps * factor;
}

##
# Set the current charge instantly to 100 %.
#
Battery.reset_to_full_charge = func (x) {
    me.apply_load(-(1.0 - me.charge_percent) * me.amp_hours, 3600, x);
}

##
# Alternator model class.
#

var Alternator = {};

Alternator.new = func (switch,source,volts,amps,rpm_threshold=800){
    var obj = { parents : [Alternator],
                switch: switch,
                rpm_source : source,
                rpm_threshold : rpm_threshold,
                ideal_volts : volts,
                ideal_amps : amps };
    if (obj.rpm_source) {
        setprop( obj.rpm_source, 0.0 );
    }
    return obj;
}

##
# Scale alternator output for rpms < 800.  For rpms >= 800
# give full output.  This is just a WAG, and probably not how
# it really works but I'm keeping things "simple" to start.   
Alternator.get_factor = func {
    # If alternator switch is off, you no get no juice from this puppy..
    if (! getprop( me.switch )) {
        return 0;
    }
    if (! me.rpm_source) {
        # No factor. Could be an external source.
        return 1.0;
    }
    var rpm = getprop( me.rpm_source );
    var factor = rpm / me.rpm_threshold;
    if ( factor > 1.0 ) {
        factor = 1.0;
    }
    return factor;
}

##
# Computes available amps and returns remaining amps after load is applied
#
Alternator.apply_load = func( amps, dt ) {    
    # print( "alternator amps = ", me.ideal_amps * factor );
    var available_amps = me.ideal_amps * me.get_factor();
    return available_amps - amps;
}

##
# Return output volts based on rpm
#
Alternator.volts = func {
    return me.ideal_volts * me.get_factor();
}

##
# Return output amps available based on rpm.
#
Alternator.amps = func {
    return me.ideal_amps * me.get_factor();
}


var Bus = {};

Bus.new = func (name, switch){
    var obj = { parents : [Bus],
                name: name,
                breaker : "/controls/circuit-breakers/bus-"~name,
                switch : switch,
                output : "/systems/electrical/outputs/bus-"~name,
                loads : [],
                volts : 0.0,
                amps : 0.0 };
    setprop( obj.breaker, 1 );
    setprop( obj.output, 0.0 );
    return obj;
}
Bus.add_load = func(load) {
    append(me.loads,load);
}
Bus.get_load = func(volts) {
    var bus_load = 0.0;
    var v = 0.0;
    if (getprop(me.switch) and getprop(me.breaker)) {
        v = volts;
    }
    foreach(var load; me.loads) {
        bus_load += load.get_load(v);
    }
    setprop(me.output, v);
    
    return bus_load;
}

var Load = {};
Load.new = func (name, amps, switch) {
    var obj = { parents : [Load],
                name : name,
                breaker : "/controls/circuit-breakers/"~name,
                switch : switch,
                output : "/systems/electrical/outputs/"~name,
                amps : amps };
    setprop( obj.breaker, 1 );
    setprop( obj.output, 0.0 );
    return obj;
}
Load.get_load = func(volts) {
    var load = 0.0;
    # switch could be a potentiometer (ie: a light dimmer)
    var factor = getprop(me.switch);
    if (volts and factor and getprop(me.breaker) ) {
        setprop(me.output, volts*factor);
        load = me.amps * volts * factor;
    } else {
        setprop(me.output, 0.0);
    }
    return load;
}