// function to change values of fields
function change_field_value (id, new_value) {
   document.getElementById(id).value = new_value;
}

// clears any checked radio fields
function uncheckRadio(field) {
   var radios = document.getElementsByName(field);
   for(var i=0; i<radios.length; i++){
      if (radios[i].checked == true){
        radios[i].checked = false;
      }
   }
}

// function makes sure a radio button and checkboxes have been selected
// for assignment purposes in the evidence similarity table
function checkSanity (radio_field, checkbox_field, text_field) {
   var checks = document.getElementsByName(checkbox_field);
   var radios = document.getElementsByName(radio_field);
   var text_function = document.getElementById(text_field);
   var radio_click = "false";
   var check_click = "false";   
   var assign_to = [];

   for(var i=0; i<checks.length; i++){
      if (checks[i].checked == true){
         check_click = "true";
         assign_to.push(checks[i].value);
      }
   }
   document.getElementById('_hidden_assign_to').value = assign_to.join('~');


   if (text_function.value != ""){
      document.getElementById('_hidden_assign_from').value = text_function.value;
   }
   else {
     for(var i=0; i<radios.length; i++){
        if (radios[i].checked == true){
           radio_click = "true";
           document.getElementById('_hidden_assign_from').value = radios[i].value;
           break;
        }
     }
   }

   if ((radio_click == "false") && (text_function.value == '') ){
      alert('Select or write in a function to assign');
   }
   else if (check_click == "false"){
      alert('You must select an id to assign the function to');
   }
   else {
      execute_ajax('assignFunction', 'simTableTarget', 'sims_form', 'Processing...', 0);
      //execute_ajax('reload_simGraph', 'simGraphTarget', 'sims_form', 'Processing...', 0);
   }
}

// function used to enter the same exact text in 
// another textfield on a separate part of the form
function copyTextField (source, target){
   document.getElementById(target).value = document.getElementById(source).value;
   document.getElementById(target).checked = document.getElementById(source).checked;
}

// takes you from the visual sims view to the tabular view for the alignment of interest
function changeSimsLocation (location, tab_id){
	//alert(tab_id);
   tab_view_select("0", tab_id);
   window.location='#anchor_' + location;
}

// function for the hover effects on the buttons
function hov(loc,cls){
   if(loc.className)
      loc.className=cls;
}

function downloadFasta (id){
   var fastaline = document.getElementById(id).value;
   //var fastaline = hiddenObj.value;
//   window.open('data:application/fasta,'+encodeURI(fastaline), '_self');
   window.open('data:text/fasta,'+encodeURI(fastaline), '_self');
}

function VisualCheckPair(id1,id2,id3)
{
   var myCheckbox = document.getElementById(id1);
   var myPairCheckbox = document.getElementById(id2);
   var myCellbox = document.getElementById(id3);	

   if(myCheckbox.checked == true){
	myPairCheckbox.checked = true;
        changeColor(myCheckbox,myCellbox);
   }
   else{
	myPairCheckbox.checked = false;
	changeColor(myCheckbox,myCellbox);
   }
}

function changeColor(myCheckbox,myCellbox) {
   if (myCheckbox.checked == true) {
      myCellbox.style.color = "red";
      myCellbox.style.fontWeight = "bold";
   }
   else{
      myCellbox.style.color = "black";
      myCellbox.style.fontWeight = "normal";
   }
}

function search_in_tree (){
   var selForm = document.getElementById('main_form');
   var searchText = document.getElementById('search_string').value;
   
   if ( (searchText == null) && (searchText == "") ){
     return;
   }
   for(var i=0;i<selForm.elements.length;i++) {
      if ( (selForm.elements[i].name != null) && (selForm.elements[i].name == 'lineageBoxes') ){
         var box_id = selForm.elements[i].id;
         var taxes = box_id.split(";");
         if (taxes[taxes.length - 1] == searchText){
            var tmp_array = new Array;
			tmp_array[0] = taxes[0];
            for (var j=1;j<taxes.length-1;j++){
			   tmp_array[j] = taxes[j];
			   var tmp_box = tmp_array.join(";");
               var tree_id = document.getElementById('tree_node_' + tmp_box).value;
			   var div = document.getElementById('tree_div_'+0+'_'+ (tree_id));
               if ( ( div != null) && (div.style.display == 'none') ) {
                  expand(0,tree_id);
			   }
            }
         }
      }
   }
}

