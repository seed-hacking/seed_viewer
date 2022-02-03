var checkedExperiments = new Array();
var currCount = new Array();
currCount[1] = 1;
currCount[2] = 1;


function setChecked (checkbox) {
   if (checkedExperiments.length <= 1) {
      checkedExperiments.push(checkbox.value);
   } else {
      checkedExperiments.shift();
      checkedExperiments.push(checkbox.value);
   }
} 


function setForm () {
    if (checkedExperiments.length != 2) {
        alert("You must select two expriments to run the analysis against.");
        return;
    }
    var exp1 = checkedExperiments.shift();
    var exp2 = checkedExperiments.shift();
    window.location.href = "seedviewer.cgi?page=UploadMicroarray&exp1="+exp1+"&exp2="+exp2;
}

function addAnotherUpload (num, genome) {
    currCount[num]++;
    var setId = num + "_" + currCount[num];
    $('#rep'+num+' > table').append("<tr><td>Expression Sample "+currCount[num]+":</td><td id='upload_"+setId+"_ajaxTarget'></td></tr>");
    execute_ajax('new_expression_set_box_ajax', 'upload_'+setId+'_ajaxTarget', 'queryName=upload_'+setId+'&genome='+genome, 'Loading...', 0, 'post_hook');
}
$(document).ready( function () {  
    $('#UploadForm2').submit(function () {
        currCount[1] = 0;
        $('#rep1 > table > tbody > tr').each( function(index) {
            currCount[1]++;
            });
        currCount[1]--; // for the name field
        $('#rep1Count').attr('value', currCount[1]);
        currCount[2] = 0;
        $('#rep2 > table > tbody > tr').each( function(index) {
            currCount[2]++;
            });
        currCount[2]--; // for the name field
        $('#rep2Count').attr('value', currCount[2]);
        return true;
    });
});

function select_genome (input) {
	var NewGenome;
	NewGenome = document.getElementsByName(input)[0].value;
	document.getElementById('genome_id').value = NewGenome;
	document.getElementById('UploadForm1').submit();
}
