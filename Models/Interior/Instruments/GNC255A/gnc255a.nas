# AR-6201 by D-ECHO based on

# A3XX Lower ECAM Canvas
# Joshua Davidson (it0uchpods)
#######################################

var GNC255A_com = nil;
var GNC255A_nav = nil;
var GNC255A_start = nil;
var GNC255A_brightness = nil;
var GNC255A_squelch = nil;
var GNC255A_sch = nil;
var GNC255A_sach = nil;
var GNC255A_display = nil;
var page = "com";
var comm = 0;
var nav = 0;
var comm_base = "/instrumentation/comm["~comm~"]/";
var nav_base = "/instrumentation/nav["~nav~"]/";

setprop(comm_base~"sq", 1);

var instrument_dir = "Aircraft/DR400-dauphin/Models/Interior/Instruments/GNC255A/";

var volume_prop = comm_base~"volume";
var start_prop = comm_base~"start";
var volt_prop = "/systems/electrical/outputs/comm";
var pilotmenu_prop = comm_base~"pilot-menu";
var channelmenu_prop = comm_base~"channel-menu";
var brightness_prop = comm_base~"brightness";
var squelch_prop = comm_base~"squelch-lim";

var nav_act 	=	props.globals.getNode(nav_base~"frequencies/selected-mhz", 1);
var nav_stb 	=	props.globals.getNode(nav_base ~ "frequencies/standby-mhz", 1);

var cn	 	=	props.globals.getNode("/instrumentation/gnc255a/comm-mode", 1); #0=NAV 1=COM

var serviceable	=	props.globals.getNode("/instrumentation/gnc255a/serviceable", 1);

var stored_base = comm_base~"stored_frequencies/";

var stored_frequency = {
	new : func(frequency, number){
	m = { parents : [stored_frequency] };
			m.frequency=frequency;
			m.number=number;
	return m;
	},
	set_frequency: func(frequency) {
		me.frequency = frequency;
	},
};

var stored_frequencies={1:nil,2:nil,3:nil,4:nil,5:nil,6:nil,7:nil,8:nil,9:nil,10:nil,11:nil,12:nil,13:nil,14:nil,15:nil};

for(var i = 0; i <= 15; i += 1){
    stored_frequencies[i]=stored_frequency.new(nil, i);
}

var applySelectedFrequency = func () {
	var current_channel = getprop(comm_base~"selected-channel");
	var current_channel_frequency = stored_frequencies[current_channel].frequency;
	setprop(comm_base~"frequencies/selected-mhz", current_channel_frequency);
	setprop(comm_base~"channel-menu", 0);
	setprop(comm_base~"selected-channel", 0);
}

var saveFrequency = func () {
	var current_channel = getprop(comm_base~"selected-channel");
	var current_frequency = getprop(comm_base~"frequencies/selected-mhz");
	stored_frequencies[current_channel].set_frequency(current_frequency);
	setprop(comm_base~"channel-menu", 0);
	setprop(comm_base~"selected-channel", 0);
}

