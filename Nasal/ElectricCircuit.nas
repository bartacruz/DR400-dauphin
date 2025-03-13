###

var LinkedList = {};
var ListNode = {};
var Node = {};
var Element = {};
var CircuitCore = {};

ListNode.new = func(element,next) {
    var obj = { parents: [ListNode],
        element : element,
        next: next 
    };
    return obj;
}

LinkedList.new = func(){
    var obj = {parents:[LinkedList],
        head: nil,
        tail: nil,
        current:nil,
        last:nil,
        last_index:0,
        size:0
    };
    return obj;
}
LinkedList.push_front = func(element){
    var node = ListNode.new(element, me.head);
    if (me.size == 0) me.tail = node;
    me.head = node;
    me.size +=1;
}

LinkedList.push_back = func(element){
    if (me.size == 0) {
        me.push_front(element);
        return;
    }
    var node = ListNode.new(element, nil);
    me.tail.next = node;
	me.tail = node;
    me.size +=1;
}
LinkedList.find = func(element){
    var temp = me.head;
    while( temp != nil) {
        if (temp.element.name == element.name) {
            return temp.element;
        }
        temp = temp.next;
    }
    return nil;
}
LinkedList.pop_front = func{
    if ( me.size == 0 ){
        return false;
    }
    if (me.size == 1) me.tail = nil;
    me.head = me.head.next;
	me.size += -1;
    return true;
}

LinkedList.remove = func(element){
    if (me.size == 0) {
        print("remove on a size 0 list: " ~ element.name);
        return;
    }
    
    var cur = me.head;
    
    if (me.head.element.name = element.name) {
        me.head = me.head.next;		
		me.size += -1;
		me.last = me.head;
		me.last_index = 0;
		if (me.size == 0) tail = nil;
		return;
    }

    while (true) {
        if (cur.next == nil) return;
        if (cur.next.element.name == element.name) break;
        cur = cur.next;
    }

    if (me.tail.element.name == element.name) {
        me.tail = cur.element;
    }
    var to_remove = cur.next;
    cur.next = to_remove.next;
    me.size += -1;
    me.last = me.head;
	me.last_index = 0;
}
LinkedList.getd = func(index) {
    var node = me.head;
    for (var i = 0; i < index; i = i+1){
        node = node.next;
    }
    return node.element;
}
LinkedList.getc = func(index) {
    var node = me.head;
    while (index > 0) {
        node = node.next;
        index += -1;
    }
    return node.element;
}

var poup = func(some){
    if (some == nil) {
        return "is nil";
    }
}
LinkedList.get = func(index) {
    if (index >= me.last_index) {
        #print("index:"~ index ~", last_index:" ~ me.last_index);
	    if (me.last_index == 0) {
            me.last = me.head;
            #print("last:"~ typeof(me.last));
        }
        for (var i = 0; i < index - me.last_index; i = i+1)	{
            me.last = me.last.next;
		}
        #print("me.last is " ~ typeof(me.last));
        me.last_index = index;
        return me.last.element;
    }
	var temp = me.head;
    var step = 0;
	while (true){
		if (step == index) {
            me.last_index = index;
            me.last = temp;
            return temp.element;
		}
        temp = temp.next;
        step = step +1;
    }

}
LinkedList.plus = func(a_list) {
    for (var node = a_list.head; node.next != nil; node = node.next) {
        me.push_back(node.element);
    }
}
LinkedList.minus = func(a_list) {
    for(var i=0; i< a_list.size; i=i+1) {
        var node = a_list.get(i);
        me.remove(node.element);
    }
}
LinkedList.destroy = func {
    while(me.size > 0) {
        me.remove(me.head.element);
    }
}

LinkedList.get_intersection = func(list1,list2) {
    var intersection = LinkedList.new();
    for (var node = a_list.head; node.next != nil; node = node.next) {
        if (list2.find(node.element) != nil){
            intersection.push_back(node.element);
        }
    }

	return intersection;
}
LinkedList.list_nodes = func {
    var ret = [];
    var cur = me.head;
    #print(sprintf("#listing %s %s %s", me.size,cur,ret));
    if (me.size == 0) return ret;
    while (true) {
        append(ret,cur);
        if (cur.next == nil) return ret;
        cur = cur.next;
        #print(sprintf("##listing %s %s %s", me.size,cur.element.name,ret));
    }
    return ret;
}
LinkedList.list_elements = func {
    var ret = [];
    foreach (var n; me.list_nodes()) {
        append(ret,n.element);
    }
    return ret;
}



