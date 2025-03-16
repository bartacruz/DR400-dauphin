systems ={};

var charge_battery_cb= func(node) {
    var s = split("/",node.getPath());
    var bn = s[-2];
    var charge_percent = node.getDoubleValue();
    if (charge_percent < 0 or charge_percent > 1) return;
    foreach (var system; values(systems)) {
        if (find(system.path,node.getPath()) < 0) continue;
        foreach(var source;system.sources){
            if (source.is_instance(Battery) and source.name == bn){
                printf("setting charge of %s from %f to %f", source.id(),source.charge_percent,charge_percent);
                source.set_charge_percent(charge_percent);
            }
        }
    }
};

var setpropr = func(dec,path,val) {
    var mult = math.pow(10,dec);
    var val_r = int(val * mult) / mult;
    setprop(path,val_r);
}


var Class= {
    class_name: "Class",
    
    new: func(name) {
        var obj = {
            parents:[Class],
            name:name,
            sources:[],
            loads: [],
            voltage:0,
            current:0,
            path: nil, # sublcasses must declare.
            system:nil,
        };
        obj.publish();
        return obj;

    },
    id: func {
        return me.class_name~":"~me.name;
    },
    add_source: func(source){
        if (!contains(me.sources,source))
            append(me.sources,source);
        return source;
    },
    # Get sources sorted by bigger voltage.
    get_sources: func {
        return sort (me.sources, func (a,b) a.get_volts() < b.get_volts());
    },
    add_load: func(load) {
        append(me.loads,load);
        return load;
    },
    get_prop: func(prop, obj = nil) { 
        obj = obj or me;
        if (obj.path)
            return getprop(obj.path ~ obj.name ~ "/" ~ prop);
        return nil;
    },
    set_prop: func(prop,val, obj=nil) { 
        obj = obj or me;
        if (obj.path)
            setprop(obj.path ~ obj.name ~ "/" ~ prop,val);
    },
    is_instance: func(class) {
        var find_parent = func(o,class){                
            if (o.class_name == class.class_name) return true;
            if (size(o.parents) > 1){
                for (var i=1; i<size(o.parents) ; i+=1) {
                    return find_parent(o.parents[i],class);
                }
            }
            return false;
        }
        return find_parent(me,class);
    },
    super: func(class,method) {
        var fun = sprintf("%s.%s",class.class_name,method);
        var fn = compile(fun);
        var ret = call(fn(),arg,me);
        return ret;
    },

    reset: func {
        me.voltage=0;
        me.current=0;
    },
    publish: func(obj=nil) {
        obj = obj or me;
        me.set_prop("voltage",me.voltage);
        me.set_prop("current",me.current);
    },
    str: func(){
        return sprintf("[%s %.4fV %.4fA]",me.id(),me.voltage,me.current);
    },
};
Class.ids = func(v) {
    var ret = [];
    foreach(var c;v) append(ret,c.id());
    return debug.string(ret);
}
Class.labels=func(v) {
    var ret = [];
    foreach(var c;v) append(ret,c.str());
    return debug.string(ret);
}
Class.names = func(v) {
    var ret = [];
    foreach(var c;v) append(ret,c.name);
    return ret;
}
Class.names_str = func(v) {
    return debug.string(Class.names(v));
}

var Source = {
    class_name: "Source",
    new: func(name) {
        var obj= {
            parents: [Source,Class.new(name)],
            path: "/systems/electrical/sources/",
        };
        return obj;
    },
};

var Load = {
    class_name: "Load",
    new: func (name, amps, switch) {
        var obj = { 
            parents : [Load, Class.new(name)],
            switch: switch,
            amps:amps,
            path: "/systems/electrical/loads/",
            output: "/systems/electrical/outputs/",
        };
        obj.path = "/systems/electrical/loads/";
        obj.publish();
        return obj;
    },
    publish: func{
        me.super(Class, "publish");
        if (me.output){
            setpropr(5,me.output~me.name, me.voltage);
        }

    },
    # Can be overwritten by subclasses or instances to accomodate variable loads.
    # ie: panel lights, ignition coil, etc.
    get_volts: func(volts) {
        # switch could be a potentiometer (ie: a light dimmer)
        var switch = getprop(me.switch);
        if (switch == nil or switch == false) {
            switch = 0;
        }
        return  switch * volts;
    },
    get_amps: func(volts=nil) {
        return me.amps;
    },
    get_load: func(volts,dt) {
        var v = me.get_volts(volts);
        var a = me.get_amps(v);
        if (v and a ) {
            me.voltage = v;
            me.current = a;
        } else {
            me.voltage = 0.0;
            me.current = 0.0;
        }
        #printf("%s %s volts=%s voltage=%s current=%s", me.class_name,me.name,volts,me.voltage,me.current);
        return me.current;
    }
};

var Light = {
    class_name:"Light",
    new: func (name, amps, switch=nil) {
        var obj = { 
            parents : [Light, Load.new(name,amps,switch)],
            switch : switch or "/controls/lighting/" ~ name,
        };
        return obj;
    }
};