function ClickLineageBoxes (tax,boxid)
{
   var selForm = document.getElementById('main_form');
   var selBox = document.getElementById(boxid);
   if (tax != "none") {
      var selected = selBox.checked;
      for(i=0;i<selForm.elements.length;i++) {
        if (selForm.elements[i].name == "lineageBoxes") {
	   if (selForm.elements[i].id.indexOf(boxid) > -1){
	      selForm.elements[i].checked = selected;
           }
        }
      }
   }
  
   var hiddenObj = document.getElementById('selected_taxes');
   var all_items = "";
   var count=0;
   for(i=0;i<selForm.elements.length;i++) {
     if (selForm.elements[i].name == "lineageBoxes") {
        if (selForm.elements[i].checked == true){
	   var theVal = selForm.elements[i].value;
	   var theSplits = theVal.split(";");
	   var myTax = theSplits[theSplits.length - 1];
	   if ((myTax.indexOf('fig') == 0) && (count > 0)){
              all_items = all_items + "_feature=" + myTax;
           }
           else if ((myTax.indexOf('fig') == 0) && (count == 0)) {
              all_items = "feature=" + myTax;
              count++;
           }
        }
     }
   }
   hiddenObj.value=all_items;
}

var checkflag = "false";
function checkUncheckAll(form, button_id, field)
{
   var selForm = document.getElementById(form);
   var button_obj = document.getElementById(button_id);
   var button_value = button_obj.value;
      
   if (button_value == "All") {
      var action = true;
      button_obj.value = "None";
   }
   else if (button_value == "None"){
      var action = false;
      button_obj.value = "All";
   }

   for(i=0;i<selForm.elements.length;i++) {
      if (selForm.elements[i].id.indexOf('visual_fig') > -1){
         selForm.elements[i].checked = action;
         var myVisualBox = selForm.elements[i].id;
         var myCellBox = 'cell_' + selForm.elements[i].id.substring(selForm.elements[i].id.indexOf('f'));
         var myTableBox = 'tables_' + selForm.elements[i].id.substring(selForm.elements[i].id.indexOf('f'));
         VisualCheckPair(myVisualBox,myTableBox,myCellBox);
      }
   }
}

function check_up_to_last_checked (form) {
   var selForm = document.getElementById(form);
   for(i=0;i<selForm.elements.length;i++) {
      if (selForm.elements[i].id.indexOf('visual_fig') > -1){
         if (selForm.elements[i].checked){
            break;
         }
         else{
            selForm.elements[i].checked = 1;
            var myVisualBox = selForm.elements[i].id;
            var myCellBox = 'cell_' + selForm.elements[i].id.substring(selForm.elements[i].id.indexOf('f'));
            var myTableBox = 'tables_' + selForm.elements[i].id.substring(selForm.elements[i].id.indexOf('f'));
            VisualCheckPair(myVisualBox,myTableBox,myCellBox);
        }
    }
  }
}

function checkAllorNone (form, button_id, boxes)
{
   var selForm = document.getElementById(form);
   var button_obj = document.getElementById(button_id);
   var button_value = button_obj.value;

   if (button_value == "All") {
      var action = true;
      button_obj.value = "None";

      for (i = 0; i < selForm.elements.length; i++){
        if (selForm.elements[i].name == boxes){
          selForm.elements[i].checked = true ;
        }
      }

   }
   else if (button_value == "None"){
      var action = false;
      button_obj.value = "All";

      for (i = 0; i < selForm.elements.length; i++){
        if (selForm.elements[i].name == boxes){
          selForm.elements[i].checked = false;
        }
      }
   }

}

function newTextFormat (form, id, cell)
{
   var selForm = document.getElementById(form);
   for (i=0;i<selForm.elements.length;i++) {
      if (selForm.elements[i].name == id) {
         selForm.elements[i].checked = false;
      }
   }
   var myCellbox = document.getElementById(cell);
   myCellbox.style.color = "red";
}

function clearText (id)
{
   var selText = document.getElementById(id);
   if ((id == "studentNotes") || (id == "teacherNotes")){
      if (selText.value == "Enter justification for assignment here"){
         selText.value = '';
      }
   }
   else if (id == "fasta_seq"){
      if (selText.value == "Enter sequence in fasta format"){
	 selText.value = null;
      }
   }
   else{
      selText.value = '';
   }
}

function checkText (id)
{
   var selBox = document.getElementById(id);
   if (selBox.value) {
   }
   else{
      selBox.value = "Enter justification for assignment here";
   }
}