#
# Node
#
Node.new = func (name, friend=nil) {
    var obj = { parents : [Node],
        name: name,
        friend: friend,
        elements : LinkedList.new(),
    };
    return obj;
};

#
# Element
#
Element.new = func (name, voltage,current,resistance,node1,node2) {
    var obj = { parents : [Element],
        name:name,
        voltage:voltage,
        current:current,
        resistance:resistance,
        node1:node1,
        node2:node2,
        left:nil,
        right:nil,
        connections:0,
    };
    return obj;
};

Element.is_battery = func {
    return (me.voltage > 0.00001 or me.voltage < -0.00001);
}
Element.is_wire = func {
    return (!me.is_battery() and me.resistance < 0.00001);
}


#
# CircuitCore
#
CircuitCore.new = func {
    var obj = { parents: [CircuitCore],
        is_dirty : false,
        elements : LinkedList.new(),
        nodes : LinkedList.new()
    }
};
CircuitCore.Errors = [
    "DIRTY_CIRCUIT",
    "ELEMENT_ALREADY_EXISTS",
];

CircuitCore.search_node = func(name) {
    foreach(var node; me.nodes.list_elements()) {
        if (node.name == name) return node;
    }
    return nil;
}

CircuitCore.search_element = func(name) {
    foreach(var element; me.elements.list_elements()) {
        if (element.name == name) return element;
    }
    return nil;
}
CircuitCore.remove_element = func(element) {
    element.node1.elements.remove(element);
    element.node2.elements.remove(element);
	me.elements.remove(element);
    return element;
}
CircuitCore.remove_element_name = func(name) {
    var element = me.search_element(name);
    if (element == nil) me.remove_element(element);
    return element;
}

CircuitCore.get_or_create_node = func(name) {
    var node = me.search_node(name);
    if (!node) {
        node = Node.new(name);
        me.nodes.push_back(node);
    }
    return node;
}

CircuitCore.add_element = func(name,voltage,current,resistance,negative,positive) {
    if (me.search_element(name)) {
        print("already added: " ~name);
        return false;
    }
    var node1 = me.get_or_create_node(negative);
    var node2 = me.get_or_create_node(positive);
    var element = Element.new(name,voltage,current,resistance,node1,node2);
    me.elements.push_front(element);
    node1.elements.push_back(element);
    node2.elements.push_back(element);
    return element;
}
CircuitCore.add_element_instance = func(element) {
    if (me.search_element(element.name)) {
        print("already added: " ~name);
        return false;
    }
    var node1 = me.get_or_create_node(element.node1.name);
    var node2 = me.get_or_create_node(element.node2.name);
    
    me.elements.push_front(element);
    node1.elements.push_back(element);
    node2.elements.push_back(element);
    return element;
}

CircuitCore.add_wire = func(name,negative,positive) {
    if (negative == positive) {
        print("TWO SAME NODES");
        return false;
    }
    return me.add_element(name,0,0,0,negative,positive);
}


CircuitCore.add_resistor = func(name,resistance,negative,positive) {
    if (negative == positive) {
        print("TWO SAME NODES");
        return false;
    }
    return me.add_element(name,0,0,resistance,negative,positive);
}

CircuitCore.add_battery = func(name,voltage,negative,positive) {
    if (negative == positive) {
        print("TWO SAME NODES");
        return false;
    }
    return me.add_element(name,voltage,0,0,negative,positive);
}

CircuitCore.validate = func {
    if (me.elements.size == 0) {
        return false;
    }
    var batts = 0;
    var rs = 0;
    for (var i=0; i < me.elements.size; i = i+1) {
        var el = me.elements.get(i);
        if (el.is_battery()) batts +=1;
        if (el.resistance > 0) rs +=1;
        if ( el.node1.elements.size == 1) {
            die("element n1 not connected: " ~ el.name ~ ">" ~el.node1.name );
            
        }
        if ( el.node2.elements.size == 1) {
            die("element n2 not connected: " ~ el.name ~ ">" ~el.node2.name );
            
        }
    }
    if (batts == 0) {
        die("no bats");
    }
    if (rs == 0) {
        die("no loads");
    }
    return true;
}

CircuitCore.SERIES = 1;
CircuitCore.PARALLEL = -1;
CircuitCore.NONE = 0;