var Wire = {
    class_name: "Wire",
    new: func(name) {
        var obj = { 
            parents : [Wire, Class.new(name)],
        };
        return obj;
    },
    # Between 0-1
    get_factor: func(volts) {
        return 1;
    },
    get_load: func(volts,dt) {
        var current=0;
        volts = volts * me.get_factor(volts);
        me.voltage = volts;
        foreach(var load; me.loads) {
            # Apply current to load only if our voltage is greater.
            if (load.voltage < volts) 
                current += load.get_load(volts,dt);
            # else
            #     printf("Ignoring bigger load %s < %s",me.str(), load.str());
        }
        #printf("\t%s %s get_load(%s) = %s | %s", me.class_name,me.name,volts,current,me.names_str(me.loads));
        me.current = current;
        
        return current;
    },
    get_volts: func {
        # var sources = sort (bus.sources, func (a,b) a.get_volts() < b.get_volts());
        # return sources[0].get_volts();
        # Mmmmm....
        return me.voltage;
    },
    apply_load: func(load,dt) {
        if (me.get_factor(me.voltage) > 0)
            return me.get_sources()[0].apply_load(load,dt);
        return 0;
    }
};

# A special kind of wire that publishes it's output.
var Bus = {
    class_name: "Bus",
    new: func(name, output=nil){
        var obj = { 
            parents : [Bus, Wire.new(name)],
            output: output or "/systems/electrical/outputs/",
        };
        obj.publish();
        return obj;
    },
    publish: func{
        me.super(Class,"publish");
        if (me.output){
            setpropr(5,me.output~me.name, me.voltage);
        }
    },
};
var Switch = {
    class_name: "Switch",
    new: func(name,switch=nil) {
        var obj = { 
            parents : [Switch, Wire.new(name)],
            switch: switch or "/controls/switches/" ~ name,
        };
        return obj;
    },
    get_factor: func(volts) {
        var switch = me.switch ? getprop(me.switch) : 1;
        return switch;
    },
    
};
var Breaker = {
    class_name: "Breaker",
    new: func(name,amps, control="/controls/circuit-breakers/") {
        var obj = { 
            parents : [Breaker, Wire.new(name)],
            amps:amps,
            state: control~name,
        };
        obj.set_state(1);
        return obj;
    },
    
    get_state: func return getprop(me.state),
    
    set_state: func(state) setprop(me.state,state),
    get_factor: func(volts) {
        return me.get_state();
    },
    get_load: func(volts,dt){
        if (!me.get_state()){
            me.current =0;
            me.voltage = 0;
        } else {
            me.current = me.super(Wire,"get_load",volts,dt);
            #printf("Breaker %s current=%s amps=%s", me.name,me.current,me.amps);
            if (me.current > me.amps *1.1) {
                print(sprintf("### Circuit-breaker %s popped! %f > %f", me.name, me.current, me.amps ));
                me.set_state(1);
            }
        }
        return me.current;
    },
};

##
# Battery model class.
#

var Battery = {
    class_name: "Battery",
    new: func (name, volts,amps,cc_amps, charge_amps=nil, charge_percent=0) {
        var obj = { parents : [Battery,Source.new(name)],
            volts : volts,
            amps : amps,
            cc_amps: cc_amps,
            charge_amps: charge_amps or amps*0.3,
        };
        obj.charge_percent= charge_percent or obj.get_prop("charge-percent") or 1.0;
        # obj.set_prop("set-charge-percent",nil);
        setlistener(obj.path ~ obj.name~"/set-charge-percent", charge_battery_cb ,0,0);
        return obj;
    },
    publish: func() {
        me.super(Class,"publish");
        me.set_prop("charge-percent",me.charge_percent);    
        me.set_prop("amps", me.get_amps());
    },
    
    ##
    # Return output volts based on percent charged.  Currently based on a simple
    # polynomial percent charge vs. volts function.
    #
    get_volts: func {
        var x = 1.0 - me.charge_percent;
        var tmp = -(3.0 * x - 1.0);
        
        var factor = (tmp*tmp*tmp*tmp*tmp + 32) / 32;
        return me.volts * factor;
    },
    get_amps: func {
        return me.amps * me.charge_percent;
    },
    get_cc_amps: func {
        return me.cc_amps * me.charge_percent;
    },
    apply_load: func(amps, dt) {
        if (getprop("/sim/freeze/replay-state"))
            return me.get_cc_amps();
        var load_amps = math.min(amps,me.get_cc_amps());
        var amps_used = load_amps * dt / 3600.0;
        var percent_used = amps_used / me.amps;
        me.charge_percent = std.max(0.0, me.charge_percent - percent_used);
        me.voltage = me.get_volts();
        me.current = load_amps;
        return  amps - me.get_cc_amps();
    },
    get_load: func(volts,dt) {
        if (volts <= me.get_volts()) {
            return 0;
        }
        # TODO: factorize charge_amps using voltage difference with source.
        var amps_used = me.charge_amps * dt / 3600.0;
        var percent_used = amps_used / me.amps;
        me.charge_percent = std.min(me.charge_percent + percent_used, 1.0);
        me.voltage = me.get_volts();
        me.current = -1* me.charge_amps;
        return me.charge_amps;
    },
    set_charge_percent: func(charge_percent) {
        if (me.system.loop.enabled) {
            # avoid our value being overwritten by the update process.
            me.system.loop.disable();
            me.charge_percent = charge_percent;
            me.system.loop.enable();
        } else {
            me.charge_percent = charge_percent;
        }
    }
};

