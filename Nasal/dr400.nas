###############################################################################
##
##  Nasal for DR400-dauphin
##
##  dany93
##  Clément de l'Hamaide - PAF Team - http://equipe-flightgear.forumactif.com
##  This file is licensed under the GPL license version 2 or later.
##
###############################################################################

#####################################
# Save data
#####################################

# 12v or 24v electric system
var system_volts = 12;

foreach( var config; props.globals.getNode("/sim/model/config").getChildren() ) {
  aircraft.data.add(config);
}

#####################################
# Dialogs
#####################################

var config_dlg = gui.Dialog.new("/sim/gui/dialogs/config/dialog", getprop("/sim/aircraft-dir")~"/Dialogs/config.xml");
var electric_dlg = gui.Dialog.new("/sim/gui/dialogs/electric/dialog", getprop("/sim/aircraft-dir")~"/Dialogs/electrical.xml");

#####################################
# Canopy
#####################################

var canopy = aircraft.door.new("canopy", 3);
  setprop("canopy/position-norm",0);
###############################################
#Fuel Management (+ Daniel Dubreuil, March 2013)
###############################################

  setprop("controls/fuel/selected-tank",-1);
  setprop("/engines/engine/fuel-pressure-psi",0);
  props.globals.initNode("consumables/fuel/tank[0]/selected",0,"BOOL");
  props.globals.initNode("consumables/fuel/tank[1]/selected",0,"BOOL");
  props.globals.initNode("consumables/fuel/tank[2]/selected",0,"BOOL");
  props.globals.initNode("consumables/fuel/fuel-low",0,"INT");

#Feeding tank (to engine)

  setlistener("controls/fuel/selected-tank", func() {
  var sel_tank = getprop("controls/fuel/selected-tank");  

     if (sel_tank == 0) {
        setprop("consumables/fuel/tank[0]/selected",1);
        setprop("fdm/jsbsim/propulsion/tank[0]/priority", 1);
     }
     else {
        setprop("consumables/fuel/tank[0]/selected",0); 
        setprop("fdm/jsbsim/propulsion/tank[0]/priority", 0);
     };
     if (sel_tank == 1) {
        setprop("consumables/fuel/tank[1]/selected",1);
        setprop("fdm/jsbsim/propulsion/tank[1]/priority", 1);
     }
     else {
        setprop("consumables/fuel/tank[1]/selected",0);  
        setprop("fdm/jsbsim/propulsion/tank[1]/priority", 0);
     };
     if (sel_tank == 2) {
        setprop("consumables/fuel/tank[2]/selected",1);
        setprop("fdm/jsbsim/propulsion/tank[2]/priority", 1);
     }
     else {
        setprop("consumables/fuel/tank[2]/selected",0);
        setprop("fdm/jsbsim/propulsion/tank[2]/priority", 0);
     }
  });

var Fuel = func {
  
  var engine_run = getprop("/engines/engine/running");
  var pump_on = (getprop("/systems/electrical/outputs/fuel-pump") > 9) ? 1 : 0;
  var fuel_level_0 = getprop("consumables/fuel/tank[0]/level-lbs");
  var fuel_level_1 = getprop("consumables/fuel/tank[1]/level-lbs");
  var fuel_level_2 = getprop("consumables/fuel/tank[2]/level-lbs");
  var tank_selector0 = getprop("consumables/fuel/tank[0]/selected");
  var tank_selector1 = getprop("consumables/fuel/tank[1]/selected");
  var tank_selector2 = getprop("consumables/fuel/tank[2]/selected");
#Fuel level low (15.43 lbs = 10 liters) in the selected tank
# two warning thresholds: light then sound

  if ((fuel_level_0 < 15.43 and tank_selector0) or (fuel_level_1 < 15.43 and tank_selector1) or (fuel_level_2 < 15.43 and tank_selector2))
    if ((fuel_level_0 < 1.5 and tank_selector0) or (fuel_level_1 < 5 and tank_selector1) or (fuel_level_2 < 1.5 and tank_selector2))
      setprop("consumables/fuel/fuel-low",2);
    else
      setprop("consumables/fuel/fuel-low",1);
  else
      setprop("consumables/fuel/fuel-low",0);

#Fuel pressure 

  if ((fuel_level_0 > 0.1 and tank_selector0) or (fuel_level_1 > 0.1 and tank_selector1) or (fuel_level_2 > 0.1 and tank_selector2))
      if (pump_on)
          interpolate("/engines/engine/fuel-pressure-psi", 4, 1); #300 mbar    
      else 
          if(engine_run)
            interpolate("/engines/engine/fuel-pressure-psi", 4, 1); #300 mbar         
          else 
               interpolate("/engines/engine/fuel-pressure-psi", 0, 1);               
  else 
      interpolate("/engines/engine/fuel-pressure-psi", 0, 1);
  
#Engine does not start if no fuel pressure 
   
  if(getprop("/engines/engine/fuel-pressure-psi") > 1){
     if (tank_selector0)
        setprop("fdm/jsbsim/propulsion/tank[0]/priority", 1);
     else 
        setprop("fdm/jsbsim/propulsion/tank[0]/priority", 0);
     if (tank_selector1)
        setprop("fdm/jsbsim/propulsion/tank[1]/priority", 1);
     else 
        setprop("fdm/jsbsim/propulsion/tank[1]/priority", 0);
     if (tank_selector2)
        setprop("fdm/jsbsim/propulsion/tank[2]/priority", 1);
     else 
        setprop("fdm/jsbsim/propulsion/tank[2]/priority", 0);
  }
  else {
     setprop("fdm/jsbsim/propulsion/tank[0]/priority", 0);
     setprop("fdm/jsbsim/propulsion/tank[1]/priority", 0);
     setprop("fdm/jsbsim/propulsion/tank[2]/priority", 0);
  }
};