var canvas_GNC255A_base = {
	init: func(canvas_group, file) {
		var font_mapper = func(family, weight) {
			if(weight=="bold"){
				return "LiberationFonts/LiberationSans-Bold.ttf";
			}else{
				return "LiberationFonts/LiberationSans-Regular.ttf";
			}
		};

		
		canvas.parsesvg(canvas_group, file, {'font-mapper': font_mapper});

		var svg_keys = me.getKeys();
		 
		foreach(var key; svg_keys) {
			me[key] = canvas_group.getElementById(key);
			var clip_el = canvas_group.getElementById(key ~ "_clip");
			if (clip_el != nil) {
				clip_el.setVisible(0);
				var tran_rect = clip_el.getTransformedBounds();
				var clip_rect = sprintf("rect(%d,%d, %d,%d)", 
				tran_rect[1], # 0 ys
				tran_rect[2], # 1 xe
				tran_rect[3], # 2 ye
				tran_rect[0]); #3 xs
				#   coordinates are top,right,bottom,left (ys, xe, ye, xs) ref: l621 of simgear/canvas/CanvasElement.cxx
				me[key].set("clip", clip_rect);
				me[key].set("clip-frame", canvas.Element.PARENT);
			}
		}

		me.page = canvas_group;

		return me;
	},
	getKeys: func() {
		return [];
	},
	update: func() {
		if(serviceable.getBoolValue() ){
			var volts = getprop(volt_prop) or 0;
			var volume = getprop(volume_prop) or 0;
			var start = getprop(start_prop) or 0;
			if ( start == 1 and volts > 9) {
				GNC255A_start.page.hide();
				var pilot_menu = getprop(pilotmenu_prop) or 0;
				var channel_menu = getprop(channelmenu_prop) or 0;
				if(cn.getValue()){
					GNC255A_com.page.show();
					GNC255A_nav.page.hide();				
				}else{
					GNC255A_nav.page.show();
					GNC255A_com.page.hide();
				}
				#GNC255A_sch.page.hide();
				#GNC255A_sach.page.hide();
			} else if ( start > 0 and start < 1 and volts > 9){
				GNC255A_com.page.hide();
				GNC255A_start.page.show();
				#GNC255A_sch.page.hide();
				#GNC255A_sach.page.hide();
				GNC255A_nav.page.hide();
			} else {
				GNC255A_com.page.hide();
				GNC255A_start.page.hide();
				#GNC255A_sch.page.hide();
				#GNC255A_sach.page.hide();
				GNC255A_nav.page.hide();
				
			}
		}else{
			GNC255A_com.page.hide();
			GNC255A_start.page.hide();
			#GNC255A_sch.page.hide();
			#GNC255A_sach.page.hide();
			GNC255A_nav.page.hide();
		}
		settimer(func me.update(), 0.02);
	},
};
	
	
var canvas_GNC255A_com = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_GNC255A_com , canvas_GNC255A_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["sq.flag","stb.flag","com.active","com.standby"];
	},
	update: func() {
		
		#var ptt = getprop(comm_base~"ptt") or 0;
		#if(ptt==1){
		#	me["TX"].show();
		#}else{
		#	me["TX"].hide();
		#}
		
		var squelch = getprop(comm_base~"sq") or 0;
		if(squelch==1){
			me["sq.flag"].show();
		}else{
			me["sq.flag"].hide();
		}
		
		var mon = getprop(comm_base~"monitor") or 0;
		if(mon==1){
			me["stb.flag"].setText("MON");
		}else{
			me["stb.flag"].setText("STB");
		}
		
		
		var active_frequency = getprop(comm_base~"frequencies/selected-mhz") or 0;
		me["com.active"].setText(sprintf("%3.3f", active_frequency));
		
		var standby_frequency = getprop(comm_base~"frequencies/standby-mhz") or 0;
		me["com.standby"].setText(sprintf("%3.3f", standby_frequency));
		
		settimer(func me.update(), 0.02);
	}
	
};	
var canvas_GNC255A_nav = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_GNC255A_nav , canvas_GNC255A_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["nav.active","nav.standby"];
	},
	update: func() {
		me["nav.active"].setText(sprintf("%3.3f", nav_act.getValue()));
		me["nav.standby"].setText(sprintf("%3.3f", nav_stb.getValue()));
		
		settimer(func me.update(), 0.02);
	}
	
};


var canvas_GNC255A_start = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_GNC255A_start , canvas_GNC255A_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return [];
	},
	update: func() {
	}
	
};


var canvas_GNC255A_brightness = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_GNC255A_brightness , canvas_GNC255A_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["brightness.bar","brightness.digits","active_frq"];
	},
	update: func() {
	
		var active_frequency = getprop(comm_base~"frequencies/selected-mhz") or 0;
		me["active_frq"].setText(sprintf("%3.3f", active_frequency));
		
		var brightness = getprop(brightness_prop);
		
		me["brightness.digits"].setText(sprintf("%3d", brightness*100));
		me["brightness.bar"].setTranslation((1-brightness)*(-315),0);
		
		settimer(func me.update(), 0.02);
	}
	
};


var canvas_GNC255A_squelch = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_GNC255A_squelch , canvas_GNC255A_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["squelch.bar","squelch.digits","active_frq"];
	},
	update: func() {
	
		var active_frequency = getprop(comm_base~"frequencies/selected-mhz") or 0;
		me["active_frq"].setText(sprintf("%3.3f", active_frequency));
		
		var squelch = getprop(squelch_prop);
		
		me["squelch.digits"].setText(sprintf("%3d", squelch));
		me["squelch.bar"].setTranslation((1-((squelch-6)/20))*(-315),0);
		
		settimer(func me.update(), 0.02);
	}
	
};


