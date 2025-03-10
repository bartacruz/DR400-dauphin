# Copyright 2018 Stuart Buchanan
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
# NavCom Interface using Emesary for a simple dual Nav/Com system using standard properties
# This updates the properties from Emesary messages.

var GNS530NavComUpdater =
{
  new : func () {
    var obj = {
      parents : [
        GNS530NavComUpdater,
        PropertyUpdater.new(
          notifications.PFDEventNotification.DefaultType,
          notifications.PFDEventNotification.NavComData
        )
      ],
    };

    # GNS530 only operates on comm1 and nav1, and starts with comm selected
    setprop("/instrumentation/com-selected", 1);
    setprop("/instrumentation/nav-selected", 1);
    
    # Custom property to detect where to actuate with the freq knob
    setprop("/instrumentation/navcom-selected", 1);
    
    obj.addPropMap("Comm1SelectedFreq", "/instrumentation/comm/frequencies/selected-mhz");
    obj.addPropMap("Comm1StandbyFreq", "/instrumentation/comm/frequencies/standby-mhz");
#    obj.addPropMap("Comm1AirportID", "/instrumentation/comm/airport-id");
#    obj.addPropMap("Comm1StationName", "/instrumentation/comm/station-name");
#    obj.addPropMap("Comm1StationType", "/instrumentation/comm/station-type");
    obj.addPropMap("Comm1Volume", "/instrumentation/comm/volume");
    obj.addPropMap("Comm1Serviceable", "/instrumentation/comm/serviceable");

    obj.addPropMap("Nav1SelectedFreq", "/instrumentation/nav/frequencies/selected-mhz");
    obj.addPropMap("Nav1StandbyFreq", "/instrumentation/nav/frequencies/standby-mhz");
    obj.addPropMap("Nav1RadialDeg", "/instrumentation/nav/radials/selected-deg");
    obj.addPropMap("Nav1Volume", "/instrumentation/nav/nav-volume");
#    obj.addPropMap("Nav1AudioID", "/instrumentation/nav/audio-btn");
    obj.addPropMap("Nav1Serviceable", "/instrumentation/nav/operable");

    obj.addPropMap("NavCommSelected", "/instrumentation/navcom-selected");
    obj.addPropMap("TransponderMode", "/instrumentation/transponder/inputs/knob-mode");
    obj.addPropMap("TransponderIdent", "/instrumentation/transponder/inputs/ident-btn");
    obj.addPropMap("TransponderCode", "/instrumentation/transponder/id-code");

    return obj;
  },
};
