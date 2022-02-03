var media = new Array();
var compounds = new Array();

function removeCompound (cpdId) {
    var row = document.getElementById(cpdId);
    row.parentNode.removeChild(row);
}

function addCompound (id, name) {
    if (document.getElementById(id) != null) {
        return;
    }
    var table = document.getElementById('mediaTable');
    for(var i=0; i<table.childNodes.length; i++) {
        var node = table.childNodes[i];
        if (node.tagName == 'TBODY') {
            break;
        }     
    }
    var link = document.createElement("td");
    link.innerHTML = "<a href='seedviewer.cgi?page=CompoundViewer&compound="+id+"'>"+name+"</a><input type='hidden' class='cpdId' value='"+id+"'/>";
    var conc = document.createElement("td");
    conc.innerHTML = "<input type='text' name='"+id+"_conc'></input>";
    var max = document.createElement("td");
    max.innerHTML = "<input type='text' name='"+id+"_max'></input>";
    var remove = document.createElement("td");
    remove.innerHTML = "<input type='button' value='remove' onClick='removeCompound(\"" +id+ "\");'></input>";
    var error = document.createElement("td");
    var rowDiv = document.createElement("tr");
    rowDiv.id = id;
    rowDiv.appendChild(link);
    rowDiv.appendChild(conc);
    rowDiv.appendChild(max);
    rowDiv.appendChild(remove);
    rowDiv.appendChild(error);
    node.appendChild(rowDiv);
}

function parseOneB (e, d) {
    var keyValuePairs = d.split('&');
    var method = 'none';
    var key, value;
    for(var i=0; i<keyValuePairs.length; i++) {
        var keyValue = keyValuePairs[i].split('=');
        if(keyValue && keyValue.length > 0) {
            if(keyValue[0] == 'media') {
                method = 'media';    
            } else if (keyValue[0] == 'fileText' &&
                keyValue.length > 1 && keyValue[1].length > 0) {
                method = 'text';
            } else if (keyValue[0] == 'new' && 
                keyValue.length == 2 && keyValue[1] == 'empty') {
                method = 'empty'; 
            }
            if (method != 'none') {
                key = keyValue[0];
                value = keyValue[1];
                break;
            }
        }
    }
    var one, two;
    if(method != 'none') {
        one = document.getElementById('one');
        two = document.getElementById('two');
        two.style.backgroundColor = one.style.backgroundColor;
        one.style.backgroundColor = "rgb(221, 221, 221)";
    }
    if (method == 'media') {
        one.innerHTML = "<h3>Step 1: Use existing formulation: "+unescape(value)+"</h3>";
        execute_ajax('new_media_step_two', 'two', 'media='+value, 'Loading...', 0, format_step_two);
    } else if (method == 'text') {
        one.innerHTML = "<h3>Step 1: Upload formulation from text</h3>";
        execute_ajax('new_media_step_two', 'two', 'media='+value, 'Loading...', 0, format_step_two);
    } else if (method == 'empty') {
        one.innerHTML = "<h3>Step 1: Start with an empty formulation</h3>";
        execute_ajax('new_media_step_two', 'two', 'media=', 'Loading...', 0, format_step_two);
    }
}

function parseTwo () {
    var media = new Array();
    var cpdIds = document.getElementsByClassName('cpdId');   
    for(var i=0; i<cpdIds.length; i++) {
        var compoundInfo = new Array();
        var id = cpdIds[i].value;
        compoundInfo.push(id);
        var conc = document.getElementById(id+'_conc');
        var max = document.getElementById(id+'_max');
        (conc == null) ? conc = '0.001' : conc = conc.value;
        (max == null) ? max = '100' : max = max.value; 
        compoundInfo.push(conc);
        compoundInfo.push(max);
        media.push(compoundInfo.join(','));
    }
    media = media.join(':');
    var two, three;
    two = document.getElementById('two');
    three = document.getElementById('three');
    three.style.backgroundColor = two.style.backgroundColor;
    two.style.backgroundColor = "rgb(221, 221, 221)";
    execute_ajax('new_media_completed_two', 'two', 'media='+media, 'Loading...', 0);
    execute_ajax('new_media_step_three', 'three', 'media='+media, 'Loading...', 0);
}

function displayOverflow (obj) {
    for(var i=0; i<obj.childNodes.length; i++) {
        if(obj.childNodes[i].style) 
            obj.childNodes[i].style.visibility = "visible";
    }
}    

function format_step_two() {
    var tbls = document.getElementsByClassName('table_table');
    for(var i=0; i<tbls.length; i++) {
        tbls[i].style.backgroundColor = "rgb(255,255,255)";
    }
}

function saveMedia() {
    execute_ajax('new_media_final', 'content', 'formThree', 'Loading...', 0);
}