var canvas_GNC255A_sch = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_GNC255A_sch , canvas_GNC255A_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["channel.num","active_frq"];
	},
	update: func() {
	
		var active_frequency = getprop(comm_base~"frequencies/selected-mhz") or 0;
		var channel = getprop(comm_base~"selected-channel") or 0;
		
		if(channel==0 or channel>15){
			me["active_frq"].setText(sprintf("%3.3f", active_frequency));
			if(channel>15){
				me["channel.num"].setText(">>");
			}else{				
				me["channel.num"].setText("--");
			}
		}else{
			var use_freq = stored_frequencies[channel].frequency;
			if(use_freq != nil){
				me["active_frq"].setText(sprintf("%3.3f", use_freq));
			}else{
				me["active_frq"].setText(sprintf("%3.3f", active_frequency));
			}
			me["channel.num"].setText(sprintf("%02d", channel));
		}
		
		
		settimer(func me.update(), 0.02);
	}
	
};


var canvas_GNC255A_sach = {
	new: func(canvas_group, file) {
		var m = { parents: [canvas_GNC255A_sach , canvas_GNC255A_base] };
		m.init(canvas_group, file);

		return m;
	},
	getKeys: func() {
		return ["channel.num","active_frq","ind"];
	},
	update: func() {
	
		var active_frequency = getprop(comm_base~"frequencies/selected-mhz") or 0;
		var channel = getprop(comm_base~"selected-channel") or 0;
		
		me["active_frq"].setText(sprintf("%3.3f", active_frequency));
		
		if(channel==0 or channel>15){
			if(channel>15){
				me["channel.num"].setText(">>");
			}else{				
				me["channel.num"].setText("--");
			}
		}else{
			me["channel.num"].setText(sprintf("%02d", channel));
		}
		
		if(channel <= 15 and stored_frequencies[channel].frequency != nil){
			me["ind"].setText("USED");
		}else{
			me["ind"].setText("FREE");
		}
		
		
		settimer(func me.update(), 0.02);
	}
	
};


var identoff = func {
	setprop("/instrumentation/transponder/inputs/ident-btn", 0);
}

setlistener("/instrumentation/transponder/inputs/ident-btn-2", func{
	setprop("/instrumentation/transponder/inputs/ident-btn", 1);
	settimer(identoff, 18);
});


setlistener("sim/signals/fdm-initialized", func {
	GNC255A_display = canvas.new({
		"name": "GNC255A",
		"size": [200, 33],
		"view": [200, 33],
		"mipmapping": 1
	});
	GNC255A_display.addPlacement({"node": "gnc255a.screen"});
	var groupCom = GNC255A_display.createGroup();
	var groupNav = GNC255A_display.createGroup();
	var groupStart = GNC255A_display.createGroup();
	#var groupSch = GNC255A_display.createGroup();
	#var groupSach = GNC255A_display.createGroup();


	GNC255A_com = canvas_GNC255A_com.new(groupCom, instrument_dir~"gnc255a_com.svg");
	GNC255A_nav = canvas_GNC255A_nav.new(groupNav, instrument_dir~"gnc255a_nav.svg");
	GNC255A_start = canvas_GNC255A_start.new(groupStart, instrument_dir~"gnc255a_start.svg");
	#GNC255A_sch = canvas_GNC255A_sch.new(groupSch, instrument_dir~"ar6201-select-channel.svg");
	#GNC255A_sach = canvas_GNC255A_sach.new(groupSach, instrument_dir~"ar6201-save-channel.svg");

	GNC255A_com.update();
	GNC255A_nav.update();
	#GNC255A_sch.update();
	#GNC255A_sach.update();
	canvas_GNC255A_base.update();
	print("### GNC255A started");
});

var showGNC255A = func {
	var dlg = canvas.Window.new([512, 256], "dialog").set("resize", 1);
	dlg.setCanvas(GNC255A_display);
}

var stop1 = 0;
var stop2 = 0;
var stop3 = 0;

