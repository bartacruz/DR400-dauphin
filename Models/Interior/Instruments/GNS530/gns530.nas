# Copyright 2020 Julio Santa Cruz (Barta)
#
# This program is free software: you can redistribute it and/or modify 
# it under the terms of the GNU General Public License as published by 
# the Free Software Foundation, either version 3 of the License, or 
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# GNS530 - FG1000 implementation

var nasal_dir = getprop("/sim/fg-root") ~ "/Aircraft/Instruments-3d/FG1000/Nasal/";
var aircraft_dir = getprop("/sim/aircraft-dir");
var power_listener = nil;
var gns530_dir = aircraft_dir ~ '/Models/Interior/Instruments/GNS530/';
var fg1000system = dr400.fg1000system;

var load_gns530 = func() {
	
	io.load_nasal(nasal_dir ~ 'FG1000.nas', "fg1000");
	io.load_nasal(gns530_dir ~ 'Constants.nas', "fg1000");
	io.load_nasal(gns530_dir ~ 'MFDPageController.nas', "fg1000");
	io.load_nasal(gns530_dir ~ 'Interfaces/GNS530InterfaceController.nas', "fg1000");
	io.load_nasal(gns530_dir ~ 'GNS530D.nas', "fg1000");

	# Load the custom controller
	var interfaceController = fg1000.GNS530InterfaceController.getOrCreateInstance();

	interfaceController.start();

	var EIS ={engineMenu:"",systemMenu:""}; # Empty EIS to fool FG1000
	var svg_path = gns530_dir ~ 'SVG/';
	fg1000system = fg1000.FG1000.getOrCreateInstance(EIS, nil, svg_path);

	# Overide Surround controller
	io.load_nasal(gns530_dir ~ 'SelectableElement.nas', "fg1000");
	io.load_nasal(gns530_dir ~ 'MDFPages/Surround/SurroundController.nas', "fg1000");
	io.load_nasal(gns530_dir ~ 'MDFPages/Surround/Surround.nas', "fg1000");

	var targetcanvas = canvas.new({
	"name" : "MFD Canvas",
	"size" : [1024, 768],
	"view" : [1024, 768],
	"mipmapping": 0,
	});

	targetcanvas.set("visible", 0);

	var mfd = fg1000.GNS530Display.new(fg1000system, fg1000system.EIS_Class, fg1000system.EIS_SVG, fg1000system.SVG_Path, targetcanvas, 1);
	fg1000system.displays[1] = mfd;
	fg1000system.display(index:1);
	setprop("/instrumentation/gns530/loaded",true);
	print("GNS530 loaded");

}
# Turn on/off the displays 
var fg1000_power = func(n) {
	if (n.getValue() > 6) {
		# Show the device
		fg1000system.show(index:1);
		
		# Hack: Some nasal scripts and add-ons looks for this switch to
		# detect if the radio is serviceable...
		setprop("/instrumentation/comm/power-btn",1);
		setprop("/instrumentation/nav/power-btn",1);
	} elsif (fg1000system) {		
		fg1000system.hide(index:1);	        
		setprop("/instrumentation/comm/power-btn",0);
		setprop("/instrumentation/nav/power-btn",0);
    }
};

var loader = func(n){
	var loaded = props.globals.getNode("/instrumentation/gns530/loaded").getBoolValue();
	if (n.getValue() == "gns530"){	
		if (!loaded) {
			load_gns530();
		}
		power_listener = setlistener("/systems/electrical/outputs/gns530", fg1000_power);
		print("GNS530 power listener hooked");
    } elsif (loaded) {
        # TODO: can't unload the nasal, but we should destroy the MFD...
		if (dr400.fg1000system) {
			dr400.fg1000system.hide(index:1);
		};
		removelistener(power_listener);
		print("GNS530 power listener UNhooked");

    }
}
setlistener("sim/model/config/radio-setup", loader,1);


