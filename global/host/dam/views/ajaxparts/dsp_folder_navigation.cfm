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
<cfoutput>
<!---
<cfif session.folderaccess NEQ "R">
	<div style="float:left;padding-right:10px;padding-top:6px;"><a href="##" onclick="showwindow('#myself##xfa.assetadd#&folder_id=#folder_id#','#JSStringFormat(defaultsObj.trans("add_file"))#',650,1);return false;">#defaultsObj.trans("add_file")#</a></div>
</cfif>
--->
<div style="float:right;padding-top:3px;">
	<div style="float:left;" id="tooltip">
		<a href="##" onclick="loadcontent('#thediv#','#myself##thexfa#&folder_id=#folder_id#&kind=#thetype#&view=');return false;" title="Thumbnail View"><img src="#dynpath#/global/host/dam/images/view-list-icons.png" border="0" width="24" height="24"></a>
		<a href="##" onclick="loadcontent('#thediv#','#myself##thexfa#&folder_id=#folder_id#&kind=#thetype#&view=list');return false;" title="List View"><img src="#dynpath#/global/host/dam/images/view-list-text-3.png" border="0" width="24" height="24"></a>
		<a href="##" onclick="loadcontent('#thediv#','#myself##thexfa#&folder_id=#folder_id#&kind=#thetype#&view=combined');return false;" title="Combined/Quick Edit View"><img src="#dynpath#/global/host/dam/images/view-list-details-4.png" border="0" width="24" height="24"></a>
	</div>
</div>
</cfoutput>