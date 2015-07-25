
$(document).ready(function() {


    setTimeout(function() {
       refreshGameSaves();
    }, 3000);

});

$(document).on('click', '.btnDownloadSave', function() {
    var filepath = $(this).closest('tr').data('path');

    console.log(filepath);
});

function refreshGameSaves() {
    $.ajax({
        type: 'GET',
        url: '/GetSaveList',
        dataType: 'json',
        success: function(json) {
            console.log('success!');
            console.log(json);

            listGameSaves(json);
        },
        error: function(ex) {
            console.log('Error!');
            console.log(ex);
        }
    });
}

function listGameSaves(json) {

    if(json != null && json.length > 0) {
        var html = '';

        for(var i = 0; i < json.length; i++) {
            var filename = decodeURIComponent(json[i].split('/').pop());
            json[i] = encodeURIComponent(decodeURIComponent(json[i]));

            html += '<tr data-path="' + json[i] + '"><td>' + filename + '</td><td><a href="/download/save/' + json[i] + '" class="btn btn-default" title="Download Save"><i class="fa fa-cloud-download"></i></a></td></tr>';
        }

        var $tableGameSaves = $('#tableGameSaves');
        $tableGameSaves.html(html);
    }
}