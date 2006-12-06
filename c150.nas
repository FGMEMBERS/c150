
optarg = aircraft.optarg;
makeNode = aircraft.makeNode;

last_time  = 0.0;
DTOR       = math.pi / 180.0;
starterN   = props.globals.getNode("controls/engines/engine/starter", 1);
primerN    = props.globals.getNode("controls/engines/engine/primer", 1);
MixtureLever = props.globals.getNode("controls/engines/engine[0]/mixture-lever", 1);
fdmMixture = props.globals.getNode("controls/engines/engine[0]/mixture", 1);
refTemp    = props.globals.getNode("engines/engine/oil-temperature-degf", 1);
#refTemp    = props.globals.getNode("engines/engine/egt-degf", 1);
airTempN   = props.globals.getNode("/environment/temperature-degf", 1);

pumpPrimer = func {
    if (getprop("controls/engines/engine/primer-pump") == 0){
        setprop("controls/engines/engine/primer-pump",1);
    }
    else
    {
        setprop("controls/engines/engine/primer-pump",0);
        pump = primerN.getValue() + 1;
        primerN.setValue( pump );
    }
}



# strobes ===========================================================
strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
#aircraft.light.new("sim/model/bo105/lighting/strobe-top", [0.05, 1.00], strobe_switch);
#aircraft.light.new("sim/model/bo105/lighting/strobe-bottom", [0.05, 1.03], strobe_switch);

# beacons ===========================================================
beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
#aircraft.light.new("sim/model/bo105/lighting/beacon-top", [0.62, 0.62], beacon_switch);
#aircraft.light.new("sim/model/bo105/lighting/beacon-bottom", [0.63, 0.63], beacon_switch);



# nav lights ========================================================
nav_light_switch = props.globals.getNode("controls/lighting/nav-lights", 1);
visibility = props.globals.getNode("environment/visibility-m", 1);
sun_angle = props.globals.getNode("sim/time/sun-angle-rad", 1);
nav_lights = props.globals.getNode("sim/model/c150/lighting/nav-lights", 1);

nav_light_loop = func {
	if (nav_light_switch.getValue()) {
		nav_lights.setValue(visibility.getValue() < 5000 or sun_angle.getValue() > 1.4);
	} else {
		nav_lights.setValue(0);
	}
	settimer(nav_light_loop, 3);
}

settimer(nav_light_loop, 0);



# doors =============================================================
active_door = 0;
doors = [];

init_doors = func {
	foreach (d; props.globals.getNode("sim/model/c150/doors").getChildren("door")) {
		append(doors, aircraft.door.new(d, 2.5));
	}
}
settimer(init_doors, 0);

next_door = func { select_door(active_door + 1) }

previous_door = func { select_door(active_door - 1) }

select_door = func {
	active_door = arg[0];
	if (active_door < 0) {
		active_door = size(doors) - 1;
	} elsif (active_door >= size(doors)) {
		active_door = 0;
	}
	gui.popupTip("Selecting " ~ doors[active_door].node.getNode("name").getValue());
}

toggle_door = func {
	doors[active_door].toggle();
}


variant = nil;


# dialogs ===========================================================
dialog = nil;