##########################################
# Horameter / Chrono
##########################################

props.globals.initNode("/instrumentation/horameter/elapsed-time", 0, "INT");
props.globals.initNode("/instrumentation/chrono/elapsed-time", 0, "INT");

var chrono = aircraft.timer.new("/instrumentation/chrono/elapsed-time", 1);
var horameter = aircraft.timer.new("/instrumentation/horameter/elapsed-time", 1, 1);

setlistener("/instrumentation/horameter/running", func(running){
  if(running.getBoolValue()){
    horameter.start();
  }else{
    horameter.stop();
  }
});


var floor = func(v) v < 0.0 ? -int(-v) - 1 : int(v);
var elapsedTime = 0;
var formatedTime = "";
var sec = 0;
var min = 0;
var hrs = 0;

var timeFormat = func{

  elapsedTime = getprop("/instrumentation/chrono/elapsed-time");

  hrs = floor(elapsedTime/3600);
  min = floor(elapsedTime/60);
  sec = elapsedTime;

  formatedTime = sprintf("%02d:%02d:%02d", hrs, min-(60*hrs), sec-(60*min));
  setprop("/instrumentation/chrono/formated-time", formatedTime);

}

##############################################
############### ENGINE SYSTEM ################
##############################################

#Engine sensors class 
# ie: var Eng = Engine.new(engine number);
var Engine = {
  new : func(eng_num){
    var m = { parents : [Engine]};
    m.air_temp =      props.globals.initNode("environment/temperature-degc");
    m.oat =           m.air_temp.getValue() or 0;
    m.eng =           props.globals.initNode("engines/engine["~eng_num~"]");
    m.running =       0;
    m.ot_target =     90;
    m.mp =            m.eng.initNode("mp-inhg");
    m.cutoff =        props.globals.initNode("controls/engines/engine["~eng_num~"]/cutoff");
    m.mixture =       props.globals.initNode("engines/engine["~eng_num~"]/mixture");
    m.mixture_lever = props.globals.initNode("controls/engines/engine["~eng_num~"]/mixture",1,"DOUBLE");
    m.rpm =           m.eng.initNode("rpm",1);
    m.oil_temp =      m.eng.initNode("oil-temp-c",m.oat,"DOUBLE");
    m.cyl_temp =      m.eng.initNode("cyl-temp",m.oat,"DOUBLE");
    m.carb_heat =     m.eng.initNode("carb-heat",0,"DOUBLE");
    m.carb_temp =     m.eng.initNode("carb-temp-degc",m.oat,"DOUBLE");
    m.oil_psi =       m.eng.initNode("oil-pressure-psi",0.0,"DOUBLE");
    m.fuel_psi =      m.eng.initNode("fuel-psi-norm",0,"DOUBLE");
    m.fuel_out =      m.eng.initNode("out-of-fuel",0,"BOOL");
    m.fuel_switch =   props.globals.initNode("controls/fuel/switch-position",-1,"INT");
    m.hpump =         props.globals.initNode("systems/hydraulics/pump-psi["~eng_num~"]",0,"DOUBLE");
    m.Lrunning =      setlistener("engines/engine["~eng_num~"]/running",func (rn){m.running=rn.getValue()},0,0);
    return m;
  },
  #### update ####
  update : func(eng_num){
    var rpm =     me.rpm.getValue();
    var mp =      me.mp.getValue();
    var OT =      me.oil_temp.getValue();
    var mx =      me.mixture_lever.getValue();
    var ctemp =   me.air_temp.getValue();
    var cyltemp = me.cyl_temp.getValue();
    var cheat =   me.carb_heat.getValue();
    var cooling = (getprop("velocities/airspeed-kt") * 0.1) *2;
    ###################################
    ######### OIL TEMPERATURE #########
    ###################################
    cooling += (mx * 5);
    var tgt  = me.ot_target + mp;
    var tgt -= cooling;
    if(me.running){
      if(OT < tgt) OT += rpm * 0.00001;
      if(OT > tgt) OT -= cooling * 0.001;
    }else{
      if(OT > me.air_temp.getValue()) OT-=0.001; 
    }
    me.oil_temp.setValue(OT);
    ###################################
    ##### CARBURATOR TEMPERATURE ######
    ###################################
    var et0 = getprop("/environment/temperature-degc");
    # var cbt = et0 + 0.85 * mp; #carb temperature
    if(props.globals.getNode("systems/electrical/outputs/carb-heat").getValue() >= 12){
      cheat += 0.01;
      if(cheat > 15) cheat = 15;
      setprop("engines/engine["~eng_num~"]/carb-heat", cheat);
      # cbt += cheat;
    }else{
      cheat -= 0.05;
      if(cheat < 0) cheat = 0;
      setprop("engines/engine["~eng_num~"]/carb-heat", cheat);
      # cbt += cheat;
    }
    ctemp = (rpm * 0.0029);
    me.carb_temp.setValue(et0 - ctemp + cheat);
    ######################################
    ############ PROP FRICTION ###########
    ######################################
    if(!getprop("/fdm/jsbsim/propulsion/engine/set-running") and
        getprop("/systems/electrical/outputs/starter") < 8) {
        setprop("/fdm/jsbsim/propulsion/engine/friction-hp", 20);
    }else{
        setprop("/fdm/jsbsim/propulsion/engine/friction-hp", 0);
    }
  },
};

