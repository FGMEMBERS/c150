
optarg = aircraft.optarg;
makeNode = aircraft.makeNode;


# strobes ===========================================================
strobe_switch = props.globals.getNode("controls/lighting/strobe", 1);
#aircraft.light.new("sim/model/bo105/lighting/strobe-top", 0.05, 1.00, strobe_switch);
#aircraft.light.new("sim/model/bo105/lighting/strobe-bottom", 0.05, 1.03, strobe_switch);

# beacons ===========================================================
beacon_switch = props.globals.getNode("controls/lighting/beacon", 1);
#aircraft.light.new("sim/model/bo105/lighting/beacon-top", 0.62, 0.62, beacon_switch);
#aircraft.light.new("sim/model/bo105/lighting/beacon-bottom", 0.63, 0.63, beacon_switch);



# nav lights ========================================================
nav_light_switch = props.globals.getNode("controls/lighting/nav-lights", 1);
visibility = props.globals.getNode("environment/visibility-m", 1);
sun_angle = props.globals.getNode("sim/time/sun-angle-rad", 1);
nav_lights = props.globals.getNode("sim/model/bo105/lighting/nav-lights", 1);

nav_light_loop = func {
	if (nav_light_switch.getValue()) {
		nav_lights.setValue(visibility.getValue() < 5000 or sun_angle.getValue() > 1.4);
	} else {
		nav_lights.setValue(0);
	}
	settimer(nav_light_loop, 3);
}

# settimer(nav_light_loop, 0);



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

	# doors
	foreach (d; doors) {
		w = checkbox(d.node.getNode("name").getValue());
		w.set("property", d.node.getNode("enabled").getPath());
		w.prop().getNode("binding[0]/command", 1).setValue("dialog-apply");
	}

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




# main() ============================================================
crashed = props.globals.getNode("sim/crashed", 1);
reset = props.globals.getNode("sim/model/c150/reset", 1);

main_loop = func {
	if (crashed.getValue()) {
		crash();
	} elsif (reset.getValue()) {
		REINIT();
	}
	settimer(main_loop, 0.5);
}


REINIT = func {
	reset.setIntValue(0);
}


INIT = func {

	reset.setIntValue(0);
	settimer(main_loop, 0);
}

settimer(INIT, 0);