var sqlicpressed = func () {
	var time_passed = getprop(comm_base~"sql-ic-pressed-time") or 0;
	var pressed = getprop(comm_base~"sql-ic-pressed") or 0;
	if(pressed){
		if( time_passed > 2 and stop1 != 1) {
			var intercom = getprop(comm_base~"intercom");
			if(intercom==0){
				setprop(base ~ "intercom", 1);
			}else{
				setprop(base ~ "intercom", 0);
			}
			stop1 = 1;
		}
		setprop(comm_base~"sql-ic-pressed-time", time_passed + 0.1);
		settimer(sqlicpressed, 0.1);		
	} else {
		if(time_passed<2){
			var sq = getprop(comm_base~"sq");
			if(sq==0){
				setprop(base ~ "sq", 1);
			}else{
				setprop(base ~ "sq", 0);
			}
		}
		setprop(comm_base~"sql-ic-pressed-time", 0);
		stop1 = 0;
		
	}
}

var swap_freqs = func () {
	var active_prop = comm_base~"frequencies/selected-mhz";
	var standby_prop = comm_base~"frequencies/standby-mhz";
	var active = getprop(active_prop) or 0;
	var standby = getprop(standby_prop) or 0;
	
	var i=1;
	var fail=0;
	while(i<6){
		var frq=stored_frequencies[i].frequency;
		if(frq==nil){
			stored_frequencies[i].set_frequency(active);
			break;
		}else if(i==5){
			fail=1;
		}
		i=i+1;
	}
	if(fail==1){
		stored_frequencies[1].set_frequency(active);
	}
	
	setprop(active_prop, standby);
	setprop(standby_prop, active);
}

var swapscanpressed = func () {
	var time_passed = getprop(comm_base~"swap-scan-pressed-time") or 0;
	var pressed = getprop(comm_base~"swap-scan-pressed") or 0;
	if(pressed){
		if( time_passed > 2 and stop2 != 1) {
			var scan = getprop(comm_base~"scan");
			if(scan==0){
				setprop(base ~ "scan", 1);
			}else{
				setprop(base ~ "scan", 0);
			}
			stop2 = 1;
		}
		setprop(comm_base~"swap-scan-pressed-time", time_passed + 0.1);
		settimer(swapscanpressed, 0.1);
	} else {
		if(time_passed<2){
			swap_freqs();
		}
		setprop(comm_base~"swap-scan-pressed-time", 0);
		stop2 = 0;
		
	}
}

var modepressed = func () {
	var short_prop = base ~ "channel-menu";
	var long_prop = base ~ "pilot-menu";
	var time_prop = base ~ "mode-pressed-time";
	var time_passed = getprop(time_prop) or 0;
	var pressed = getprop(comm_base~"mode-pressed") or 0;
	if(pressed){
		if( time_passed > 2 and stop3 != 1) {
			var pm = getprop(long_prop);
			if(pm==0){
				setprop(long_prop, 1);
			}else{
				setprop(long_prop, 0);
			}
			stop3 = 1;
		}
		setprop(time_prop, time_passed + 0.1);
		settimer(modepressed, 0.1);
	} else {
		if(time_passed<2){
			var sch = getprop(short_prop);
			if(sch==0){
				setprop(short_prop,1);
			}else{
				setprop(short_prop,0);
			}
		}
		setprop(time_prop, 0);
		stop3 = 0;
		
	}
}


setlistener(volt_prop, func{
	if(getprop(volt_prop) > 9 and getprop(start_prop) == 0){
		interpolate(start_prop, 1, 5 );
	}else if(getprop(volt_prop) <= 9 and getprop(start_prop) != 0){
		setprop(start_prop, 0);
	}
});

setlistener(comm_base~"channel-menu", func{
	if(getprop(comm_base~"channel-menu")==0){
		setprop(comm_base~"selected-channel", 0);
	}else if(getprop(comm_base~"channel-menu")==2){
		var i=6;
		var fail=0;
		while(i<16){
			var frq=stored_frequencies[i].frequency;
			if(frq==nil){
				setprop(comm_base~"selected-channel", i);
				break;
			}else if(i==15){
				fail=1;
			}
			i=i+1;
		}
		if(fail==1){
			setprop(comm_base~"selected-channel", 6);
		}
	}
});
	
