# Copyright 2018 Stuart Buchanan
# Copyright 2020 Julio Santa Cruz
# This file is part of FlightGear.
#
# FlightGear is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# FlightGear is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with FlightGear.  If not, see <http://www.gnu.org/licenses/>.
#
# GNS530 MFD

var GNS530Pages = [
  "NavigationMap",
  "TrafficMap",
  "Stormscope",
  "WeatherDataLink",
  "TAWSB",
  "AirportInfo",
  "AirportDirectory",
  "AirportDeparture",
  "AirportArrival",
  "AirportApproach",
  "AirportWeather",
  "IntersectionInfo",
  "NDBInfo",
  "VORInfo",
  "UserWPTInfo",
  "TripPlanning",
  "Utility",
  "GPSStatus",
  "XMRadio",
  "XMInfo",
  "SystemStatus",
  "ActiveFlightPlanNarrow",
  "ActiveFlightPlanWide",
  "FlightPlanCatalog",
  "StoredFlightPlan",
 "NearestAirports",
 "NearestIntersections",
 "NearestNDB",
 "NearestVOR",
 "NearestUserWPT",
 "NearestFrequencies",
 "NearestAirspaces",
  "WaypointEntry",
  "DirectTo",
  "Surround",
];


var GNS530Display =
{
  new : func (fg1000instance, EIS_Class, EIS_SVG, SVG_Path, myCanvas, device_id=1)
  {
    var obj = {
      parents : [ GNS530Display ],
      EIS : nil,
      NavigationMap: nil,
      Surround : nil,
      _pageList : {},
      _fg1000 : fg1000instance,
      _canvas : myCanvas,
    };

    obj.ConfigStore = obj._fg1000.getConfigStore();

    obj._svg = myCanvas.createGroup("softkeys");
    obj._svg.set("clip-frame", canvas.Element.LOCAL);
    obj._svg.set("clip", "rect(0px, 1024px, 768px, 0px)");

    # monoMMM_5 is the most similar to the GNS530 font.
    var fontmapper = func (family, weight) {
      if( family == "monoMMM_5") {
    	  return "monoMMM_5.ttf";
      }
      return "LiberationFonts/LiberationSansNarrow-Regular.ttf";
    };


    foreach (var page; GNS530Pages) {
      var svg_file = SVG_Path ~ page ~ '.svg';
        # Load an SVG file if available.
        if (resolvepath(svg_file) != "") {
        canvas.parsesvg(obj._svg,
                        svg_file,
                        {'font-mapper': fontmapper});
        print("Loaded SVG" ~ svg_file);
      }
    }

    obj._MFDDevice = canvas.PFD_Device.new(obj._svg, 12, "SoftKey", myCanvas, "MFD");
    obj._MFDDevice.device_id = device_id;

    # DirectTo "Page" loaded first so that it receives any Emesary notifications
    # _before_ the actual page.
    obj._DTO = fg1000.DirectTo.new(obj, myCanvas, obj._MFDDevice, obj._svg);
    obj._DTO.getController().RegisterWithEmesary();

    # Next, the WaypointEntry "Page" so that it too receives any Emesary notifications
    # _before_ the actual page.
    obj._WaypointEntry = fg1000.WaypointEntry.new(obj, myCanvas, obj._MFDDevice, obj._svg);
    obj._WaypointEntry.getController().RegisterWithEmesary();

    obj._MFDDevice.RegisterWithEmesary();

    # Surround dynamic elements
    obj._pageTitle = obj._svg.getElementById("PageTitle");

    # Controller for the header and display on the bottom left which allows selection
    # of page groups and individual pages using the FMS controller.
    obj.Surround = fg1000.Surround.new(obj, myCanvas, obj._MFDDevice, obj._svg);
    obj.SurroundController = obj.Surround.getController();

    # GNS530 have no EIS. Make an empty EIS to fool FG1000. 
    obj.EIS = {engineMenu:"",systemMenu:""}; 

    # The NavigationMap page is a special case, as it is displayed with the Nearest... pages as an overlay
    obj.NavigationMap = fg1000.NavigationMap.new(obj, myCanvas, obj._MFDDevice, obj._svg);
    obj.addPage("NavigationMap", obj.NavigationMap);
    obj.NavigationMap.topMenu(obj._MFDDevice, obj.NavigationMap, nil);

    # Now load the other pages normally;
    foreach (var page; GNS530Pages) {
      if ((page != "NavigationMap") and (page != "EIS") and (page != "DirectTo") and (page != "WaypointEntry")) {
        print("Loading page " ~ page);
        var code = "obj.addPage(\"" ~ page ~ "\", fg1000." ~ page ~ ".new(obj, myCanvas, obj._MFDDevice, obj._svg));";
        var addPageFn = compile(code);
        addPageFn();
      }
    }

    # Display the Surround and NavMap and the appropriate top level on startup.
    obj.Surround.setVisible(1);
    obj._MFDDevice.selectPage(obj.NavigationMap);

    return obj;
  },
  getDevice : func () {
    return me._MFDDevice;
  },
  del: func()
  {
    me._MFDDevice.current_page.offdisplay();
    me._MFDDevice.DeRegisterWithEmesary();
    me.SurroundController.del();

  },
  setPageTitle: func(title)
  {
    me._pageTitle.setText(title);
  },
  addPage : func(name, page)
  {
    me._pageList[name] = page;
  },

  getPage : func(name)
  {
    return me._pageList[name];
  },

  getDeviceID : func() {
    return me._MFDDevice.device_id;
  },

  getCanvas : func() {
    return me._canvas;
  }
};
