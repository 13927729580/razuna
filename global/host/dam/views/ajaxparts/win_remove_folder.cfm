<!---
*
* Copyright (C) 2005-2008 Razuna
*
* This file is part of Razuna - Enterprise Digital Asset Management.
*
* Razuna is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Razuna is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero Public License for more details.
*
* You should have received a copy of the GNU Affero Public License
* along with Razuna. If not, see <http://www.gnu.org/licenses/>.
*
* You may restribute this Program with a special exception to the terms
* and conditions of version 3.0 of the AGPL as described in Razuna's
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->
<!--- Define variables --->
<cfparam name="attributes.id" default="0">
<cfoutput>
<table border="0" cellpadding="5" cellspacing="5" width="100%">
	<tr>
		<td style="padding-top:10px;">#myFusebox.getApplicationData().defaults.trans("remove_folder_desc")#</td>
	</tr>
	<tr>
		<td align="right" style="padding-top:10px;"><input type="button" name="remove" value="#myFusebox.getApplicationData().defaults.trans("remove_folder")#" onclick="remfolder();" class="button"></td>
	</tr>
</table>

<script type="text/javascript">
	function remfolder(){
		// Show loading bar
		$("body").append('<div id="bodyoverlay"><img src="#dynpath#/global/host/dam/images/loading-bars.gif" border="0" style="padding:10px;"></div>');
		$('##explorer<cfif attributes.iscol EQ "T">_col</cfif>').load('#myself#c.folder_remove&folder_id=#folder_id#&iscol=<cfif attributes.iscol EQ "T">T<cfelse>F</cfif>', function() {
			setTimeout("remfolderdelay()", 1000);
		});
	}
	function remfolderdelay(){
		$('##rightside').load('#myself#ajax.remove_folder_confirm');
		destroywindow(1);
		$("##bodyoverlay").remove();
	}
</script>
</cfoutput>
<!---

onclick="destroywindow(1);loadcontent('explorer<cfif attributes.iscol EQ "T">_col</cfif>','#myself#c.folder_remove&folder_id=#folder_id#&iscol=<cfif attributes.iscol EQ "T">T<cfelse>F</cfif>');loadcontent('rightside','#myself#ajax.remove_folder_confirm');"
--->