EngineMain = Engine.new(0);

##########################################
# Mixture/Throttle controlled by mouse
##########################################

var mousex =0;
var msx = 0;
var msxa = 0;
var mousey = 0;
var msy = 0;
var msya=0;

var mouse_accel=func{
  msx=getprop("devices/status/mice/mouse/x") or 0;
  mousex=msx-msxa;
  mousex*=0.5;
  msxa=msx;
  msy=getprop("devices/status/mice/mouse/y") or 0;
  mousey=msya-msy;
  mousey*=0.5;
  msya=msy;
#  settimer(mouse_accel, 0);
}

var set_levers = func(type,num,min,max){
  var ctrl=[];
  var cpld=-1;
  if(type == "throttle"){
    ctrl = ["controls/engines/engine[0]/throttle","controls/engines/engine[1]/throttle"];
    cpld = "controls/throttle-coupled";
  }elsif(type == "prop"){
    ctrl = ["controls/engines/engine[0]/propeller-pitch","controls/engines/engine[1]/propeller-pitch"];
    cpld = "controls/prop-coupled";
  }elsif(type == "mixture"){
    ctrl = ["controls/engines/engine[0]/mixture","controls/engines/engine[1]/mixture"];
    cpld ="controls/mixture-coupled";
  }

  var amnt =mousey* getprop("controls/movement-scale");
  var ttl = getprop(ctrl[num]) + amnt;
  if(ttl > max) ttl = max;
  if(ttl<min)ttl=min;
  setprop(ctrl[num],ttl);
  if(getprop(cpld))setprop(ctrl[1-num],ttl);
}

##############################################
######### AUTOSTART / AUTOSHUTDOWN ###########
##############################################

setlistener("/sim/model/start-idling", func(idle){
    var run= idle.getBoolValue();
    if(run){
    Startup();
    }else{
    Shutdown();
    }
},0,0);

