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

function addOptionLeft(theSel, theText, theValue, tableID)
{
  var newOpt = new Option(theText, theValue);
  var selLength = theSel.length;
  theSel.options[selLength] = newOpt;

//  var mySplitResult = theValue.split("_");
//  var myLength = mySplitResult.length;
//  var myColumn = mySplitResult[myLength-1];
//  show_column(tableID, myColumn);
//  setTimeout(function(){show_column(tableID, myColumn);}, 100);
}

function deleteOptionLeft(theSel, theIndex, theValue, tableID)
{
  var selLength = theSel.length;
  if(selLength>0)
  {
    theSel.options[theIndex] = null;
    var mySplitResult = theValue.split("_");
    var myLength = mySplitResult.length;
    var myColumn = mySplitResult[myLength-1];
    //hide_column(tableID, myColumn);
    setTimeout(function(){hide_column(tableID, myColumn);}, 100);
  }
}


function addOption(theSel, theText, theValue, tableID)
{
  var newOpt = new Option(theText, theValue);
  var selLength = theSel.length;
  theSel.options[selLength] = newOpt;

  var mySplitResult = theValue.split("_");
  var myLength = mySplitResult.length;
  var myColumn = mySplitResult[myLength-1];
//  show_column(tableID, myColumn);
  setTimeout(function(){show_column(tableID, myColumn);}, 100);
}

function deleteOption(theSel, theIndex, theValue, tableID)
{ 
  var selLength = theSel.length;
  if(selLength>0)
  {
    theSel.options[theIndex] = null;
//    var mySplitResult = theValue.split("_");
//    var myLength = mySplitResult.length;
//    var myColumn = mySplitResult[myLength-1];
//    hide_column(tableID, myColumn);
//    setTimeout(function(){hide_column(tableID, myColumn);}, 100);
  }
}

function moveOptionsRight(theSelFrom, theSelTo, tableID)
{
  var myBox1 = document.getElementById(theSelFrom);
  var myBox2 = document.getElementById(theSelTo);
 
  var selLength = myBox1.length;
  var selectedText = new Array();
  var selectedValues = new Array();
  var selectedCount = 0;
  
  var i;
  
  // Find the selected Options in reverse order
  // and delete them from the 'from' Select.
  for(i=selLength-1; i>=0; i--)
  {
    if(myBox1.options[i].selected)
    {
      selectedText[selectedCount] = myBox1.options[i].text;
      selectedValues[selectedCount] = myBox1.options[i].value;
      deleteOption(myBox1, i, selectedValues[selectedCount], tableID);
      selectedCount++;
    }
  }
  
  // Add the selected text/values in reverse order.
  // This will add the Options to the 'to' Select
  // in the same order as they were in the 'from' Select.
  for(i=selectedCount-1; i>=0; i--)
  {
    addOption(myBox2, selectedText[i], selectedValues[i], tableID);
  }

  SelectSort(myBox1);
  SelectSort(myBox2);  
}

function moveOptionsLeft(theSelFrom, theSelTo, tableID)
{
  var myBox1 = document.getElementById(theSelFrom);
  var myBox2 = document.getElementById(theSelTo);

  var selLength = myBox1.length;
  var selectedText = new Array();
  var selectedValues = new Array();
  var selectedCount = 0;

  var i;

  // Find the selected Options in reverse order
  // and delete them from the 'from' Select.
  for(i=selLength-1; i>=0; i--)
  {
    if(myBox1.options[i].selected)
    {
      selectedText[selectedCount] = myBox1.options[i].text;
      selectedValues[selectedCount] = myBox1.options[i].value;
      deleteOptionLeft(myBox1, i, selectedValues[selectedCount], tableID);
      selectedCount++;
    }
  }

  // Add the selected text/values in reverse order.
  // This will add the Options to the 'to' Select
  // in the same order as they were in the 'from' Select.
  for(i=selectedCount-1; i>=0; i--)
  {
    addOptionLeft(myBox2, selectedText[i], selectedValues[i], tableID);
  }

  SelectSort(myBox1);
  SelectSort(myBox2);
}


function SelectSort(SelList)
{
    var ID='';
    var Text='';
    for (x=0; x < SelList.length - 1; x++)
    {
        for (y=x + 1; y < SelList.length; y++)
        {
            if (SelList[x].text > SelList[y].text)
            {
                // Swap rows
                ID=SelList[x].value;
                Text=SelList[x].text;
                SelList[x].value=SelList[y].value;
                SelList[x].text=SelList[y].text;
                SelList[y].value=ID;
                SelList[y].text=Text;
            }
        }
    }
}

function selectAllOptions(selStr)
{
  var selObj = document.getElementById(selStr);
  var all_items = '';
  var hiddenObj = document.getElementById('selected_columns')
  for (var i=0; i<selObj.options.length; i++) {
    selObj.options[i].selected = true;
    all_items = all_items + '#' + selObj.options[i].value;
  }
  hiddenObj.value=all_items;
}

function ClickLineageBoxes (tax,boxid)
{
   var selForm = document.getElementById('lineages');
   var selBox = document.getElementById(boxid);

   if (tax != "none") {
      var selected = selBox.checked;
      for(i=0;i<selForm.elements.length;i++) {
        if (selForm.elements[i].name == "lineageBoxes") {
	   if (selForm.elements[i].value.indexOf(tax) > -1){
	      selForm.elements[i].checked = selected;
	   }
        }
      }
   }
  
   var hiddenObj = document.getElementById('selected_taxes');
   var hiddenRange = document.getElementById('hidden_range');
   var compareRange = document.getElementById('select_compare_range');
   var all_items = "";
   for(i=0;i<selForm.elements.length;i++) {
     if (selForm.elements[i].name == "lineageBoxes") {
        if (selForm.elements[i].checked == true){
	   var theVal = selForm.elements[i].value;
	   var theSplits = theVal.split(";");
	   var myTax = theSplits[theSplits.length - 1];
           all_items = all_items + '#' + myTax;
        }
     }
   }
   hiddenObj.value=all_items;
   hiddenRange.value=compareRange.value;
}

var checkflag = "false";
function checkAll(form, id)
{
   var selForm = document.getElementById(form);
   var field = document.getElementById(id);
   var checkboxes = field.name;

   if (checkflag == "false") {
      for(i=0;i<selForm.elements.length;i++) {
         if (selForm.elements[i].name == checkboxes) {
            selForm.elements[i].checked = true;
         }
      }
      checkflag = "true";
      return ('Uncheck all');
   }
   else{
      for(i=0;i<selForm.elements.length;i++) {
         if (selForm.elements[i].name == checkboxes) {
            selForm.elements[i].checked = false ;
         }
      }
      checkflag = "false";
      return ('    Check all   ');
   }
}

function newTextFormat (form, id, cell)
{
   var selForm = document.getElementById(form);
   //var field = document.getElementById(id);
   for (i=0;i<selForm.elements.length;i++) {
	//alert (selForm.elements[i].name);
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

   if (id == "notes"){
      if (selText.value == "Enter justification for assignment here"){
         selText.value = null;
      }
   }
   else{
      selText.value = null;
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
   //selDiv.scrollLeft = middle;
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

window.onload = init;
