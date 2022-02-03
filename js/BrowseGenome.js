/*conf:+define document*/
/*jsl:option explicit*/


function redraw_graphic (table_id) {
  var offset = document.getElementById("offset").value;
  var window_size = document.getElementById('window_size').options[document.getElementById('window_size').selectedIndex].value;
  var end_base = parseInt(offset) + parseInt(window_size);
  var contig = document.getElementById('contig').options[document.getElementById('contig').selectedIndex].value;
  var contig_text = document.getElementById('contig').options[document.getElementById('contig').selectedIndex].text;
  var re = /\(.+\)/;
  var m = re.exec(contig_text);
  var re2 = new RegExp("[\(\,\)\sbp]", "g");
  var contig_length = m[0].replace(re2, "");
  var data = table_extract_data(table_id, "9~"+offset+"~more^8~"+end_base+"~less^2~"+contig+"~equal");

  var coloring = document.getElementById('coloring').options[document.getElementById('coloring').selectedIndex].value;
  if (coloring == 'table') {
    var numcols = parseInt(document.getElementById('table_cols_' + table_id).value);    
    var data_array = new Array();
    var rows = data.split("%5E");
    for (var i=0; i<rows.length; i++) {
      data_array[data_array.length] = rows[i].split(/~/);
    }
    
    /* do the filtering step for each column that has a value entered in its filter box */
    for (var z=0; z<numcols; z++) {
      var filter = document.getElementById('table_' + table_id + '_operand_' + (z + 1));
      SORT_COLUMN_INDEX = z;
      if (filter) {
	if (filter.value != '') {
	  OPERAND = filter.value;
	  var operator = document.getElementById('table_' + table_id + '_operator_' + (z + 1)).value;
	  if (operator == 'equal') {
	    data_array = array_filter(data_array, element_equal);
	  } else if (operator == 'unequal') {
	    data_array = array_filter(data_array, element_unequal);
	  } else if (operator == 'like') {
	    OPERAND = reg_escape(OPERAND);
	    data_array = array_filter(data_array, element_like);
	  } else if (operator == 'unlike') {
	    OPERAND = reg_escape(OPERAND);
	    data_array = array_filter(data_array, element_unlike);
	  } else if (operator == 'less') {
	    data_array = array_filter(data_array, element_less);
	  } else if (operator == 'more') {
	    data_array = array_filter(data_array, element_more);
	  }
	}
      }
    }
    
    // extract only the fig ids from this set
    for (i=0;i<data_array.length;i++) {
      coloring = coloring + "~" + data_array[i][0];
    }
  } else if (coloring == 'list') {
    coloring = 'list';
    var rows = table_extract_data(document.getElementById('upload_table_id').value).split("%5E");
    for (i=0; i<rows.length; i++) {
      coloring = coloring + '~' + rows[i].split(/~/).join('*');
    }
  } else if (coloring == 'focus') {
    coloring = 'table~'+document.getElementById('focus_id').innerHTML;
  }

  execute_ajax("redraw", "browser_div", "contig_length="+contig_length+"&offset="+offset+"&data="+data+"&window_size="+window_size+"&coloring="+coloring);
}

function update_window_options () {
  var contig = document.getElementById('contig').options[document.getElementById('contig').selectedIndex].text;
  var window_option = document.getElementById('window_size').options[0];
  var re = /\(.+\)/;
  var m = re.exec(contig);
  window_option.text = 'all '+m[0];
  var re2 = new RegExp("[\(\,\)\sbp]", "g");
  window_option.value = m[0].replace(re2, "");
}