var t;
function move_center(scroll_id, table_id) {
   var selDiv = document.getElementById(scroll_id);
   var selTable = document.getElementById(table_id);

   var middle = (selTable.offsetWidth-750) / 2;
   if (Math.abs(selDiv.scrollLeft-middle) <= 1000){
      selDiv.scrollLeft = middle;
      t = setTimeout(function(){move_center(scroll_id,table_id);},10);
      clearTimeout(t);
   }
   else if (selDiv.scrollLeft<middle){
      selDiv.scrollLeft = selDiv.scrollLeft+1000; // scroll 1 pixel up
      t = setTimeout(function(){move_center(scroll_id,table_id);},10);
   }
   else if (selDiv.scrollLeft>middle){
      selDiv.scrollLeft = selDiv.scrollLeft - 1000; // scroll 1 pixel up
      t	= setTimeout(function(){move_center(scroll_id,table_id);},10);
   }
   else{
      clearTimeout(t);
   }

}

var t2;
function move_side(scroll_id,speed) {
   var selDiv = document.getElementById(scroll_id);

      selDiv.scrollLeft = selDiv.scrollLeft+speed; // scroll by x pixel
      t2 = setTimeout(function(){move_side(scroll_id,speed);},10);
      //clearTimeout(t2);
}

function stop_move(scroll_id) {
   clearTimeout(t2);
}

function move_center_start(scroll_id, table_id) {
   var selDiv = document.getElementById(scroll_id);
   var selTable = document.getElementById(table_id);

   var middle = (selTable.offsetWidth-750) / 2;
   selDiv.scrollLeft = middle;
}

function init () {
   move_center_start('codon_scroll','codon_table');
}

function changeStart (direction, startID, stopID, newStart, hiddenField, hiddenStop) {
   var newPos = document.getElementById(newStart).value;
   var start = document.getElementById(startID).innerHTML;
   var stop = document.getElementById(stopID).innerHTML;
   var oldStart = start;

   if (direction == "f"){
      if (newPos < oldStart){
         for (var i=newPos;i<=oldStart;i=i+3){
            var cellID = "f_" + i;
            if (i == newPos){
               document.getElementById(cellID).className = 'main_protein_start';
            }
            else{
               document.getElementById(cellID).className = 'main_protein_middle';
            }
         }
      }
      else if (newPos > oldStart){
         for (var i=newPos;i>=oldStart;i=i-3){
            var cellID = "f_" + i;
      	    if (i == newPos) {
      	       document.getElementById(cellID).className = 'main_protein_start';
      	    }
      	    else{
               document.getElementById(cellID).className = 'protein_none';
      	    }
      	 }
      }
   }
   else if (direction == "r"){
      if (newPos < oldStart){
         for (var i=newPos;i<=oldStart;i=i+3){
            var cellID = "r_" + i;
            if (i == newPos){
               document.getElementById(cellID).className = 'main_protein_end';
            }
            else{
               document.getElementById(cellID).className = 'protein_none';
            }
         }
      }
      else if (newPos > oldStart){
         for (var i=newPos;i>=oldStart;i=i-3){
            var cellID = "r_" + i;
            if (i == newPos) {
               document.getElementById(cellID).className = 'main_protein_end';
            }
            else{
               document.getElementById(cellID).className = 'main_protein_middle';
            }
         }
      }
   }
   document.getElementById(startID).value = newPos;
   document.getElementById(hiddenStop).value = stop;
   document.getElementById(hiddenField).value = newPos;
   document.getElementById(startID).innerHTML = newPos;
}

function fillCell (order, cellID, content, start, stop) {
   if ((order == "forward") && (start < stop)){
      if (content < stop){
         if ((start-content)%3 == 0){
            document.getElementById(cellID).innerHTML = '<div >' + content + '</div>';
            document.getElementById(cellID).value = content;
         }
         else {
            alert ('The new start must be in the same frame as the current start codon');
         }
      }
      else {
         alert ('The new start must be a position before the stop codon');
      }
   }
   else if ((order == "forward") && (stop < start)){
      alert ('The new start must be in the same frame as the current start codon');
   }
   else if ((order == "reverse") && (stop < start)){
      if (content > stop){
         if ((start-content)%3 == 0){
            document.getElementById(cellID).innerHTML = '<div >' + content + '</div>';
	    document.getElementById(cellID).value = content;
         }
         else {
            alert ('The new start must be in the same frame as the current start codon');
         }
      } 
      else {
         alert ('The new start must be a position before the stop codon');
      }
   }
   else if ((order == "reverse") && (start < stop)){
      alert ('The new start must be in the same	frame as the current start codon');
   }
}

var sPage = window.location.search;
if (sPage.indexOf('ContigView') > -1){
   window.onload = init;
}
//var sPage = sPath.substring(sPath.lastIndexOf('/') + 1);
//alert(sPath);
//window.onload = init;
