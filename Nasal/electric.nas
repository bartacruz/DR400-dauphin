
var setpropr = func(dec,path,val) {
    var mult = math.pow(10,dec);
    var val_r = int(val * mult) / mult;
    setprop(path,val_r);
}

var Class ={class_name: "Class"};
Class.new = func(name) {
    var obj = {
        parents:[Class],
        name:name,
        is_instance: func(class) {
            foreach(var c; me.parents) {
                if (c.class_name == class.class_name) return true;
            }
            return false;
        },
    }
};
Class.names = func(v) {
    var ret = [];
    foreach(var c;v) append(ret,c.name);
    return ret;
}

    # 
var Source ={class_name: "Source",};
Source.new = func(name) {
    var obj= {
        parents: [Source,Class.new(name)],
        loads:[],
        get_node: func { return "/systems/electrical/sources/"~me.name~"/" },
        get_prop: func(prop) { return getprop(me.get_node()~prop); },
        set_prop: func(prop,val) { setprop(me.get_node()~prop,val);},
        add_load: func(load) {
            append(me.loads,load);
            return load;
        },
    };
    return obj;
};



##
# Battery model class.
#

var Battery = {class_name: "Battery"};


##
# 
Battery.new = func (name, switch, volts,amps,cc_amps, charge_amps=nil, charge_percent=0) {
    var obj = { parents : [Battery,Source.new(name)],
      switch: switch,
      ideal_volts : volts,
      ideal_amps : amps,
      cc_amps: cc_amps,
      charge_amps: charge_amps or amps*0.3,
    };
    obj.charge_percent= charge_percent or obj.get_prop("charge-percent") or 1.0;
    obj.set_prop("charge-percent",obj.charge_percent);
    obj.set_prop("volts",obj.volts());
    obj.set_prop("amps", obj.amps());
    return obj;
}

##
# Passing in positive amps means the battery will be discharged.
# Negative amps indicates a battery charge.
# return 
#    >0 means it didn't fulfill the load.
#    < 0 means it has power left to charge batteries

Battery.apply_load = func(amps, dt) {
    if (getprop("/sim/freeze/replay-state"))
        return me.ideal_amps * me.charge_percent;
    load_amps = amps;
    if (amps < 0 ) {
        load_amps = me.charge_amps;
        me.set_prop("charging", load_amps);
    }
    var amps_used = load_amps * dt / 3600.0;
    var percent_used = amps_used / me.ideal_amps;

    var new_charge_percent = std.max(0.0, std.min(me.charge_percent - percent_used, 1.0));

    if (new_charge_percent < 0.1 and me.charge_percent >= 0.1)
        gui.popupTip("Warning: Low battery! Enable alternator or apply external power to recharge battery!", 10);
    me.charge_percent = new_charge_percent;
    me.set_prop("charge-percent",me.charge_percent);
    me.set_prop("volts",me.volts());
    me.set_prop("amps", me.amps());
    
    if (load_amps < 0) {
        return load_amps - amps;
    } 
    return load_amps - me.amps();
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
    
    # var x = 1.0 - me.charge_percent;
    # var tmp = -(3.0 * x - 1.0);
    # var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
    # return me.ideal_amps * factor;
    return me.ideal_amps * me.charge_percent;
}

##
# Set the current charge instantly to 100 %.
#
Battery.reset_to_full_charge = func  {
    me.apply_load(-(1.0 - me.charge_percent) * me.ideal_amps, 3600);
}

##
# Alternator model class.
#

var Alternator = {class_name:"Alternator"};

