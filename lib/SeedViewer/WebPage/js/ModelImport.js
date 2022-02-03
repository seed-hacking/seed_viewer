$(document).ready(function() {
// Populate rxnf, cpdf and sbmlf fields with uploadify things
$.fn.setupUploadify = function (config) {
$(this).uploadify({
    'uploader' : './Html/uploadify.swf',
    'script' : FIG_Config.cgi_url + '/ModelImport_server.cgi',
    'scriptData' : { "function" : "uploadFile", "encoding" : "json" },
    'cancelImg' : './Html/cancel.png',
    'auto' : true,
    'folder' : '/uploads',
    'buttonText' : (config.buttonText) ? config.buttonText : 'Upload',
    'displayData' : 'speed',
    'onError' : config.onError,
    'onComplete' : config.onComplete,
});
}
$('#rxnf').setupUploadify({ 'buttonText' : 'Upload',
    'onComplete' : function(e, id, fileObj, resp) {
        resp = JSON.parse(resp);
        $('#rxn').createFileTokenBlob(fileObj, resp.file_token);
    },
    'onError' : function(e, id, fileObj, err) {
    },
});
$('#cpdf').setupUploadify({ 'buttonText' : 'Upload',
    'onComplete' : function(e, id, fileObj, resp) {
        resp = JSON.parse(resp);
        $('#cpd').createFileTokenBlob(fileObj, resp.file_token);
    },
    'onError' : function(e, id, fileObj, err) {
        console.log(err);
    },
});
$('#sbmlf').setupUploadify({ 'buttonText' : 'Upload',
    'onComplete' : function(e, id, fileObj, resp) {
        resp = JSON.parse(resp);
        $('#sbml').createFileTokenBlob(fileObj, resp.file_token);
    },
    'onError' : function(e, id, fileObj, err) {
        console.log(err);
    },
});

// Event handler for competed upload - hide uploder and populate form with file token
// fire event to form to start processing statistics if enough info is found
$.fn.createFileTokenBlob = function (fileObj, token) {
   var id = $(this).attr('id');
   $(this).hide();
   var target = $('#'+id+'ft');
   target.append("<li><label>Uploaded file: </label><span>" + fileObj.name +
        "<button>Remove</button><input class='uparam' type='hidden' name='" +
        id + "t' value='" + token + "'/></span></li>");    
   $('#' + id + 'ft button').click(function () {
        $('#stats').hide();
        target.children().remove();
        $('#' + id).show();
    });
   $('#' + id + 'ft').show();
   $('#importForm').change();
}

$('#importForm').change( function(e) {
    if($('.uparam[name="sbmlt"]').length > 0 || // if we have sbml token or both cpd and rxn tokens
        ( $('.uparam[name="rxnt"]').lengt > 0 && $('.uparam[name="cpdt"]').length > 0 )) {
        $('#stats *').detach();
        $('#stats').append('<legend>Model Statistics</legend>').show();
        $('#stats').append('<h3><img height="18px" src="./Html/ajax-loader.gif" /> Processing model...</h3>');
        
        $.ajax({
            url : 'http://bioseed.mcs.anl.gov/~devoid/FIG/ModelImport_server.cgi',
            type: 'POST',
            data: 'function=stat&encoding=json&args=' + $('.uparam').formToString(),
            success : function(msg) {
                console.log(msg);
                $().makeStat(JSON.parse(msg));
            },
            error: function(msg) {
                console.log(msg);
            },
        }); 
    }
});

$.fn.makeStat = function (data) {
    $('#stats *').detach();
    var statFields = $('#stats');
    if(data.msg) {
        statFields.append('<h3>'+data.msg+'</h3><ol></ol>');
    }
    var types = [ 'compounds', 'reactions', 'biomass'];
    var stats = [ 'matched', 'missed' ];
    statFields = $('#stats ol');
    for(var i=0; i<types.length; i++) {
        var type = types[i];
        if(data[type]) {
            for(var j=0; j<stats.length; j++) {
                var stat = stats[j];
                if(data[type][stat]) {
                    statFields.append('<li><label>'+stat+' '+type+'</label>'+data[type][stat]+'</li>');
                }
            }
        }
    }
    if(data.success != '1') { // don't add import button if we had a problem
        return false;
    }
    statFields.append('<li><label/><button>Complete Import</button></li>');
    $('#stats button').click(function () {
        var x = $(this);
        //x.attr('disabled', true);
        $().checkerUpdate(x, { 'success' : 'false', 'error' : 'false',
            'msg' : '<img src="./Html/ajax-loader.gif" /> Importing...' });
        $.ajax({
            url : 'http://bioseed.mcs.anl.gov/~devoid/FIG/ModelImport_server.cgi',
            type: 'POST',
            data: 'function=import&encoding=json&args=' + $('.uparam').formToString(),
            success : function(msg) {
                $().checkerUpdate(x, JSON.parse(msg));
            },
            error: function(msg) {
                $().checkerUpdate(x, {'msg' : 'Server error: ' + msg,
                    'success' : 'false', 'error' : 'true'});
            },
        });
        return false;
    });
};

$('.qparam[name="format"]').change(function (e) {
    $.each($('.qparam[name="format"]:checked'), function(i,o) {
            var target = o.value;
            $('.'+target).show();
        });
    $.each($('.qparam[name="format"]:not(:checked)'), function(i,o) {
            var target = o.value;
            $('.'+target).hide();
        });
});

$.fn.formToString = function () {
    var o = {};
    $.each($(this), function () {
        if(!o[this.name]) {
            o[this.name] = this.value || ''; 
        }
    });
    return JSON.stringify(o);
} 


$.fn.checkerUpdate = function (target, data) {
    var spn = target.next('span'); 
    if(spn.length == 0) {
        target.after('<span/>');
        spn = target.next('span');
        spn.addClass('msg');
    }
    if(!data) {
        spn.remove();
    } else if(data && data.success == "false" &&
        data.error == "false") {
        spn.addClass('msgUnknown');
        spn.removeClass('msgBad');
        spn.removeClass('msgGood');
    } else if(data && data.success == "true") {
        spn.addClass('msgGood');
        spn.removeClass('msgBad');
        spn.removeClass('msgUnknown');
    } else if(data && data.error == "true") {
        spn.addClass('msgBad');
        spn.removeClass('msgGood');
        spn.removeClass('msgUnknown');
    }
    if(data && data.msg) {
        spn.empty().append(data.msg);
    }
}
        
$('.uparam[name="id"]').blur(function () {
    var x = $(this);
    if(x.attr('value') == '') {
       $().checkerUpdate(x);
        return;
    }
    $().checkerUpdate(x, { 'success' : 'false', 'error' : 'false', 'msg' : '<img src="./Html/ajax-loader.gif" /> Checking...' });
    $.ajax({
        url : 'http://bioseed.mcs.anl.gov/~devoid/FIG/ModelImport_server.cgi',
        type: 'POST',
        data: 'function=check_id&encoding=json&args=' + $(this).formToString(),
        success: function(str) {
            console.log(str);
            data = JSON.parse(str);
            $().checkerUpdate(x, data);
        },
    });
});
        
            

});

