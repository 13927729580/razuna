<script type="text/javascript">
(function() {
    if (typeof window.janrain !== 'object') window.janrain = {};
    if (typeof window.janrain.settings !== 'object') window.janrain.settings = {};
    
    janrain.settings.tokenUrl = 'http://<cfoutput>#cgi.http_host##cgi.script_name#?fa=c.login_janrain&shared=#attributes.shared#&fid=#attributes.fid#&wid=#attributes.wid#</cfoutput>';

	janrain.settings.appUrl = '<cfoutput>#jr_url#</cfoutput>';

    function isReady() { janrain.ready = true; };
    if (document.addEventListener) {
      document.addEventListener("DOMContentLoaded", isReady, false);
    } else {
      window.attachEvent('onload', isReady);
    }

    var e = document.createElement('script');
    e.type = 'text/javascript';
    e.id = 'janrainAuthWidget';

    if (document.location.protocol === 'https:') {
      e.src = 'https://rpxnow.com/js/lib/razuna/engage.js';
    } else {
      e.src = 'http://widget-cdn.rpxnow.com/js/lib/razuna/engage.js';
    }

    var s = document.getElementsByTagName('script')[0];
    s.parentNode.insertBefore(e, s);
})();
</script>