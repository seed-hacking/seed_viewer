loader.require("Html/AC_OETags.min.js");
loader.require("Html/cytoscapeweb.js");
loader.require("Html/json2.js");
loader.require("Html/jquery.min.js");
loader.require("Html/ModelDBServer.js");

loader.ready(function () {
        $(document).ready(function () {
           $.ajax({
                url: "http://bioseed.mcs.anl.gov/~devoid/foo.xgmml",
                type: 'GET',
                dataType: 'xml',
                timeout: 2000,
                error: function () {
                    console.log('Error in loading xml!');
                },
                success: function (data) {
                    var options = {
                        swfPath : 'Html/CytoscapeWeb',
                        flashInstallerPath : '/Html/playerProductInstall',
                    };
                    data = (new XMLSerializer()).serializeToString(data);
                    var vis = new org.cytoscapeweb.Visualization("cytoscapeweb", options);
                    vis.addListener('error', function (evt) {
                        console.log(evt.msg);
                    });
                    vis.draw({ layout: "Preset", network: data });
                    vis.ready(function () {
                        vis.nodeTooltipsEnabled(true);
                   });
                }
            });
        });
});
