
# Write the airplane state to file and resume
# 
# by Julio Santa Cruz (Barta) 2025.
#

var location_props = [
    "/position/latitude-deg",
    "/position/longitude-deg",
    "/position/altitude-ft",
    "/orientation/heading-deg",
    "/orientation/pitch-deg",
    "/orientation/roll-deg",
    "/velocities/uBody-fps",
    "/velocities/vBody-fps",
    "/velocities/wBody-fps",
];
var fuel_props = [
    "/consumables/fuel/tank[0]/selected",
    "/consumables/fuel/tank[0]/level-lbs",
    "/consumables/fuel/tank[1]/selected",
    "/consumables/fuel/tank[1]/level-lbs",
    "/consumables/fuel/tank[2]/selected",
    "/consumables/fuel/tank[2]/level-lbs",
    "/controls/fuel/selected-tank",
    "/controls/fuel/selected-tank-pos",
];
var electric_props = [
    "/controls/electric/battery-switch",
    "/controls/electric/external-power",
    "/controls/engines/engine/master-alt",
    "/controls/switches/master-avionics",
    "/controls/lighting/instruments-norm",
    "/controls/lighting/instruments-norm[1]",
    "/controls/lighting/instruments-norm[2]",
    "/controls/lighting/landing-lights",
    "/controls/lighting/nav-lights",
    "/controls/lighting/strobe-lights",
    "/controls/lighting/taxi-lights",
];
var engine_props = [

];
var save_props = location_props
                    ~ fuel_props
                    ~ electric_props
                    ;
var save_state = func {
    var running = getprop("/engines/active-engine/running");
    var moving = getprop("/velocities/groundspeed-kt");
    var pitch = getprop("/orientation/pitch-deg");
    var roll = getprop("/orientation/roll-deg");

    if (running) {
        gui.popupTip("Engine must be turned off to save state!", 5.0);
        return;
    }
    if (moving > 7 or moving < -7) {
        gui.popupTip("Aircraft cannot be moving to save state!", 5.0);
        return;
    }
    if (pitch > 7 or roll > 7) {
        gui.popupTip("Slope too steep to save state!", 5.0);
        return;
    }
    
    foreach (var path; save_props) {
        var v = getprop(path);
        print(path,v);
        setprop("/save" ~ path,v );
    }
    # Special cases

    # battery
    setprop("/save/systems/electrical/sources/battery/set-charge-percent", getprop("/systems/electrical/sources/battery/charge-percent"));

    var timestring = getprop("/sim/time/real/year");
    timestring = timestring~ "-"~getprop("/sim/time/real/month");
    timestring = timestring~ "-"~getprop("/sim/time/real/day");
    timestring = timestring~ "-"~getprop("/sim/time/real/hour");

    var minute = getprop("/sim/time/real/minute");
    if (minute < 10) {minute = "0"~minute;}
    timestring = timestring~ ":"~minute;
    var aircraft = getprop("/sim/aircraft");
    var description = aircraft ~ " saved state";

    setprop("/save/description", description);
    setprop("/save/timestring", timestring);

    # save state to specified file

    #var filename = getprop("/sim/gui/dialogs/c172p/save/filename");
    var filename = aircraft ~ "-save.xml";
    var path = getprop("/sim/fg-home") ~ "/aircraft-data/"~filename;
    var nodeSave = props.globals.getNode("/save", 0);
    io.write_properties(path, nodeSave);

    print("Current state written to ", filename, " !");
}
var read_state = func {
    var aircraft = getprop("/sim/aircraft");
    var filename = aircraft ~ "-save.xml";
    var path = getprop("/sim/fg-home") ~ "/aircraft-data/"~filename;
    var readNode = props.globals.getNode("/save", 0);
    io.read_properties(path, readNode);
    
    
    foreach (var path; save_props) {
        setprop(path,getprop("/save"~path));
    }
    fgcommand("reposition");
    print("State restored from ", filename, " !");
}

var show_save_dialog = func {
    var MARGIN = 12;
    var dlg = canvas.Window.new([300,120], "dialog")
                           .setTitle("Save/Restore");
    var root = dlg.getCanvas(1)
                  .set("background", canvas.style.getColor("bg_color"))
                  .createGroup();
    var vbox = canvas.VBoxLayout.new();
    vbox.setContentsMargin(MARGIN);
    dlg.setLayout(vbox);

    vbox.addItem(
      canvas.gui.widgets.Label.new(root, canvas.style, {wordWrap: 1})
                       .setText("Save or restore aircraft state to/from file.")
    );
    
    var button_box = canvas.HBoxLayout.new();
    vbox.addItem(button_box);
    button_box.addStretch(1);
    button_box.addItem(
        canvas.gui.widgets.Button.new(root, canvas.style, {})
        .setText("Save")
        .listen("clicked", func {
            dlg.del();
            dr400.save_state();
        })
    );
    button_box.addItem(
        canvas.gui.widgets.Button.new(root, canvas.style, {})
        .setText("Restore")
        .listen("clicked", func {
            dlg.del();
            dr400.restore_state();
        })
    );
    button_box.addStretch(1);
}