CircuitCore.connection = func(el1,el2) {
    if (me.elements.size == 2) {
        return me.SERIES;
    }
    var common_nodes = LinkedList.new();
    if (el1.node1.name == el2.node1.name ) common_nodes.push_back(el1.node1);
    if (el1.node2.name == el2.node2.name ) common_nodes.push_back(el1.node2);
    if (el1.node1.name == el2.node2.name ) common_nodes.push_back(el1.node1);
    if (el1.node2.name == el2.node1.name ) common_nodes.push_back(el1.node2);
    print("common nodes for %s and %s: %s", el1.name,el2.name, common_nodes.size);
    if (common_nodes.size == 1) {
        var node = common_nodes.get(0);
        if ( node.elements.size == 2) {
            return me.SERIES;
        }
    }
    if ( common_nodes.size == 2)  return me.PARALLEL;
    print("NOT SERIES or PARALLEL for " ~el1.name ~ " and " ~ el2.name);
    return 0;
}
CircuitCore.is_series = func(el1,el2) {
    return me.connection(el1,el2) == me.SERIES;
}
CircuitCore.is_parallel = func(el1,el2) {
    return me.connection(el1,el2) == me.PARALLEL;
}
var pprvar = func(obj) {
    foreach (var k; keys(obj)) {
        print("k: " ~ k);
    }
}
CircuitCore.print_nodes = func() {
    print("### Nodes ###");

    foreach (var node; me.nodes.list_nodes()) {
        foreach (var el; node.elements.list_nodes()) {
            pprint(el);
        
        }
    }
}
CircuitCore.remove_and_bind = func(element) {
    var saved_node = element.node1;
    var not_saved_node = element.node2;
    var is_parallel = false;
    var neighbor = nil;
    for (var i=0; i < element.node1.elements.size; i = i+1) {
        neighbor = element.node1.elements.get(i);
        print("rab neigh " ~ neighbor.name);
        if (neighbor.name == element.name) continue;
        if (me.is_parallel(element,neighbor)) {
            is_parallel = true;
            break;
        }
    }
    if (!is_parallel) {
        for (var i=0; i < element.node2.elements.size; i = i+1) {
            neighbor = element.node2.elements.get(i);
            print("rab neigh2 " ~ neighbor.name);
            if (neighbor.name == element.name) continue;
            if (me.is_parallel(element,neighbor)) {
                is_parallel = true;
                break;
            }
        }   
    }
    print(sprintf("after parallel %s element=%s, neigh=%s", is_parallel, element.name, neighbor.name));
    if (is_parallel and element.is_wire()) {
        print(sprintf("Short circuit of %s by %s (wire)",neighbor,element ));
        return false;
    }
    if (!is_parallel) {
        while ( not_saved_node.elements.size != 0) {
            var other = not_saved_node.elements.head.element;
			if (other == element) {
                print(sprintf("Element %s found in nsn head %s. Removing",element.name,not_saved_node.name ));
				not_saved_node.elements.remove(element);
				continue;
			}

			# Attach the saved_node to the element
			if (other.node1 == not_saved_node) {
				other.node1 = saved_node;
			} elsif (other.node2 == not_saved_node) {
				other.node2 = saved_node;
			}

			# Deattach the other element from the old node
            print(sprintf("Removing %s (as other) from %s",other.name,not_saved_node.name ));
			not_saved_node.elements.remove(other);
			# Attach the other element to the saved node (new node)
            print(sprintf("Pushing front %s (as other) to %s",other.name,saved_node.name ));
			saved_node.elements.push_front(other);
        }
    }
    # Deattach the leftover empty node from circuit
	if (not_saved_node.elements.size == 0){
		me.nodes.remove(not_saved_node);
		not_saved_node = nil;
	}

	# Deattach the element from its node
	element.node1.elements.remove(element);
	if (not_saved_node != nil)
		element.node2.elements.remove(element);

	# Deattach from circuit
	me.elements.remove(element);
}