showDialog = func {
	name = "c150-config";
	if (dialog != nil) {
		fgcommand("dialog-close", props.Node.new({ "dialog-name" : name }));
		dialog = nil;
		return;
	}
	dialog = gui.Widget.new();
	dialog.set("layout", "vbox");
	dialog.set("name", name);

	# "window" titlebar
	titlebar = dialog.addChild("group");
	titlebar.set("layout", "hbox");
	titlebar.addChild("text").set("label", "____________C150 configuration____________");
	titlebar.addChild("empty").set("stretch", 1);

	dialog.setColor(0.6, 0.65, 0.55, 0.85);

	w = titlebar.addChild("button");
	w.set("pref-width", 16);
	w.set("pref-height", 16);
	w.set("legend", "");
	w.set("default", 1);
	w.set("border", 1);
	w.prop().getNode("binding[0]/command", 1).setValue("nasal");
	w.prop().getNode("binding[0]/script", 1).setValue("c150.dialog = nil");
	w.prop().getNode("binding[1]/command", 1).setValue("dialog-close");

	checkbox = func {
		group = dialog.addChild("group");
		group.set("layout", "hbox");
		group.addChild("empty").set("pref-width", 4);
		box = group.addChild("checkbox");
		group.addChild("empty").set("stretch", 1);

		box.set("halign", "left");
		box.set("label", arg[0]);
		box;
	}
    button = func {
	    w = dialog.addChild("button");
#	    w.set("pref-width", 16);
#	    w.set("pref-height", 16);
	    w.set("legend", arg[0]);
#	    w.set("default", 1);
	    w.set("border", 1);
		w.set("label", "");
	    w.prop().getNode("binding[0]/command", 1).setValue("nasal");
	    w.prop().getNode("binding[0]/script", 1).setValue(arg[1]);
	    w.prop().getNode("binding[1]/command", 1).setValue("dialog-close");
    }

	# doors
	foreach (d; doors) {
#		w = checkbox(d.node.getNode("name").getValue());
#		w.set("property", d.node.getNode("enabled").getPath());
#		w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	}

    w = button( "Cold start", "c150.cold_start();" );
    w = button( "Hot start", "c150.hot_start();" );

	# lights
#	w = checkbox("beacons");
#	w.set("property", "controls/lighting/beacon");
#	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");

#	w = checkbox("strobes");
#	w.set("property", "controls/lighting/strobe");
#	w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");


	# finale
	dialog.addChild("empty").set("pref-height", "3");
	fgcommand("dialog-new", dialog.prop());
	gui.showDialog(name);
}

controls.mixtureAxis = func {
    val = cmdarg().getNode("setting").getValue();
    if(size(arg) > 0) { val = -val; }
    props.setAll("/controls/engines/engine", "mixture-lever", (1 - val)/2);
}

# simulate fuel cut off due to lack of gravity
# simulate engine cold start
calcMixture = func {
    gg = - getprop("/fdm/jsbsim/accelerations/n-pilot-z-norm");
    # compute this value since jsbsim does not export it here
    # need to check the AS or else any bump in terrain will cut the fuel flow
    if( getprop("/velocities/airspeed-kt") < 30.0 ) {
        gg = 1.0;
    }
    setprop("accelerations/pilot-g", gg);

    g = getprop("accelerations/pilot-g");
    if (g == nil) {
	    g = 1.0;
    }
    if (g > 0.75) {
        mixture = 1.0;
    }
    elsif (g <= 0.75 and g >= 0)  {            # mixture set by - ve g
        mixture = g * 4/3;
    }
    else  {                                    # mixture set by - ve g
        mixture = 0.0;
    }
    mixture = mixture * MixtureLever.getValue();
    # use oil temp because engine temp is off at startup
    # but oil temp is off too because of a 298°K base
    # 298 K == 77 F == 25 C
    engineTemp = refTemp.getValue();
    # engineTemp is wrong at startup
#    if( engineTemp < 77 ) {engineTemp = 77);
    engineTemp = engineTemp - 77 + airTempN.getValue();
    pump = primerN.getValue();
    if( getprop( "engines/engine/running") == 0) {
        if( pump > 7) {
            # flooding
            mixture = 0;
        }
        if( engineTemp <= 40 ) {
            if( pump < 5) {
                mixture = 0;
            }
            # up to 6 primer
        } elsif ( engineTemp <= 65 ) {
            # 1 or 2 primer
            if( pump < 1) {
                mixture = 0;
            }
        }
    } else {
        primerN.setValue( 0 );
    }
    if( starterN.getValue() ) {
        print("engineTemp=", engineTemp, " pump=", pump, " => mixture=", mixture);
        primerN.setValue( pump - 0.2);
        if( primerN.getValue() < 0 ) {
            primerN.setValue( 0 );
        }
    }
    fdmMixture.setValue( mixture );
}

system_loop = func {

    time = getprop("/sim/time/elapsed-sec");
    dt = time - last_time;
    last_time = time;

    calcMixture();
#	fdmMixture.setValue( MixtureLever.getValue() );

    ldoorw = 0.0;
    rdoorw = 0.0;
    if( getprop("sim/model/c150/doors/door[0]/position-norm") > 0.0 ) { ldoorw += 1.0; }
    elsif( getprop("sim/model/c150/doors/door[2]/position-norm") > 0.0 ) { ldoorw += 0.5; }
    if( getprop("sim/model/c150/doors/door[1]/position-norm") > 0.0 ) { rdoorw += 1.0; }
    elsif( getprop("sim/model/c150/doors/door[3]/position-norm") > 0.0 ) { rdoorw += 0.5; }
    setprop("sim/model/c150/doors/doorw", ldoorw + rdoorw);

    computeCompress(dt);
	settimer(system_loop, 0.1);
}


# reset code ========================================================
cold_start = func {
    print("cold start");
	setprop("controls/engines/engine/primer", 0);
	setprop("controls/engines/engine/primer-pump", 0);
	MixtureLever.setValue(0.0);
	fdmMixture.setValue(0.0);
	setprop("engines/engine/rpm", 0.0);
	setprop("controls/engines/engine/magnetos", 0);
	setprop("controls/engines/engine/master-alt", 0);
	setprop("controls/engines/engine/master-bat", 0);
	setprop("engines/engine/running", 0);
    setprop("controls/engines/engine/throttle", 0.0);
}

hot_start = func {
	cold_start();
    print("hot start");
	fdmMixture.setValue(1.0);
	MixtureLever.setValue(1.0);
	setprop("engines/engine/rpm", 700.0);
	setprop("controls/engines/engine/magnetos", 3);
	setprop("controls/engines/engine/master-alt", 1);
	setprop("controls/engines/engine/master-bat", 1);
	setprop("controls/engines/engine/primer", 2);
	setprop("engines/engine/running", 1);
    setprop("controls/engines/engine/throttle", 0.25);
}

# main() ============================================================
crashed = props.globals.getNode("sim/crashed", 1);
reset = props.globals.getNode("sim/model/c150/reset", 1);

main_loop = func {
	if (crashed.getValue()) {
		crash();
	} elsif (reset.getValue()) {
		on_menu_reset();
	}
	settimer(main_loop, 0.5);
}


crash = func {
    print("crashed ?");
    reset.setIntValue(1);
}


on_menu_reset = func {
	reset.setIntValue(0);
	hot_start();
}


INIT = func {
    on_menu_reset();

	settimer(main_loop, 1.0);
	settimer(system_loop, 1.0);
}


wheels = [
    [ 0.805, 0, -1.23, 0.0],
    [ 2.28, 1.10, -1.18, 0.0],
    [ 2.28, -1.10, -1.18, 0.0]
];

last_lon = 0.0;
last_lat = 0.0;
prev_dist = prev_dt = 1.0;

computeCompress = func(dt) {

    lat = getprop("/position/latitude-deg") * DTOR;
    lon = getprop("/position/longitude-deg") * DTOR;
    dstVnormal = [0.0, 0.0, 0.0];
    dstP = [0.0, 0.0, 0.0, 0.0];
    wheelPos = [0.0, 0.0, 0.0];
    cg = [2.10, 0.0, -0.40];
    h = getprop("/orientation/heading-deg") * DTOR;
    p = getprop("/orientation/pitch-deg") * DTOR;
    r = getprop("/orientation/roll-deg") * DTOR;
    calcVec(dstVnormal, h, p, r);

    alt = getprop("/position/altitude-agl-ft") * 0.3048;

    dstP = [dstVnormal[0], dstVnormal[1], dstVnormal[2], dstVnormal[2] * alt];

    setprop("gear/gear[0]/compression-norm", calcComp(dstP, wheels[0], cg));
    setprop("gear/gear[1]/compression-norm", calcComp(dstP, wheels[1], cg));
    setprop("gear/gear[2]/compression-norm", calcComp(dstP, wheels[2], cg));
    dist = calcDist(last_lat, last_lon, lat, lon);

    setprop("/temp/dist", dist);
    speed = (dist+prev_dist) / (dt+prev_dt);
    setprop("/temp/speed-mps", speed);
    setprop("/temp/speed-mph", speed * 2.2369);
    prev_dist = dist; prev_dt = dt;
    last_lon = lon;
    last_lat = lat;
}

calcComp = func(Plane, wheelPos, cg) {

    wheel = [wheelPos[0] - cg[0], wheelPos[1] - cg[1], wheelPos[2] - cg[2]];
    d = sgHeightAbovePlaneVec3(Plane, wheel);
    if( d > 0 ) {
        # WoW = False
        return 0.0;
    } else {
        # WoW = True
        return -d / 0.15;
    }
}

calcVec = func(dst, h, p, r) {
    sh = math.sin(h);
    ch = math.cos(h);
    sp = math.sin(p);
    cp = math.cos(p);
    sr = math.sin(r);
    cr = math.cos(r);
    crsp = cr * sp;
    dst[0] = (sr * ch + sh * crsp);
    dst[1] = (sr * sh - crsp * ch);
    dst[2] = (cr * cp);
}

sgHeightAbovePlaneVec3 = func(Plane, pnt) {
    if( Plane[2] == 0.0 ) {
        return pnt[2];
    } else {
        return pnt[2] + (Plane[0] * pnt[0] + Plane[1] * pnt[1] + Plane[3]) / Plane[2];
    }
}

asin = func(x) {
    return math.atan2(x,math.sqrt( (1.0-x)*(1.0-x) ));
}

calcDist = func(lat1, lon1, lat2, lon2) {
    tempa = math.sin(  (lat1-lat2)/2  );
    tempa = tempa * tempa;
    tempb = math.sin( (lon1-lon2)/2 );
    tempb = tempb * tempb;
    dd=2.0 * 
    asin(   math.sqrt( tempa + math.cos(lat1)*math.cos(lat2) * tempb ) );
    return dd * 1852.0 * 180.0 / math.pi * 60.0;
}

settimer(INIT, 0);
