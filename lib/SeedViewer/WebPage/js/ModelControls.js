$(document).ready(function() {
$.fn.checkerUpdate = function (target, data) {
    var spn = target.next('span'); 
    var newspn = false;
    if(spn.length == 0) {
        target.after('<span/>');
        spn = target.next('span');
        spn.addClass('msg');
        newspn = true;
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
    if(data && data.msg && newspn) {
        spn.append( '<img src="./Html/ajax-loader.gif" />' + data.msg);
    } else if(data && data.msg) {
        spn.empty().append(data.msg);
    }
};
// disable submit on all forms
$('.control').submit( function (e) {
    return false;
});
$('.control button').click( function(e) {
    var button = $(this);
    var form = button.parents('form')
    var form_submit_message = $('#' + form.attr('id') +
        ' span.submit_message').text() || 'processing...';
    $().checkerUpdate(button, { 'success' : '0', 'error' : '0', 'msg' : form_submit_message });
    $.ajax({
        url: web_config.model_controls_server,
        type: 'POST',
        data: 'encoding=json&function='+form.attr('id')+'&args='+
            $('#'+form.attr('id') + ' .param').formToString(),
        // get all decendants of this form that are of class .param
        success : function(data) {
            console.log(data);
            var obj = JSON.parse(data);
            $().checkerUpdate(button, obj);
        },
        error: function(data) {
            console.log(data);
            var obj = JSON.parse(data);
            $().checkerUpdate(button, obj);
        },
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


});