CircuitCore.merge = func(el1,el2) {
    var cxn = me.connection(el1, el2);
    print(sprintf("Merge connection %s %s: %s", el1.name, el2.name, cxn));
	if (cxn == me.NONE) {
		print(sprintf("Merge failed %s %s", el1.name, el2.name));
        return nil;
    }

	
    # Are batteries in the same direction or not?
    # if not, negative the voltage of one of them
	# TODO: Check esto.
	if (el1.is_battery() and el2.is_battery())
		if (el1.node1 == el2.node1 or el1.node2 == el2.node2)
			el2.voltage *= -1;

	# Construct new element
	var name = el1.name ~ "+" ~ el2.name;
	var voltage = 0.0;
	var current = 0.0;
	var resistance = 0.0;
	var node1 = nil;
	var node2 = nil;

	if (cxn == me.SERIES) {
		resistance = el1.resistance + el2.resistance;
		voltage = el1.voltage + el2.voltage;

		# Remove the common node and save the other nodes for further using
		var commonNode = nil;
		if (el1.node1 == el2.node1) commonNode = el1.node1;
		if (el1.node2 == el2.node2) commonNode = el1.node2;
		if (el1.node1 == el2.node2) commonNode = el1.node1;
		if (el1.node2 == el2.node1) commonNode = el1.node2;

		node1 = el1.node1 == commonNode ? el1.node2 : el1.node1;
		node2 = el2.node1 == commonNode ? el2.node2 : el2.node1;

		
		#    The first node of battery, is its negative side
		#    and the second node of battery is its possitive side
		#    If an element tries to be merged with a battery, we need to make sure
		#    the negative and positive sides stay the same
		
		if (!el1.is_battery() and el2.is_battery()) {
			if (!(node1 == el2.node1 or node2 == el2.node2)){
				var temp = node1;
				node1 = node2;
				node2 = temp;
			}
		}

		if (el1.is_battery() and !el2.is_battery()) {
			if (!(node1 == el1.node1 or node2 == el1.node2)) {
				var temp = node1;
				node1 = node2;
				node2 = temp;
			}
		}

		if (el1.is_battery() and el2.is_battery()) {
			if (node1 != el1.node1 and node1 != el2.node1) {
				var temp = node1;
				node1 = node2;
				node2 = temp;
			}
		}
	}

	if (cxn == me.PARALLEL) {
		# Check short circuit. It may happen when an element is parallel with a battery
		if (el1.resistance < 0.000001 or el2.resistance < 0.000001) 
			die(sprintf("SHORT_CIRCUIT_WITH_BATTERY %s(%f) %s(%f)",el1.name,el1.resistance, el2.name, el2.resistance));

		if (math.abs(el1.voltage) > 0.00001 or math.abs(el2.voltage) > 0.00001)
			die("NOT_SERIES_NOT_PARALLEL" ~ el1.name ~ "," ~ el2.name);

		resistance = 1.0 / (1.0 / el1.resistance + 1.0 / el2.resistance);
		node1 = el1.node1;
		node2 = el1.node2;
	}

	if (node1 == nil or node2 == nil)
		die(MERGE_FAILED);

	var new_element = me.add_element(name, voltage, current, resistance, node1.name, node2.name);
    
	new_element.left = el1;
	new_element.right = el2;
	new_element.connections = cxn;
    print(sprintf("New element %s %fV %fA %sOhms  %s %s", new_element.name, new_element.voltage, new_element.current, new_element.resistance, new_element.left ? new_element.left.name : "None", new_element.connections));
	me.remove_element(el1);
	me.remove_element(el2);

	if (node1.elements.size < 2 or node2.elements.size < 2)
		die(sprintf("SHORT_CIRCUIT %s(%d) %s(%d)",node1.name,node1.elements.size, node2.name, node2.elements.size));

	return new_element;
}

CircuitCore.unmerge = func(element) {
    if (element.left == nil and element.right == nil) {
		if (!me.elements.find(element))
			me.add_element_instance(element);
		if (!element.node1.elements.find(element))
			element.node1.elements.push_front(element);
		if (!element.node2.elements.find(element))
			element.node2.elements.push_front(element);
		if (!element.is_battery)
			element.voltage = element.current * element.resistance;

		return;
	}

	var left = element.left;
	var right = element.right;
	var current = element.current;

	if (left == nil or right == nil)
		die("UNMERGE_FAILED");

	# Divide current
	if (element.connections == me.SERIES)
	{
		left.current = current;
		right.current = current;
	}

	if (element.connections == me.PARALLEL)
	{
		# Check short circuit
		if (left.resistance < 0.000001)
			left.current = current;
		else if (right.resistance < 0.000001)
			right.current = current;
		else {
			var ratio = left.resistance / right.resistance;

			left.current = current / (ratio + 1);
			right.current = ratio * current / (ratio + 1);
		}
	}

	me.unmerge(left);
	me.unmerge(right);

	# Remove element footsteps from circuit
	element.node1.elements.remove(element);
	element.node2.elements.remove(element);
	me.elements.remove(element);
}