var Startup = func{
  setprop("controls/fuel/selected-tank", 1);
  FuelValve(0);
  settimer( func { FuelValve(180); }, 0.3);
  setprop("controls/fuel/tank/boost-pump", 1);
  setprop("controls/engines/engine[0]/master-alt",1);
  setprop("/controls/engines/engine[0]/magnetos",3);
  setprop("controls/engines/engine[0]/mixture",1);
  setprop("/controls/gear/brake-parking",0);
  setprop("/controls/lighting/instrument-lights",0.8);
  setprop("/controls/lighting/instrument-lights[1]",0.8);
  setprop("/controls/lighting/instrument-lights[2]",0.8);
  setprop("/controls/lighting/nav-lights",1);
  setprop("/controls/lighting/strobe-lights",1);
  setprop("/instrumentation/comm[0]/power-btn",1);
  setprop("/instrumentation/comm[0]/volume",1);
  setprop("/instrumentation/nav[0]/power-btn",1);  
  setprop("/instrumentation/nav[0]/volume",0); 
  setprop("/instrumentation/adf[0]/power-btn",1);
  setprop("/instrumentation/adf[0]/volume",1);
  setprop("/instrumentation/adf[0]/volume-norm",1);
  setprop("controls/electric/battery-switch",1);
  setprop("controls/switches/master-avionics",1);
#  setprop("sim/messages/copilot", "Now press \"s\" to start engine");
  gui.popupTip("Now press \"s\" to start engine", 8);
}

var Shutdown = func{
  setprop("controls/fuel/selected-tank", -1);
  FuelValve(0);
  setprop("controls/engines/engine[0]/master-alt",0);
  setprop("/controls/engines/engine[0]/magnetos",0);
  setprop("controls/engines/engine[0]/mixture",1);
  setprop("/engines/engine[0]/rpm",0);
  setprop("/engines/engine[0]/running",0);
  setprop("/controls/gear/brake-parking",1);
  setprop("/controls/lighting/instrument-lights",0);
  setprop("/controls/lighting/instrument-lights[1]",0);
  setprop("/controls/lighting/instrument-lights[2]",0);
  setprop("/controls/lighting/nav-lights",0);
  setprop("/controls/lighting/strobe-lights",0);
  setprop("/instrumentation/comm[0]/power-btn",0);
  setprop("/instrumentation/comm[0]/volume",0);
  setprop("/instrumentation/nav[0]/power-btn",0);
  setprop("/instrumentation/nav[0]/volume",0);
  setprop("/instrumentation/adf[0]/power-btn",0);
  setprop("/instrumentation/adf[0]/volume",0);
  setprop("/instrumentation/adf[0]/volume-norm",0);
  setprop("controls/electric/battery-switch",0);
  setprop("controls/switches/master-avionics",0);
  setprop("controls/fuel/tank/boost-pump", 0);
  #setprop("sim/messages/copilot", "Engine is stopped");
  gui.popupTip("Engine is stopped");
}


############################################
# ELT System from Cessna337
# Authors: Pavel Cueto, with A LOT of collaboration from Thorsten and AndersG
# Adaptation by Clément de l'Hamaide and Daniel Dubreuil for DR400-dauphin
############################################

var eltmsg = func {
  var lat = getprop("/position/latitude-string");
  var lon = getprop("/position/longitude-string");
  var aircraft = getprop("/sim/description");
  var callsign = getprop("/sim/multiplay/callsign");

  if(getprop("/sim/damaged")){
     if(getprop("/instrumentation/elt/armed")) {
        var help_string = "" ~ aircraft ~ " " ~ callsign ~ "  DAMAGED, requesting SAR service";
        screen.log.write(help_string);
      }
    }
  
    if(getprop("/sim/crashed")){
      if(getprop("/instrumentation/elt/armed")) {
        var help_string = "ELT AutoMessage: " ~ aircraft ~ " " ~ callsign ~ " at " ~lat~" LAT "~lon~" LON, *** CRASHED ***";
        setprop("/sim/multiplay/chat", help_string);
        setprop("/sim/freeze/clock", 1);
        setprop("/sim/freeze/master", 1);
        setprop("/sim/crashed", 0);
        screen.log.write("Press p to resume");
      }
    }

  settimer(eltmsg, 0);  
}

setlistener("/instrumentation/elt/on", func(n) {
  if(n.getBoolValue()){
    var lat = getprop("/position/latitude-string");
    var lon = getprop("/position/longitude-string");
    var aircraft = getprop("/sim/description");
    var callsign = getprop("/sim/multiplay/callsign");
    var help_string = "ELT AutoMessage: " ~ aircraft ~ " " ~ callsign ~ " at " ~lat~" LAT "~lon~" LON, MAYDAY, MAYDAY, MAYDAY";
    setprop("/sim/multiplay/chat", help_string);
  }
});
  
