# var aircraft_dir = getprop("/sim/aircraft-dir");
# io.load_nasal(aircraft_dir ~ "/Nasal/tstCircuit.nas","circuit");

# var circuit = ElectricCircuit.CircuitCore.new();
# var batt = circuit.add_battery("batt",24,"battpos","battneg");
# #var batt2 = circuit.add_battery("batt2",24,"battpos","battneg");

# circuit.add_wire("mains","battpos","main_bus");
# circuit.add_wire("chasis","battneg","ground");
# circuit.add_resistor("fuel-pump",4.8,"main_bus","ground");
# circuit.add_resistor("annunciators",80,"main_bus","ground");
# circuit.add_wire("avionics",80,"main_bus","avionics_bus");
# circuit.add_resistor("gps",80,"avionics_bus","ground");
# circuit.add_resistor("adf",80,"avionics_bus","ground");

# #circuit.add_wire(
# circuit.print_elements();
# circuit.solve();
# circuit.print_elements();


# var aircraft_dir = getprop("/sim/aircraft-dir");
# io.load_nasal(aircraft_dir ~ "/Nasal/Electric.nas","Electric");

# var battery = Electric.Battery.new("battery","/controls/electric/battery-switch",12,32.0,240,1);

# var alternator = Electric.Alternator.new("alternator","/controls/engines/engine[0]/master-alt","/engines/engine[0]/rpm",14.0,50.0);
# var main_bus = Electric.Bus.new("main2", "/systems/electrical/serviceable");
# var avionics_bus = Electric.Bus.new("avionics2","controls/switches/master-avionics" );

# Electric.connect(battery,main_bus);
# Electric.connect(alternator,main_bus);
# Electric.connect(main_bus,avionics_bus);

# Electric.connect(main_bus,Electric.Load.new("carb-heat2",0.01,"/controls/anti-ice/engine/carb-heat"));
# Electric.connect(main_bus,Electric.Load.new("fuel-pump2",5.0,"/controls/fuel/tank/boost-pump"));


# Electric.connect(avionics_bus,Electric.Load.new("turn-coordinator2",.0,"controls/switches/master-avionics"));

# print("main bus ",main_bus.volts()," ",main_bus.amps());
# var tst = func(a=0,b=false) {
#     print("tst",a,b,"\n");
# }
# tst(1,true);
# tst(b:1234);

var Class ={class_name: "Class"};
Class.new = func() {
    var obj = {
        parents:[Class],
        c: "fas",
        is_instance: func(class) {
            foreach(var c; me.parents) {
                if (c.class_name == class.class_name) return true;
            }
            return false;
        },
        del: func{print("Borro class","\n")},
    }
};

var C1 = {class_name: "C1"};
C1.new = func(a) {
    var obj = {
        parents:[C1, Class.new()],
        a:a
    };
    return obj;
}
c1 = C1.new("A1");
c1.del();
c1._del = c1.del;
c1.del = func{
    print("Borro C1","\n");
    me._del();
}
c1.del();
# print("contains a: ", contains(c1,'a'),"\n");
# print("contains c: ", contains(c1,'c'),"\n");
# print(sprintf("%.1f",0));
# var f = [1,2];
# var j = [3,4];
# var i = f~j;
# print("len",size(i));
# var C2 = {class_name: "C2"};
# C2.new = func(a,b) {
#     var obj = {parents:[C2,C1.new(a)],b:b};
#     return obj;
# }

# c2 = C2.new("A2","B2");
# print("c1 C1? ", c1.is_instance(C1),"\n");
# print("c1 C2? ", c1.is_instance(C2),"\n");
# print("c2 C1? ", c2.is_instance(C1),"\n");
# print("c2 C2? ", c2.is_instance(C2),"\n");

#debug.dump("C2",c2.a,c2.b);