CircuitCore.solve = func {
    if (me.is_dirty){
        print("is_dirty!");
        return;
    }
    if (!me.validate()) {
        return false;
    }
    print("before  " ~ me.elements.size);
    foreach (var element; me.elements.list_elements()) {
        if (element.is_wire()){
            print("### removing wire" ~ element.name);
			me.remove_and_bind(element);
		}
    }
    print("after  " ~ me.elements.size);
    me.print_elements();
    var merge_with_battery = false;
    var exit = false;
	while (me.elements.size != 1) { 
		for (var i = 0; i < me.elements.size - 1; i +=1) {
			for (var j = i + 1; j < me.elements.size; j +=1) {
				var el1 = me.elements.get(i);
				var el2 = me.elements.get(j);
				var cxn = me.connection(el1, el2);

				if (cxn == me.NONE)
					continue;
				if (!merge_with_battery)
					if (el1.is_battery() or el2.is_battery())
						continue;
                #print(sprintf("i=%d, merging %s with %s", i, el1.name,el2.name));
				me.merge(el1, el2);
				exit = true;
                #print("Exiting inside for2!!" ~ me.elements.size);
                break;
			}
            if (exit) {
                #print("Exiting inside for1!!" ~ me.elements.size);
                break;
            }
		}
        if (exit) {
            exit = false;
            #print("Exiting inside while!!" ~ me.elements.size);
        }
		elsif (!merge_with_battery)
			merge_with_battery = true;
		else
		{
			me.is_dirty = true;
			die("NOT_SERIES_NOT_PARALLEL");
		}

	    #exit:;
	}

	var left_over = me.elements.get(0);
	left_over.current = left_over.voltage / left_over.resistance;

	me.unmerge(left_over);
	me.is_dirty = true;
}

CircuitCore.print_elements = func() {
    print("### Elements ###");

    foreach (var el; me.elements.list_elements()) {
        #pprint(el);
        print("\telement:" ~ el.name );
    }
    print("### Nodes ###");
    foreach (var n; me.nodes.list_elements()) {
        print(typeof(n.name));
        print("\tnode:  " ~ n.name );
    }
    
    #print(el.name ~" , " ~ el.node1.name ~" , " ~ el.node2.name ~ " next:" ~ node.next.name);

}
CircuitCore.print_output = func() {
    foreach (var el; me.elements.list_elements()) {
        print(sprintf("\t%s %fv %fa %sohms  %s %s", el.name, el.voltage, el.current, el.resistance, el.left ? el.left.name : "None", el.connections));

    }
}

var test = func() {
    var circuit = ElectricCircuit.CircuitCore.new();
    # var batt = circuit.add_battery("batt",24,"battneg","battpos");
    # circuit.add_resistor("fuel-pump",400.8,"battneg","battpos");
    circuit.add_battery("B2", 12, "b", "a");
    circuit.add_resistor("R1", 5, "a", "c");
    circuit.add_resistor("R2", 5, "c", "b");

    # circuit.add_resistor("R1", 5, "b", "c");
	# circuit.add_resistor("R2", 5, "f", "g");
	# circuit.add_battery("B1", 24, "d", "e");
	# circuit.add_battery("B2", 12, "j", "i");
	# circuit.add_wire("W1", "a", "k");
	# circuit.add_wire("W2", "a", "b");
	# circuit.add_wire("W3", "c", "d");
	# circuit.add_wire("W4", "e", "f");
	# circuit.add_wire("W5", "g", "h");
	# circuit.add_wire("W6", "h", "i");
	# circuit.add_wire("W7", "j", "k");
    # circuit.add_wire("mains","battpos","main_bus");
    # circuit.add_wire("chasis","ground","battneg");
    # circuit.add_resistor("lights",24000.0,"main_bus","ground");

    # circuit.add_wire("mains","battpos","main_bus");
    # circuit.add_wire("chasis","battneg","ground");
    # circuit.add_resistor("fuel-pump",4.8,"main_bus","ground");
    # circuit.add_resistor("annunciators",80,"main_bus","ground");
    # circuit.add_wire("avionics","main_bus","avionics_bus");
    # circuit.add_resistor("gps",80,"avionics_bus","ground");
    # circuit.add_resistor("adf",80,"avionics_bus","ground");

    #circuit.add_wire(
    circuit.print_elements();
    circuit.print_output();
    circuit.solve();
    print("Solved!");
    circuit.print_output();
}