##
# Alternator model class.
#

var Alternator = {
    class_name: "Alternator",
    new: func (name,source,volts,amps,rpm_threshold=800){    
        var obj = { 
            parents : [Alternator,Source.new(name)],
                rpm_source : source,
                rpm_threshold : rpm_threshold,
                volts : volts,
                amps : amps,
        };      
        if (obj.rpm_source) {
            setprop( obj.rpm_source, 0.0 );
        }
        return obj;
    },
    ##
    # Scale alternator output for rpms < 800.  For rpms >= 800
    # give full output.  This is just a WAG, and probably not how
    # it really works but I'm keeping things "simple" to start.   
    get_factor: func {
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
    },
    ##
    # Return output volts based on rpm
    #
    get_volts: func {
        return me.volts * me.get_factor();
    },

    ##
    # Return output amps available based on rpm.
    #
    get_amps: func {
        return me.amps * me.get_factor();
    },
    apply_load: func( amps, dt ) {  
        # print( "alternator amps = ", me.amps * factor );
        var available_amps = me.get_amps();
        me.current = math.min(available_amps,amps);
        me.voltage = me.get_volts();
        return amps - available_amps;
    },
};

##
# Initializes a new electric system.
var System = {
    new: func(name, update_period=0.1,path="/systems/electrical/") {
        var obj = {
            parents: [System,Class.new(name)],
            path: path,
            buses: [],
            loads: {},
        };
        obj.loop = updateloop.UpdateLoop.new(components: [obj], update_period: update_period, enable: 0);
        systems[name] = obj;
        return obj;
    },
    ###
    # Connects 2 or more elements
    #
    # To create a 15A landing light and hook it to the main bus via a 20A breaker:
    # main_bus = electric.Wire.new("main", etc-);
    # electric.system.connect(main_bus, Breaker.new("landing-light",20), Light.new("landing-light",15));
    ###
    connect: func {
        var load = nil;
        var source = nil;
        for (var i=0; i< size(arg)-1 ; i=i+1) {
            source = arg[i] or source;
            load = arg[i+1];

            if (!source or ! load) continue;

            # add a reference to the system they are connected (myself)
            source.system = me;
            load.system = me;

            source.add_load(load);
            load.add_source(source);
            if (source.is_instance(Source)) {
                me.add_source(source); 
            }  
            me.loads[load.id()]= load;
        }
        return load;
    },

    add_light: func(source, name, amps, breaker_amps=0) {
        var light = Light.new(name,amps);
        if (breaker_amps){
            me.connect(source,Breaker.new(name,breaker_amps),);
        } else {
            me.connect(source,Light.new(name,amps));
        }
    },
    
    # UpdateLoop methods
    enable: func {
        me.loop.reset();
        me.loop.enable();
    },
    disable: func {
        me.loop.disable();
    },
    reset: func {},

    update: func(dt){
        var start = systime();
        var serviceable = getprop(me.path ~ "serviceable");
        foreach(var load; values(me.loads)){
            load.reset();
        }
        var load_buses = [];
        foreach (var source; me.get_sources()) {
            source.reset();
            if (source.get_volts() <=0 ) continue;
            foreach (var load;source.loads){
                if (!contains(load_buses,load)) append(load_buses,load);
            }
        }
        #print("load_buses ", Class.labels(load_buses));
        foreach (var bus; load_buses){
            if (bus.voltage) {
                # Already visited
                continue;
            }
            # Bus sources sorted by volts.
            var sources = bus.get_sources();
            var sources_volts = sources[0].get_volts();

            # Traverse the bus loads gathering current.
            var load_amps = bus.get_load(sources_volts,dt);
            #printf("%s (from %s) %sV %sA s=%s",bus.str(), sources[0].str(), sources_volts, load_amps, Class.ids(sources));
            # Draw the current from the sources.
            var remaining_amps=load_amps;
            foreach (var source; sources) {
                if (source.get_volts() > 0) {
                        # apply load to the source and get remaining amps.
                        # remaing > 0 means it didn't fulfill the load.
                        # remaining < 0 means it has power left to charge batteries.

                        remaining_amps= source.apply_load( remaining_amps, dt);
                        if (remaining_amps <=0) break;
                } else {
                    break;
                }
            }
        }
        foreach(var load; values(me.loads)){
            load.publish();
        }
        foreach(var source; me.sources){
            source.publish();
        }
        var end = systime();
        #setprop(me.path~"/update",end-start);
    }
};