function focus_feature (table_id, rownum, feature) {
  // get contig and offset fields
  var i;
  var offset = document.getElementById('offset');
  var contig = document.getElementById('contig');

  // get the row data
  var data_index;
  for (i=0;i<table_list.length;i++) {
    if (table_id == table_list[i]) {
      data_index = i;
      break;
    }
  }

  // if we do not know the row, find out
  if (feature) {
    for (i=0;i<table_data[data_index].length;i++) {
      if (feature == table_data[data_index][i][0].replace(HTML_REPLACE, '')) {
	rownum = i;
	break;
      }
    }
  }
  else {
    for (i=0;i<table_data[data_index].length;i++) {
      if (rownum == table_data[data_index][i][table_data[data_index][i].length-1]) {
	rownum = i;
	break;
      }
    }
  }
  var data = table_data[data_index][rownum];

  // set the contig
  for (i=0;i<contig.options.length; i++) {
    if (contig.options[i].value == data[2]) {
      contig.selectedIndex = i;
      break;
    }
  }

  // set the offset
  var location = parseInt(data[8]) + (parseInt(data[5] / 2));
  var window_size = document.getElementById('window_size').options[document.getElementById('window_size').selectedIndex].value;
  var start = parseInt(location) - (parseInt(window_size) / 2);
  if (start < 0) { start = 0; }
  offset.value = start;

  // strip html off the id
  var id = data[0].replace(HTML_REPLACE, '');

  // update the focus tab
  document.getElementById('focus_id').innerHTML = id;
  document.getElementById('focus_type').innerHTML = data[1];
  document.getElementById('focus_contig').innerHTML = data[2];
  document.getElementById('focus_start').innerHTML = data[3];
  document.getElementById('focus_stop').innerHTML = data[4];
  document.getElementById('focus_length').innerHTML = data[5];
  document.getElementById('focus_function').innerHTML = data[6];
  document.getElementById('focus_subsystem').innerHTML = data[7];
  document.getElementById('coloring').selectedIndex=0;
  tab_view_select(0, 1);

  // redraw the graphic
  redraw_graphic(table_id);
}

function focus_upload_feature (table_id, data_table_id, rownum) {
  // get contig and offset fields
  var offset = document.getElementById('offset');
  var contig = document.getElementById('contig');
  var i;

  // get the row data
  var data_index;
  for (i=0;i<table_list.length;i++) {
    if (table_id == table_list[i]) {
      data_index = i;
      break;
    }
  }
  var data = table_data[data_index][rownum];

  // set the contig
  for (i=0;i<contig.options.length; i++) {
    if (contig.options[i].value == data[0]) {
      contig.selectedIndex = i;
      break;
    }
  }

  // set the offset
  var length = Math.abs(parseInt(data[1]) - parseInt(data[2]));
  var begin = Math.min(parseInt(data[1]), parseInt(data[2]));
  var location = parseInt(begin) + (parseInt(length / 2));
  var window_size = document.getElementById('window_size').options[document.getElementById('window_size').selectedIndex].value;
  var start = parseInt(location) - (parseInt(window_size) / 2);
  if (start < 0) { start = 0; }
  offset.value = start;

  // update the focus tab
  document.getElementById('focus_id').innerHTML = data[3];
  document.getElementById('focus_type').innerHTML = 'user defined';
  document.getElementById('focus_contig').innerHTML = data[0];
  document.getElementById('focus_start').innerHTML = data[1];
  document.getElementById('focus_stop').innerHTML = data[2];
  document.getElementById('focus_length').innerHTML = length;
  document.getElementById('focus_function').innerHTML = '-';
  document.getElementById('focus_subsystem').innerHTML = '-';

  document.getElementById('coloring').selectedIndex=3;

  // redraw the graphic
  redraw_graphic(data_table_id);
}

function move_left (table_id) {
  var offset = document.getElementById('offset');
  var window_size = document.getElementById('window_size').options[document.getElementById('window_size').selectedIndex].value;
  var start = parseInt(offset.value) - parseInt(window_size);
  if (start < 0) {
    start = 0;
  }
  offset.value = start;
  redraw_graphic(table_id);
}

function move_right (table_id) {
  var offset = document.getElementById('offset');
  var window_size = document.getElementById('window_size').options[document.getElementById('window_size').selectedIndex].value;
  var max = parseInt(document.getElementById('window_size').options[0].value) - window_size;
  var start = parseInt(offset.value) + parseInt(window_size);
  if (start > max) {
    start = max;
  }
  offset.value = start;
  redraw_graphic(table_id);
}
