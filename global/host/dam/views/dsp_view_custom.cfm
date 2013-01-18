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
<div id="rightside"></div>
<!--- If attributes.show is there and it is folder --->
<cfif structKeyExists(attributes, "show")>
	<cfif attributes.show EQ "folder">
		<script type="text/javascript">
			$('##rightside').load('#myself#c.folder&col=F&folder_id=#attributes.folderid#&cv=true&fileid=#attributes.fileid#');
		</script>
	</cfif>
	<cfif attributes.show EQ "upload">
		<cfif attributes.folderid EQ "x">
			<cfset faction = "c.choose_folder">
		<cfelse>
			<cfset faction = "c.asset_add">
		</cfif>
		<script type="text/javascript">
			$('##rightside').load('#myself##faction#&col=F&folder_id=#attributes.folderid#');
		</script>
	</cfif>
</cfif>
</cfoutput>
<!--- JS: FOLDERS --->
<cfinclude template="../js/folders.cfm" runonce="true">