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
		<tr>
			<td>#myFusebox.getApplicationData().defaults.trans("header_backup_restore_desc")#</td>
		</tr>
		<tr>
			<td style="background-color:yellow;font-weight:bold;">During a Backup or Restore operation your server will become unresponsive to any requests! Do these operation when no one is accessing your server.<p>We highly recommend to NOT use the backup option here, but instead use the native backup option for your database, e.g. mysqldump.</td>
		</tr>
		<tr>
			<td class="list"></td>
		</tr>
	</table>
	<!--- Backup --->
	<table border="0" cellpadding="0" cellspacing="0" width="100%" class="grid">
		<tr>
			<th>Backup</th>
		</tr>
		<tr>
			<td>#myFusebox.getApplicationData().defaults.trans("admin_maintenance_backup_desc2")#<br />
			<cfif !application.razuna.isp>#myFusebox.getApplicationData().defaults.trans("admin_maintenance_backup_desc3")#<br /></cfif>
			<br />
			<!--- Backup to: <input type="radio" name="tofiletype" id="tofiletype" value="raz" checked="checked"> Razuna format &mdash; Export to:<input type="radio" name="tofiletype" id="tofiletype" value="sql"> SQL file <input type="radio" name="tofiletype" id="tofiletype" value="xml"> XML file ---> <input type="button" name="backup" value="Backup Database Now" class="button" onclick="dobackup();"><div id="backup_progress"></div><div id="backup_dummy"></div></td>
		</tr>
	</table>
	<!--- Schedule Backup --->
	<table border="0" cellpadding="0" cellspacing="0" width="100%" class="grid">
		<tr>
			<th>Scheduled Backup</th>
		</tr>
		<tr>
			<td>
				<input type="radio" name="schedback" value="0"<cfif qry_setinterval EQ 0 OR qry_setinterval EQ ""> checked="ckecked"</cfif>> Never<br />
				<input type="radio" name="schedback" value="3600"<cfif qry_setinterval EQ 3600> checked="ckecked"</cfif>> Once Hourly<br />
				<input type="radio" name="schedback" value="21600"<cfif qry_setinterval EQ 21600> checked="ckecked"</cfif>> Twice Daily<br />
				<input type="radio" name="schedback" value="daily"<cfif qry_setinterval EQ "daily"> checked="ckecked"</cfif>> Once Daily<br />
				<input type="radio" name="schedback" value="weekly"<cfif qry_setinterval EQ "weekly"> checked="ckecked"</cfif>> Once Weekly<br /><br />
				<input type="button" name="backup" value="Save Schedule" class="button" onclick="doschedbackup();">
				<div id="schedback_dummy"></div>
			</td>
		</tr>
		<tr>
			<td class="list"></td>
		</tr>
	</table>
	<!--- Restore --->
	<table border="0" cellpadding="0" cellspacing="0" width="100%" class="grid">
		<tr>
			<th colspan="3">#myFusebox.getApplicationData().defaults.trans("admin_maintenance_restore_desc")#</th>
		</tr>
		<tr>
			<td colspan="3">#myFusebox.getApplicationData().defaults.trans("admin_maintenance_restore_desc2")#</td>
		</tr>
		<tr>
			<td><strong>Backup Date</strong></td>
			<td><strong>Restore</strong></td>
			<td><strong>Remove</strong></td>
		</tr>
		<cfloop query="qry_backup">
			<tr>
				<td>#dateformat(back_date,"mmmm dd yyyy")#, #timeformat(back_date,"HH:mm:ss")#</td>
				<td><a href="##" onclick="confirmrestore('#back_id#');">Restore</a></td>
				<td><a href="##" onclick="showwindow('#myself#ajax.remove_record&what=prefs_backup&id=#back_id#&loaddiv=backrest','#myFusebox.getApplicationData().defaults.trans("remove_selected")#',400,1);return false">Remove</a></td>
			</tr>
		</cfloop>
		<tr>
			<td colspan="3"><a href="##" onclick="loadcontent('backrest','#myself#c.prefs_backup_restore');">Refresh</a></td>
		</tr>
	</table>
	<div id="dummy_maintenance"></div>
	<!--- Div for hidden window for deleting --->
	<div id="dialog-confirm-restore" style="display:none;">
		<p><span class="ui-icon ui-icon-alert" style="float:left; margin:0 7px 100px 0;"></span>#myFusebox.getApplicationData().defaults.trans("restore_warning")#
		</p>
	</div>
	<!--- Load Progress --->
	<script language="JavaScript" type="text/javascript">
		// Do Backup
		function dobackup(){
			var tofiletype = $('input:radio[name=tofiletype]:checked').val();
			window.open('#myself#c.prefs_backup_do&tofiletype=' + tofiletype, 'winbackup', 'toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=1,resizable=1,copyhistory=no,width=500,height=500');
		}
		// Do Schedule Backup
		function doschedbackup(){
			var schedback = $('input:radio[name=schedback]:checked').val();
			loadcontent('dummy_maintenance','#myself#c.prefs_sched_backup&sched=' + schedback);
			$('##schedback_dummy').html('<span style="font-weight:bold;color:green;">#myFusebox.getApplicationData().defaults.trans("success")#</span>');
		}
		// Do Restore from filesystem
		function dorestore(backid){
			window.open('#myself#c.prefs_restore_do&back_id=' + escape(backid), 'winrestore', 'toolbar=no,location=no,directories=no,status=no,menubar=no,scrollbars=1,resizable=1,copyhistory=no,width=500,height=500');
		}

		function confirmrestore(backid){
			$( "##dialog-confirm-restore" ).dialog({
				resizable: false,
				height:250,
				modal: true,
				buttons: {
						"I understand. Begin Restore": function() {
							dorestore(backid);
							$( this ).dialog( "close" );
						},
						Cancel: function() {
							$( this ).dialog( "close" );
					}
				}
			});
	}
	</script>
</cfoutput>
