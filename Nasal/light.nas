##########################################################
#      DE L'HAMAIDE Clément for DR400-dauphin             #
#   PAF Team - http://equipe-flightgear.forumactif.com   #
##########################################################

var navLight = aircraft.light.new("/sim/model/lights/nav-lights", [0], "/controls/lighting/nav-lights");
var landingLight = aircraft.light.new("/sim/model/lights/landing-lights", [0], "/controls/lighting/landing-lights");
var taxiLight = aircraft.light.new("/sim/model/lights/taxi-lights", [0], "/controls/lighting/taxi-lights");
var strobeLight = aircraft.light.new("/sim/model/lights/strobe-lights", [0.08, 2.5], "/controls/lighting/strobe-lights");
var floodLight = aircraft.light.new("/sim/model/lights/flood-light-left", [0], "/controls/lighting/flood-light-left");