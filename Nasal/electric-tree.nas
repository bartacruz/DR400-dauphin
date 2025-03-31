var Level = {};
Level.new = func(x) {
    var obj={parents:[Level],
        x:x,
        nodes:[]
    };
    return obj;
};

var ElectricTree = {};
ElectricTree.new = func(system,x,y){
    
    var obj = {
        parents: [ElectricTree],
        system:system,
        x:x,
        y:y,
        template: nil,
        chart: nil,
        width: 100,
        height: 45,
        levels: [],
        nodes:[],
    };
    obj.loop = updateloop.UpdateLoop.new(components: [obj], update_period: 1.0, enable: 0);
    return obj;
}

ElectricTree.create_node = func(node,x,y) {
    var child = me.chart.createChild("group");
    props.copy(me.template._node,child._node);
    child.set("id",string.lc(node.class_name ~ "-" ~ node.name));
    child.setTranslation([x,y]);
    me.upd_node(node,child);
    child.setVisible(1);
    append(me.nodes,node);
    return child;
}
ElectricTree.enable = func {
    me.loop.reset();
    me.loop.enable();
};
ElectricTree.disable = func {
    me.loop.disable();
    print("ElectricTree disabled");
};
ElectricTree.reset = func {};

ElectricTree.update = func {
    foreach (var node; me.nodes) {
        me.upd_node(node);
    }
}

ElectricTree.upd_node = func(node, child=nil) {
    child = child or me.chart.getElementById(string.lc(node.class_name~"-"~ node.name));
    child.getElementById("name").setText(string.lc(node.class_name~"-"~ node.name));
    child.getElementById("volts").setText(sprintf("%.2f",node.voltage));
    child.getElementById("amps").setText(sprintf("%.2f",node.current));
        
    if (node.current >0) {
        if(node.is_instance(electric.Source)) {
            child.getElementById("background").setColorFill("#bebeff");
        } else {
            child.getElementById("background").setColorFill("#beffbe");
        }
    } elsif( node.current < 0) {
        child.getElementById("background").setColorFill("#ff8e8e");
    } else {
        child.getElementById("background").setColorFill("#bebebe");
    }
}

ElectricTree.get_level = func(node,x,y) {
    var bx = x+me.width;
    var by = math.max(1,y-(size(node.loads)-1)*me.height/2);
    var cx = bx+me.width-1;
    var cy = by + me.height*size(node.loads)-1;
    var my_level = false;
    # Loop each level looking for accomodation
    foreach(var level; me.levels) {
        if (level.x < bx) continue; # level is below us, ignore it.

        # check collision with other level's tenants.
        foreach(var tenant;level.nodes) {
            if (by < tenant[4] and cy  >tenant[2]  ) {
                # Collision detected, go up
                print(sprintf("Node %s collides with %s. %f<%f and %f > %f",node.id(),tenant[0],by,tenant[4],cy,tenant[2]));
                my_level = false;
                break;
            }
            # no collisions, let's accomodate here.
            my_level = level;
        }
        if (my_level) break;
        var bx += me.width;
        var cx += me.width;
    }

    if (!my_level) {
        
        my_level = Level.new(bx);
        append(me.levels,my_level);
    }
    print(sprintf("Source %s: found accomodation on bx=%d",node.name,bx));
    append(my_level.nodes,[node.name,bx,by,cx,cy]);
    return my_level;
}
ElectricTree.get_child = func(node) {
    return me.chart.getElementById(string.lc(node.class_name~"-"~ node.name));
}

ElectricTree.show_node = func(node,x,y){    
    var child = me.get_child(node);
    if (child) {
        # Already shown.
        return;
    }
    child = me.create_node(node,x,y); 
    #print("node ",node.name,"[",node.class_name,"]"," ",x, ",", y, debug.string(child.getTightBoundingBox()));
    var loads = [];
    foreach(var l; node.loads) {
        if (!contains(me.nodes,l)) {
            append(loads,l);
        }
    }
    if (size(loads)){
        # Find accomodation avoiding collisions
        var my_level = me.get_level(node,x,y);
        var bx = my_level.x;
        var by = math.max(1,y-(size(loads)-1)*me.height/2);
        var sizes = child.getElementById("background").getSize();
        var point = {x:x+sizes[0]-2,y:y+sizes[1]/2};
        
        printf("node %s: y=%s, loads=%s, by=%s", node.id(), y,node.ids(loads), by);
        foreach (var l; loads) { 
            var lchild = me.show_node(l,bx,by);
            # draw line.
            var point2 = {x:bx,y:by+sizes[1]/2};
            var line = me.chart.createChild("path")
                .moveTo(point.x,point.y)
                .lineTo(bx-5, point.y)
                .lineTo(bx-5, point2.y)
                .lineTo(point2.x, point2.y)
                .setColor("#1010ff")
                ;
            by +=me.height;
        
        }
    }
    return child;
}
ElectricTree.close = func {
    me.loop.disable();
    print("ElectricTree closed");
}
ElectricTree.show = func {
    me.dlg = canvas.Window.new([1024,768], "dialog")
        .set("title", "Electric Tree " ~ me.system.name);
    me.dlg._owner = me;
    me.dlg._del = me.dlg.del;
    me.dlg.del = func {    
        me._owner.disable();
        me._del();
    }
    var root = me.dlg.createCanvas().setColorBackground(1,1,1,1);
    me.chart=root.createGroup("electricchart");
    me.chart.set("clip-frame", canvas.Element.LOCAL);
    me.chart.set("clip", "rect(0px, 1024px, 768px, 0px)");
    canvas.parsesvg(me.chart,"/home/julio/.fgfs/aircraft/DR400-dauphin/Nasal/electric.svg");
    me.template = me.chart.getElementById("node");
    me.template.setVisible(0);
    var y = me.y;
    foreach(var source;me.system.sources) {
        me.show_node(source,me.x,y);
        y += me.height;
    }
}
var tree = ElectricTree.new(dr400.e_system,20,350);
tree.show();
tree.enable();
