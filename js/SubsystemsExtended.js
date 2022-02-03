function show_hide_div (div_id) {
	var div = document.getElementById(div_id);
	if (div.style.display == 'none') {
		div.style.display = '';
	} else {
		div.style.display = 'none';
	}
}

function change_map_color (subsystem) {
    var checkboxes = document.getElementsByName('scenarios_checked');
    var org = document.getElementById('hidden_org').getAttribute('org');
    var scens = new Array(0);
    var num_checked = 0;
    for (var i=0; i<checkboxes.length; i++) {
	if (checkboxes[i].checked) {
	    scens.push(checkboxes[i].value);
	    num_checked++;
	}
    }
    if (num_checked == 0) {
	alert ("Please select at least one scenario to color.");
    } else {
	execute_ajax("color_kegg_map", "subsys_map", subsystem+"&scens="+scens.join(' ')+"&organism="+org+"&reload_map=yes");
    }
}

function select_organism (fs_id, subsystem) {
    var orgs = document.getElementById("filter_select_"+fs_id).options;
    var scen = document.getElementById('hidden_scens').getAttribute('scens');
    for (var i=0; i<orgs.length; i++) {
	if (orgs[i].selected == 1) {
	    execute_ajax("get_scenarios", "scenarios_tab", subsystem+"&scens="+scen+"&organism="+orgs[i].value+"&reload_org=yes");
	    break;
	}
    }
}

function select_other () {
    var button = document.getElementById('org_select_switch');
    var span = document.getElementById('org_select');
    if (button.value == 'Select Organism') {
	button.value = 'Hide Organism Selection';
	span.style.display = '';
    } else {
	button.value = 'Select Organism';
	span.style.display = 'none';
    }
}

function scroll_to_element (element_id) {
    var element = document.getElementById(element_id);
    var selectedPosX = 0;
    var selectedPosY = 0;
    while (element != null) {
	selectedPosX += element.offsetLeft;
	selectedPosY += element.offsetTop;
	element = element.offsetParent;
    }
          
    window.scrollTo(selectedPosX,selectedPosY-15);
}

function display_tab (cpd_name) {
    show_tab(document.getElementById(cpd_name).parentNode.id);
}

function hide_tab (e, tab_id) {
    document.getElementById(tab_id).style.display = 'none';
    var ids = tab_id.split("_");
    tab_view_select(ids[0],"0");
    e.stopPropagation();
}

function show_tab (tab_id) {
    document.getElementById(tab_id).style.display = '';
    var ids = tab_id.split("_");
    tab_view_select(ids[0],ids[2]);
}
