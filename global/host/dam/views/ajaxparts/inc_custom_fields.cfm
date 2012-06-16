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
	<table border="0" cellpadding="0" cellspacing="0" width="100%" class="grid">
		<cfloop query="qry_cf">
			<tr>
				<td class="td2" valign="top"><strong>#cf_text#</strong></td>
				<td class="td2">
					<!--- For text --->
					<cfif cf_type EQ "text">
						<input type="text" style="width:300px;" id="cf_#cf_id#" name="cf_#cf_id#" value="#cf_value#">
					<!--- Radio --->
					<cfelseif cf_type EQ "radio">
						<input type="radio" name="cf_#cf_id#" value="T"<cfif cf_value EQ "T"> checked="true"</cfif>>#defaultsObj.trans("yes")# <input type="radio" name="cf_#cf_id#" value="F"<cfif cf_value EQ "F" OR cf_value EQ ""> checked="true"</cfif>>#defaultsObj.trans("no")#
					<!--- Textarea --->
					<cfelseif cf_type EQ "textarea">
						<textarea name="cf_#cf_id#" style="width:300px;height:60px;">#cf_value#</textarea>
					<!--- Select --->
					<cfelseif cf_type EQ "select">
						<select name="cf_#cf_id#" style="width:300px;">
							<option value=""></option>
							<cfloop list="#cf_select_list#" index="i">
								<option value="#i#"<cfif i EQ "#cf_value#"> selected="selected"</cfif>>#i#</option>
							</cfloop>
						</select>
						
					</cfif>
				</td>
			</tr>
		</cfloop>
		<!--- Submit Button --->
		<cfif attributes.folderaccess NEQ "R">
			<tr>
				<td colspan="2">
					<div style="float:right;padding:10px;"><input type="submit" name="submit" value="#defaultsObj.trans("button_save")#" class="button"></div>
				</td>
			</tr>
		</cfif>
	</table>
</cfoutput>