setlistener("/instrumentation/elt/test", func(n) {
  if(n.getBoolValue()){
    var lat = getprop("/position/latitude-string");
    var lon = getprop("/position/longitude-string");
    var aircraft = getprop("/sim/description");
    var callsign = getprop("/sim/multiplay/callsign");
    var help_string = "Testing ELT: " ~ aircraft ~ " " ~ callsign ~ " at " ~lat~" LAT "~lon~" LON";
    screen.log.write(help_string);
  }
});

############################################
# Global loop function
# If you need to run nasal as loop, add it in this function
############################################
global_system = func{

  if(getprop("/systems/electrical/outputs/starter") >= system_volts){
    setprop("/controls/engines/engine[0]/starter",1);
  }else{
    setprop("/controls/engines/engine[0]/starter",0);
  }

  if(getprop("/systems/electrical/outputs/avionics-bus") > 8){
    setprop("/instrumentation/attitude-indicator/spin",10);
  }else{
    setprop("/instrumentation/attitude-indicator/spin",0);
  }

  Fuel();
  mouse_accel();
  timeFormat();
  EngineMain.update(0);
  if(getprop("/sim/model/config/breakable-gears")){
    dr400.physics();
  }
}
var gs_timer = maketimer(0.01,global_system);
gs_timer.singleShot = 0;
var start_global_system = func(){ 
  gs_timer.start();
  print("GLOBAL SYSTEM STARTED");
}


############################################
# Upside down system
############################################
var timeOfNegatifG = 0;
upsideDown_system = func{
  if(getprop("/sim/mode/config/simulate-g-force")){
    if(getprop("fdm/jsbsim/accelerations/Nz") < -0.5){
      timeOfNegatifG += 1;
      if(timeOfNegatifG > 4){
        setprop("controls/fuel/tank/boost-pump", 0);
        setprop("engines/engine/fuel-pressure-psi", 0);
        timeOfNegatifG = 0;
      }
    }else{
      timeOfNegatifG = 0;
    }
  }
  settimer(upsideDown_system, 1);
}


############################################
# crash-detect
############################################

setlistener("fdm/jsbsim/systems/crash-detect/over-g-failure", func(n){
  if(getprop("/sim/model/config/simulate-g-force") and n.getBoolValue()){
    if (!getprop("/sim/crashed")){
      setprop("/sim/crashed", 1);
    }
  }
});

setlistener("fdm/jsbsim/systems/crash-detect/crashed", func(n){
  if(getprop("/sim/model/config/enable-crash") and n.getBoolValue()){
    if (!getprop("/sim/crashed")){
      setprop("/sim/crashed", 1);
    }
  }
});


var firstEngineStartup = setlistener("/engines/engine/running", func(val) {
  if( val.getBoolValue() ) {
    setprop("/engines/engine/has-been-started-at-least-once", 1);
    removelistener(firstEngineStartup);
  }
});

##########################################
# SetListerner must be at the end of this file
##########################################
setlistener("/sim/signals/fdm-initialized", func{
  setprop("/instrumentation/nav[0]/power-btn",0); #force OFF
  setprop("/instrumentation/nav[1]/power-btn",0); #force OFF
  setprop("/instrumentation/adf[0]/power-btn",0);
  setprop("/instrumentation/adf[0]/volume",0);
  setprop("/instrumentation/adf[0]/volume-norm",0);
  setprop("/controls/lighting/nav-lights", 0);
  setprop("/controls/lighting/landing-lights", 0);
  setprop("/controls/electric/battery-switch", 0);
});

var nasalInit = setlistener("/sim/signals/fdm-initialized", func{

  settimer(eltmsg, 2);
  print('Emergency Locator Transmitter (ELT) loaded');

  setlistener("controls/engines/engine[0]/throttle", func(throttle){
    interpolate("controls/engines/engine[0]/throttle-hand", 0.2, 0.5);
    setprop("controls/engines/engine[0]/throttle-hand", throttle.getValue()-0.06);
    settimer(func { interpolate("controls/engines/engine[0]/throttle-hand", 0, 0.4); }, 3);
  });
  

  settimer(start_global_system, 2);
  settimer(upsideDown_system, 2);
  removelistener(nasalInit);
});
var fg1000system = nil;