Alternator.new = func (name,switch,source,volts,amps,rpm_threshold=800){
    var obj = { parents : [Alternator,Source.new(name)],
                switch: switch,
                rpm_source : source,
                rpm_threshold : rpm_threshold,
                ideal_volts : volts,
                ideal_amps : amps,
    };
    
    if (obj.rpm_source) {
        setprop( obj.rpm_source, 0.0 );
    }
    obj.set_prop("volts",obj.volts());
    obj.set_prop("amps", obj.amps());
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
    var available_amps = me.amps();
    me.set_prop("volts",me.volts());
    me.set_prop("amps", available_amps);
    return amps - available_amps;
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


var Bus = {class_name: "Bus"};

Bus.new = func (name, switch){
    var obj = { parents : [Bus, Source.new(name)],
                get_node: func { return "/systems/electrical/buses/"~me.name~"/" },
                switch : switch,
                sources : [],
    };
    obj.set_prop("volts",0.0 );
    obj.set_prop("amps",0.0 );
    return obj;
}
Bus.add_source = func(source) {
    append(me.sources,source);
    return source;
}

Bus.clear = func() {
    me.loads = [];
    me.sources = [];
}

Bus.volts = func() {
    var v = 0;
    if (size(me.sources) > 0){
        var sources = sort (me.sources, func (a,b) a.volts() < b.volts());
        var v = sources[0].volts();
    } 
    me.set_prop("sources",size(me.sources) );
    return 0;
}

Bus.amps = func() {
    var amps = 0;
    foreach(var source; me.sources){
        amps += source.amps();
    }
    return amps;
}

Bus.get_load = func(volts) {
    var bus_load = 0.0;
    var v = 0.0;
    if (me.switch == nil or getprop(me.switch)) {
        v = volts;
    }
    foreach(var load; me.loads) {
        bus_load += load.get_load(v);
    }
    me.set_prop("volts",v);
    me.set_prop("amps",bus_load);
    return bus_load;
}

var Load = {class_name:"Load"};
Load.new = func (name, amps, switch) {
    var obj = { parents : [Load, Class.new(name)],
                switch : switch,
                output: "/systems/electrical/outputs/"~name,
                amps:amps,
                sources:[] };
    setprop( obj.output, 0.0 );
    return obj;
}
Load.add_source = func(source) {
    append(me.sources,source);
    return source;
}

# Can be overwritten by subclasses or instances to accomodate variable loads.
# ie: panel lights, ignition coil, etc.
Load.get_volts = func(volts) {
    # switch could be a potentiometer (ie: a light dimmer)
    var switch = getprop(me.switch);
    if (switch == nil or switch == false) {
        switch = 0;
    }
    return  switch * volts;
}
Load.get_amps = func(volts) {
    return me.amps;
}

Load.get_load = func(volts) {
    var load = 0.0;
    var v = me.get_volts(volts);
    var a = me.get_amps(v);
    if (v and a ) {
        setpropr(5,me.output, v);
        load = a;
    } else {
        setpropr(5,me.output, 0.0);
    }
    # setpropr(5,me.draw, load);
    return load;
}

##
# Breaker.
# Basically, a bus that can pop..
#
var Breaker = {class_name: "Breaker"};
Breaker.new = func (name, amps, path=nil, output=nil) {
    var obj = { parents : [Breaker,Bus.new(name,nil)],
                get_node: func { return "/systems/electrical/breakers/"~me.name~"/" },
                path : path or "/controls/circuit-breakers/"~name,
                output: output,
                amps_burn: amps,
    };
    setprop( obj.path, 1 );
    obj.set_prop("volts",0.0 );
    obj.set_prop("amps",0.0 );
    obj.set_prop("amps_burn",obj.amps_burn );
    if (obj.output) setprop( obj.output, 0.0 );
    return obj;
}

Breaker.get_load = func(volts) {
    if (!getprop(me.path)) {
        #we're popped. No volts through this puppy...
        volts = 0;
    }
    # call super (Bus.get_load)
    var bus_load = me.parents[1].get_load(volts);
    # check load current
    if (bus_load  > me.amps_burn * 1.1) {
        # Load exceded. Pop breaker.
        print(sprintf("### Circuit-breaker %s popped! %f > %f", me.name, bus_load, me.amps_burn ));
        me.pop();
        volts = 0;
        bus_load = 0.0;
        
    }
    if (me.output) setprop( obj.output, v );
    me.set_prop("volts",volts);
    me.set_prop("amps",bus_load);
    return bus_load;
}
Breaker.pop = func {
    setprop(me.path,0);
}
Breaker.reset = func {
    setprop(me.path,1);
}


var Light = {class_name:"Light"};
Light.new = func (name, amps, switch=nil) {
    var obj = { 
        parents : [Light, Load.new(name,amps,switch)],
        switch : switch or "/controls/lighting/" ~ name,
    };
    return obj;
};

System = {};

##
# Initializes a new electric system.
System.new = func(name, path="/systems/electrical/") {
    var obj = {
        parents: [System,Class.new(name)],
        path: path,
        sources:{},
        buses: [],
        loads: {},
    };
    obj.loop = updateloop.UpdateLoop.new(components: [obj], update_period: 0.0, enable: 0);
    return obj;
}
System.connect = func(source,load) {
    source.add_load(load);
    load.add_source(source);
    if (! source.is_instance(Breaker)) {
        me.sources[source.name]= source;
        print("Adding " ~ source.name ~ "as a source");
    }  else {
        print("Ignorign breaker " ~ source.name ~ " as a source");
    }
    me.loads[load.name]= load;
    return load;
}

# UpdateLoop methods
System.enable = func {
    me.loop.reset();
    me.loop.enable();
};
System.disable = func {
    me.loop.disable();
};
System.reset = func {};
System.update = func(dt){
    var serviceable = getprop(me.path ~ "serviceable");
    foreach (var source; values(me.sources)) {
        if (source.volts() <=0 ) continue;
        var load_amps = 0.0;
        load_buses = [];
        foreach (var load;source.loads){
            if (!contains(load_buses,load)) append(load_buses,load);
        }
        
        foreach (var bus; load_buses){
            # Bus sources sorted by volts.
            var sources = sort (bus.sources, func (a,b) a.volts() < b.volts());
            var batteries=[];
            var sources_volts = sources[0].volts();
            var load_amps = bus.get_load(sources_volts);
            var remaining_amps=0.0;
            foreach (var source; sources) {
                if (source.volts() > 0) {
                    if (remaining_amps < 0 and source.is_instance(Battery)) {
                        # charge battery!
                        remaining_amps= source.apply_load( remaining_amps, dt);
                    } else {
                        # apply load to the source and get remaining amps.
                        # remaing >0 means it didn't fulfill the load.
                        # remaining < 0 means it has power left to charge batteries.
                        remaining_amps= source.apply_load( load_amps, dt);
                        load_amps = math.max(0,remaining_amps);
                        
                    } 
                } else break;
            }
        }

    }
};
