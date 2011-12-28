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
<cfcomponent output="false" extends="extQueryCaching">

<!--- FUNCTION: INIT --->
<!--- in parent-cfc --->

<!--- GETTREE : GET THE FOLDERS AND SUBFOLDERS OF THIS HOST --->
<cffunction hint="GET THE FOLDERS AND SUBFOLDERS OF THIS HOST" name="getTree" output="false" access="public" returntype="query">
	<cfargument name="id" required="yes" type="string" hint="folder_id">
	<cfargument name="max_level_depth" default="0" required="false" type="numeric" hint="0 or negative numbers stand for all levels">
	<cfargument name="ColumnList" required="false" type="string" default="folder_id,folder_level,folder_name">
	<!--- this function implements only the interface & uses getTreeBy...()  --->
	<cfreturn getTreeByCollection(id=Arguments.id, max_level_depth=Arguments.max_level_depth, ColumnList=Arguments.ColumnList) />
</cffunction>

<!--- getTreeByCollection : GET THE FOLDERS AND SUBFOLDERS OF THIS HOST, WITH MORE OPTIONS --->
<cffunction name="getTreeByCollection" output="false" access="public" returntype="query">
	<cfargument name="id" required="yes" type="string" hint="folder_id">
	<cfargument name="max_level_depth" default="0" required="false" type="numeric" hint="0 or negative numbers stand for all levels">
	<cfargument name="ColumnList" required="false" type="string" default="folder_id,folder_level,folder_name">
	<cfargument name="ignoreCollections" required="no" type="boolean" default="0">
	<cfargument name="onlyCollections" required="no" type="boolean" default="0">
	<!--- init internal vars --->
	<cfset var f_1 = 0>
	<cfset var qSub = 0>
	<cfset var qRet = 0>
	<!--- Do the select --->
	<cfquery datasource="#variables.dsn#" name="f_1" cachename="#session.hostdbprefix##session.hostid##session.theuserid#getTreeByCollection#Arguments.id##Arguments.ColumnList#" cachedomain="#session.theuserid#_folders">
	SELECT #Arguments.ColumnList#,
		<!--- Permission follow but not for sysadmin and admin --->
		<cfif not Request.securityObj.CheckSystemAdminUser() and not Request.securityObj.CheckAdministratorUser()>
			CASE
				<!--- If this folder is protected with a group and this user belongs to this group --->
				WHEN EXISTS(
					SELECT fg.folder_id
					FROM #session.hostdbprefix#folders_groups fg, ct_groups_users gu
					WHERE fg.folder_id_r = f.folder_id
					AND gu.ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">
					AND gu.ct_g_u_grp_id = fg.grp_id_r
					AND lower(fg.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
					) THEN 'unlocked'
				WHEN EXISTS(
					SELECT fg2.folder_id_r
					FROM #session.hostdbprefix#folders_groups fg2 LEFT JOIN ct_groups_users gu2 ON gu2.ct_g_u_grp_id = fg2.grp_id_r AND gu2.ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">
					WHERE fg2.folder_id_r = f.folder_id
					AND lower(fg2.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
					AND fg2.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					) THEN 'unlocked'
				<!--- If this is the user folder or he is the owner --->
				WHEN ( lower(f.folder_of_user) = 't' AND f.folder_owner = '#Session.theUserID#' ) THEN 'unlocked'
				<!--- If this is the upload bin
				WHEN f.folder_id = 1 THEN 'unlocked' --->
				<!--- If this is a collection --->
				WHEN lower(f.folder_is_collection) = 't' THEN 'unlocked'
				<!--- If nothing meets the above lock the folder --->
				ELSE 'locked'
			END AS perm
		<cfelse>
			CASE
				WHEN ( lower(f.folder_of_user) = 't' AND f.folder_owner = '#Session.theUserID#' AND lower(f.folder_name) = 'my folder') THEN 'unlocked'
				WHEN ( lower(f.folder_of_user) = 't' AND lower(f.folder_name) = 'my folder') THEN 'locked'
				ELSE 'unlocked'
			END AS perm
		</cfif>
	FROM #session.hostdbprefix#folders f
	WHERE 
	<cfif Arguments.id gt 0>
		f.folder_id <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> f.folder_id_r
		AND
		f.folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Arguments.id#">
	<cfelse>
		f.folder_id = f.folder_id_r
	</cfif>
	<cfif Arguments.ignoreCollections>
		AND (f.folder_is_collection IS NULL OR folder_is_collection = '')
	</cfif>
	<cfif Arguments.onlyCollections>
		AND lower(f.folder_is_collection) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
	</cfif>
	<!--- filter user folders --->
	<!--- Does not apply to SystemAdmin users --->
	<cfif not Request.securityObj.CheckSystemAdminUser()>
		AND
			(
			LOWER(<cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2">NVL<cfelseif variables.database EQ "mysql">ifnull<cfelseif variables.database EQ "mssql">isnull</cfif>(f.folder_of_user,<cfqueryparam cfsqltype="cf_sql_varchar" value="f">)) <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
			OR f.folder_owner = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.theuserid#">
			)
	</cfif>
	AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	ORDER BY lower(folder_name)
	</cfquery>
	<!--- dummy QoQ to get correct datatypes --->
	<cfquery dbtype="query" name="qRet">
	SELECT *
	FROM f_1
	WHERE folder_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="0">
	AND perm = <cfqueryparam cfsqltype="cf_sql_varchar" value="unlocked">
	</cfquery>
	<!--- Construct the Queries together --->
	<cfloop query="f_1">
		<!--- Invoke this function again --->
		<cfif Arguments.max_level_depth neq 1>
			<cfinvoke method="getTreeByCollection" returnvariable="qSub">
				<cfinvokeargument name="id" value="#f_1.folder_id#">
				<cfinvokeargument name="max_level_depth" value="#Val(Arguments.max_level_depth-1)#">
				<cfinvokeargument name="ColumnList" value="#Arguments.ColumnList#">
				<cfinvokeargument name="ignoreCollections" value="#Arguments.ignoreCollections#">
			</cfinvoke>
		</cfif>
		<!--- Put together the query --->
		<cfquery dbtype="query" name="qRet">
		SELECT *
		FROM qRet
		UNION ALL
		SELECT *
		FROM f_1
		WHERE folder_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#f_1.folder_id#">
		AND perm = <cfqueryparam cfsqltype="cf_sql_varchar" value="unlocked">
		<cfif Arguments.max_level_depth neq 1>
			UNION ALL
			SELECT *
			FROM qSub
			WHERE perm = <cfqueryparam cfsqltype="cf_sql_varchar" value="unlocked">
		</cfif>
		</cfquery>
	</cfloop>
	<cfreturn qRet>
</cffunction>

<!--- GET FOLDER RECORD --->
<cffunction name="getfolder" output="false" access="public" description="GET FOLDER RECORD" returntype="query">
	<cfargument name="folder_id" required="yes" type="string">
	<!--- init internal vars --->
	<cfset var qLocal = 0>
	<cfquery name="qLocal" datasource="#Variables.dsn#" cachename="#session.hostdbprefix##session.hostid##session.theuserid#getfolder#Arguments.folder_id#" cachedomain="#session.theuserid#_folders">
	SELECT f.folder_id, f.folder_id_r, f.folder_name, f.folder_level, f.folder_of_user,
	f.folder_is_collection, f.folder_owner, folder_main_id_r rid, f.folder_shared, f.folder_name_shared,
	share_dl_org, share_comments, share_upload, share_order, share_order_user
	FROM #session.hostdbprefix#folders f
	WHERE folder_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Arguments.folder_id#">
	AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	<!--- *** START SECURITY *** --->
	<!--- filter user folders
	AND (
		LOWER(<cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2">NVL<cfelseif variables.database EQ "mysql">ifnull</cfif>(f.folder_of_user,<cfqueryparam cfsqltype="cf_sql_varchar" value="f">)) != <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
		OR f.folder_owner = <cfqueryparam cfsqltype="cf_sql_numeric" value="#Session.theUserID#">
	) --->
	<!--- filter folder permissions, not neccessary for SysAdmin or Admin --->
	<cfif not Request.securityObj.CheckSystemAdminUser() and not Request.securityObj.CheckAdministratorUser()>
		AND (
			<!--- R/W/X permission by group --->
			EXISTS(
				SELECT fg.GRP_ID_R,fg.GRP_PERMISSION
				FROM #session.hostdbprefix#folders_groups fg
				WHERE fg.folder_id_r = f.folder_id
				AND LOWER(fg.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="R,W,X" list="true">)
				AND fg.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				AND (
					<cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2">NVL<cfelseif variables.database EQ "mysql">ifnull<cfelseif variables.database EQ "mssql">isnull</cfif>(fg.grp_id_r, 0) = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="0">
					OR
					<!--- user in group --->
					EXISTS(
						SELECT gu.ct_g_u_grp_id, gu.ct_g_u_user_id
						FROM ct_groups_users gu
						WHERE gu.ct_g_u_grp_id = fg.grp_id_r
						AND gu.ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">
					)
				)
			)
			OR
			<!--- no group restriction --->
			NOT EXISTS(
				SELECT fg.GRP_ID_R,fg.GRP_PERMISSION
				FROM #session.hostdbprefix#folders_groups fg
				<!--- user in group --->
				INNER JOIN ct_groups_users gu ON gu.ct_g_u_grp_id = fg.grp_id_r
				WHERE gu.ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">
				AND fg.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				AND fg.folder_id_r = f.folder_id
				AND LOWER(fg.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="R,W,X" list="true">)
			)
		)
	</cfif>
	<!--- *** END SECURITY *** --->
	</cfquery>
	<cfreturn qLocal>
</cffunction>

<!--- GET FOLDER RECORD --->
<cffunction name="getfolderproperties" output="false" access="public" description="GET FOLDER RECORD" returntype="query">
	<cfargument name="folder_id" required="yes" type="string">
	<!--- init internal vars --->
	<cfset var qLocal = 0>
	<cfquery name="qLocal" datasource="#Variables.dsn#" cachename="#session.hostdbprefix##session.hostid##session.theuserid#getfolderproperties#Arguments.folder_id#" cachedomain="#session.theuserid#_folders">
	SELECT f.folder_id, f.folder_id_r, f.folder_name, f.folder_level, f.folder_of_user,
	f.folder_is_collection, f.folder_owner, folder_main_id_r rid, f.folder_shared, f.folder_name_shared,
	share_dl_org, share_comments, share_upload, share_order, share_order_user
	FROM #session.hostdbprefix#folders f
	WHERE folder_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Arguments.folder_id#">
	AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<cfreturn qLocal>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- GET THE DESCRIPTION FOR THIS FOLDER (WITH PARAGRAPHS) --->
<cffunction hint="GET THE DESCRIPTIONS FOR THIS FOLDER" name="getfolderdesc" output="false">
	<cfargument name="folder_id" required="yes" type="string">
	<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid##session.theuserid#getfolderdesc#Arguments.folder_id#" cachedomain="#session.theuserid#_folders">
	SELECT folder_desc, lang_id_r
	FROM #session.hostdbprefix#folders_desc
	WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<cfreturn qry>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- GET THE GROUPS FOR THIS FOLDER --->
<cffunction hint="GET THE GROUPS FOR THIS FOLDER" name="getfoldergroups" output="false">
	<cfargument name="folder_id" default="" required="yes" type="string">
	<cfargument name="qrygroup" required="yes" type="query">
	<!--- Set --->
	<cfset thegroups = 0>
	<!--- Query --->
	<cfif arguments.qrygroup.recordcount NEQ 0>
		<cfquery datasource="#variables.dsn#" name="thegroups" cachename="#session.hostdbprefix##session.hostid##session.theuserid#getfoldergroups#Arguments.folder_id#" cachedomain="#session.theuserid#_folders">
		SELECT grp_id_r, grp_permission
		FROM #session.hostdbprefix#folders_groups
		WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		AND grp_id_r IN (
						<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#ValueList(arguments.qrygroup.grp_id)#" list="true">
						)
		</cfquery>
	</cfif>
	<cfreturn thegroups>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- GET THE GROUPS FOR THIS FOLDER ZERO --->
<cffunction hint="GET THE GROUPS FOR THIS FOLDER ZERO" name="getfoldergroupszero" output="false">
	<cfargument name="folder_id" default="" required="yes" type="string">
	<cfquery datasource="#variables.dsn#" name="thegroups" cachename="#session.hostdbprefix##session.hostid##session.theuserid#getfoldergroupszero#Arguments.folder_id#" cachedomain="#session.theuserid#_folders">
	SELECT grp_id_r, grp_permission
	FROM #session.hostdbprefix#folders_groups
	WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
	AND grp_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="0">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<cfreturn thegroups>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- THE FOLDER LIST --->
<cffunction hint="The Folder Listing" name="folderlist" output="false" access="public" returntype="query">
	<cfargument name="folder_id" required="yes" type="string">
	<cfargument name="ignoreCollections" required="no" type="boolean" default="0">
	<cfargument name="onlyCollections" required="no" type="boolean" default="0">
	<!--- init internal vars --->
	<cfset var qLocal = 0>
	<!--- call tree-function, 1 level deep, security restrictions are there --->
	<cfinvoke method="getTreeByCollection" returnvariable="qLocal">
		<cfinvokeargument name="id" value="#Arguments.folder_id#">
		<cfinvokeargument name="max_level_depth" value="1">
		<cfinvokeargument name="ignoreCollections" value="#Arguments.ignoreCollections#">
		<cfinvokeargument name="ColumnList" value="folder_id, folder_name, folder_id_r, folder_main_id_r, folder_level, folder_owner, folder_of_user, folder_is_vid_folder, folder_is_img_folder, folder_is_collection">
		<cfinvokeargument name="onlyCollections" value="#Arguments.onlyCollections#">
	</cfinvoke>
	<cfreturn qLocal />
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- ADD A NEW FOLDER --->
<cffunction hint="Add a New Folder" name="add" output="true" returntype="string">
	<cfargument name="thestruct" type="struct">
	<cfargument name="thefolderparam" required="no" type="struct" default="#StructNew()#" hint="special argument only for call from CFC files.extractZip">
	<cfargument name="formStruct" required="no" type="struct" default="#Form#" hint="Form-struct, can be simulated.">
	<cfargument name="noTransaction" required="no" type="boolean" default="0" hint="Do not execute cftransaction. Reason: Nested cTransaction not allowed!">
	<!--- Params --->
	<cfparam default="" name="arguments.thestruct.coll_folder">
	<cfparam default="" name="arguments.thestruct.link_path">
	<!--- If this is NOT a link to a folder --->
	<cfif arguments.thestruct.link_path EQ "">
		<cftry>
			<!--- Increase folder level --->
			<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
			<!--- Check for the same name --->
			<cfquery datasource="#variables.dsn#" name="samefolder">
			SELECT folder_id
			FROM #session.hostdbprefix#folders
			WHERE lower(folder_name) = <cfqueryparam value="#lcase(arguments.thestruct.folder_name)#" cfsqltype="cf_sql_varchar">
			AND folder_level = <cfqueryparam value="#arguments.thestruct.level#" cfsqltype="cf_sql_numeric">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			<cfif arguments.thestruct.rid NEQ 0>
				AND folder_id_r = <cfqueryparam value="#arguments.thestruct.theid#" cfsqltype="CF_SQL_VARCHAR">
			</cfif>
			</cfquery>
			<!--- If folder does not already exist --->
			<cfif samefolder.recordcount EQ 0>
				<!--- Add folder --->
				<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
				<!--- If we store on the file system we create the folder here --->
				<cfif application.razuna.storage EQ "local">
					<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
					<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
					<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
					<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
					<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
				</cfif>
				<!--- Set the Action2: Fill certain arguments (folder name, collection) with supporting argument if coming from CFC files --->
				<cfif StructIsEmpty(arguments.thefolderparam)>
					<cfset this.action2="done">
				<cfelse>
					<cfset this.action2="#newfolderid#">
				</cfif>
				<!--- Return --->
				<cfreturn this.action2>
			<!--- Same Folder exists --->
			<cfelse>
				<cfif StructIsEmpty(arguments.thefolderparam)>
					<cfset this.action2="exists">
				<cfelse>
					<cfset this.action2="#samefolder.folder_id#">
				</cfif>
				<cfreturn this.action2>
			</cfif>
			<cfcatch type="any">
				<cfinvoke component="debugme" method="email_dump" emailto="support@razuna.com" emailfrom="server@razuna.com" emailsubject="Error in adding folder" dump="#cfcatch#">
			</cfcatch>
		</cftry>
	<!--- This is a link --->
	<cfelse>
		<!--- Param --->
		<cfset arguments.thestruct.link_kind = "lan">
		<cfset arguments.thestruct.dsn = variables.dsn>
		<cfset arguments.thestruct.setid = variables.setid>
		<cfset arguments.thestruct.database = variables.database>
		<!--- Increase folder level --->
		<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
		<!--- Read the name of the root folder --->
		<cfset arguments.thestruct.folder_name = listlast(arguments.thestruct.link_path,"/\")>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="arguments.thestruct.thefiles" type="file">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="arguments.thestruct.thefiles">
		SELECT *
		FROM arguments.thestruct.thefiles
		WHERE attributes != 'H'
		</cfquery>
		<!--- Param --->
		<cfset arguments.thestruct.folder_id = newfolderid>
		<!--- Thread for adding files of this folder --->
		<cfthread intstruct="#arguments.thestruct#">
			<!--- Loop over the assets --->
			<cfloop query="attributes.intstruct.thefiles">
				<!--- Params --->
				<cfset attributes.intstruct.link_path_url = directory & "/" & name>
				<cfset attributes.intstruct.orgsize = size>
				<!--- Now add the asset --->
				<cfinvoke component="assets" method="addassetlink" thestruct="#attributes.intstruct#">
			</cfloop>
		</cfthread>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirs">
		SELECT *
		FROM thedir
		WHERE attributes != 'H'
		</cfquery>
		<!--- Call rec function --->
		<cfif thesubdirs.recordcount NEQ 0>
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfthread intstruct="#arguments.thestruct#">
				<cfinvoke method="folder_link_rec" thestruct="#attributes.intstruct#">
			</cfthread>
		</cfif>
	</cfif>
</cffunction>

<!--- FOLDER LINK: Rec function to add folders --->
<cffunction name="folder_link_rec" output="true" access="private">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = directory & "/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfinvoke method="folder_link_rec_sub" thestruct="#arguments.thestruct#">
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel>
	</cfloop>
</cffunction>

<!--- FOLDER LINK: Rec function to add SUB folders --->
<cffunction name="folder_link_rec_sub" output="false" access="private" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath2 = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid2 = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel2 = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = directory & "/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfinvoke method="folder_link_rec_sub2" thestruct="#arguments.thestruct#">
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath2>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid2>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel2>
	</cfloop>
</cffunction>

<!--- FOLDER LINK: Rec function to add SUB folders --->
<cffunction name="folder_link_rec_sub2" output="false" access="private" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath3 = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid3 = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel3 = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = "#arguments.thestruct.link_path#/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfinvoke method="folder_link_rec_sub3" thestruct="#arguments.thestruct#">
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath3>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid3>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel3>
	</cfloop>
</cffunction>

<!--- FOLDER LINK: Rec function to add SUB folders --->
<cffunction name="folder_link_rec_sub3" output="false" access="private" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath4 = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid4 = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel4 = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = "#arguments.thestruct.link_path#/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfinvoke method="folder_link_rec_sub4" thestruct="#arguments.thestruct#">
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath4>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid4>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel4>
	</cfloop>
</cffunction>

<!--- FOLDER LINK: Rec function to add SUB folders --->
<cffunction name="folder_link_rec_sub4" output="false" access="private" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath5 = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid5 = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel5 = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = "#arguments.thestruct.link_path#/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfinvoke method="folder_link_rec_sub5" thestruct="#arguments.thestruct#">
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath5>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid5>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel5>
	</cfloop>
</cffunction>

<!--- FOLDER LINK: Rec function to add SUB folders --->
<cffunction name="folder_link_rec_sub5" output="false" access="private" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath6 = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid6 = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel6 = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = "#arguments.thestruct.link_path#/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfinvoke method="folder_link_rec_sub6" thestruct="#arguments.thestruct#">
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath6>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid6>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel6>
	</cfloop>
</cffunction>

<!--- FOLDER LINK: Rec function to add SUB folders --->
<cffunction name="folder_link_rec_sub6" output="false" access="private" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath7 = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid7 = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel7 = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = "#arguments.thestruct.link_path#/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfinvoke method="folder_link_rec_sub7" thestruct="#arguments.thestruct#">
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath7>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid7>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel7>
	</cfloop>
</cffunction>

<!--- FOLDER LINK: Rec function to add SUB folders --->
<cffunction name="folder_link_rec_sub7" output="false" access="private" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath8 = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid8 = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel8 = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = "#arguments.thestruct.link_path#/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<cfinvoke method="folder_link_rec_sub8" thestruct="#arguments.thestruct#">
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath8>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid8>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel8>
	</cfloop>
</cffunction>

<!--- FOLDER LINK: Rec function to add SUB folders --->
<cffunction name="folder_link_rec_sub8" output="false" access="private" returntype="void">
	<cfargument name="thestruct" type="struct">
	<!--- Check if folder has subfolders if so add them recursively --->
	<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir" type="dir">
	<!--- Filter out hidden dirs --->
	<cfquery dbtype="query" name="thesubdirs">
	SELECT *
	FROM thedir
	WHERE attributes != 'H'
	</cfquery>
	<!--- Increase folder level --->
	<cfset arguments.thestruct.level = arguments.thestruct.level + 1>
	<!--- Loop over the qry and add the folders and files within --->
	<cfloop query="thesubdirs">
		<!--- Name of folder --->
		<cfset arguments.thestruct.folder_name = name>
		<!--- Add the folder --->
		<cfinvoke method="fnew_detail" thestruct="#arguments.thestruct#" returnvariable="newfolderid">
		<!--- If we store on the file system we create the folder here --->
		<cfif application.razuna.storage EQ "local">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/img" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/vid" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/doc" mode="775">
			<cfdirectory action="create" directory="#arguments.thestruct.assetpath#/#session.hostid#/#newfolderid#/aud" mode="775">
		</cfif>
		<!--- Add the dirname to the link_path --->
		<cfset subfolderpath = "#arguments.thestruct.link_path#/#name#">
		<!--- Now add all assets of this folder --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thefiles" type="file">
		<!--- Loop over the assets --->
		<cfloop query="thefiles">
			<!--- Params --->
			<cfset arguments.thestruct.link_path_url = directory & "/" & name>
			<cfset arguments.thestruct.orgsize = size>
			<cfset arguments.thestruct.folder_id = newfolderid>
			<!--- Now add the asset --->
			<cfinvoke component="assets" method="addassetlink" thestruct="#arguments.thestruct#">
		</cfloop>
		<!--- Check if folder has subfolders if so add them recursively --->
		<cfdirectory action="list" directory="#subfolderpath#" name="thedirsub" type="dir">
		<!--- Filter out hidden dirs --->
		<cfquery dbtype="query" name="thesubdirssub">
		SELECT *
		FROM thedirsub
		WHERE attributes != 'H'
		</cfquery>
		<cfset arguments.thestruct.linkpath9 = arguments.thestruct.link_path>
		<cfset arguments.thestruct.thisfolderid9 = arguments.thestruct.theid>
		<cfset arguments.thestruct.thislevel9 = arguments.thestruct.level>
		<!--- Call rec function --->
		<cfif thesubdirssub.recordcount NEQ 0>
			<!--- Add the dirname to the link_path --->
			<cfset arguments.thestruct.link_path = "#arguments.thestruct.link_path#/#name#">
			<!--- Put folderid into struct --->
			<cfset arguments.thestruct.theid = newfolderid>
			<!--- Call function --->
			<!--- <cfinvoke method="folder_link_rec_sub4" thestruct="#arguments.thestruct#"> --->
		</cfif>
		<cfset arguments.thestruct.link_path = arguments.thestruct.linkpath9>
		<cfset arguments.thestruct.theid = arguments.thestruct.thisfolderid9>
		<cfset arguments.thestruct.level = arguments.thestruct.thislevel9>
	</cfloop>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- DETAIL OF ADD A NEW FOLDER --->
<cffunction name="fnew_detail" output="true" returntype="string" access="public">
	<cfargument name="thestruct" type="struct">
	<cfargument name="thefolderparam" required="no"  type="struct" default="#StructNew()#" hint="special argument only for call from CFC files.extractZip">
	<!--- Param --->
	<cfparam name="arguments.thestruct.coll_folder" default="f" />
	<cfparam name="arguments.thestruct.link_path" default="" />
	<cfparam name="arguments.thestruct.langcount" default="1" />
	<cfparam name="arguments.thestruct.folder_desc_1" default="" />
	<!--- Create a new ID --->
	<cfset var newfolderid = replace(createuuid(),"-","","ALL")>
	<!--- Insert --->
	<cfquery datasource="#application.razuna.datasource#">
	INSERT INTO #session.hostdbprefix#folders
	(folder_id, folder_name, folder_level, folder_id_r, folder_main_id_r, folder_owner, folder_create_date, folder_change_date,
	folder_create_time, folder_change_time, link_path, host_id
	<cfif arguments.thestruct.coll_folder EQ "T">, folder_is_collection</cfif>)
	VALUES (
	<cfqueryparam value="#newfolderid#" cfsqltype="CF_SQL_VARCHAR">,
	<cfqueryparam value="#arguments.thestruct.folder_name#" cfsqltype="cf_sql_varchar">,
	<cfqueryparam value="#arguments.thestruct.level#" cfsqltype="cf_sql_numeric">,
	<cfif arguments.thestruct.level IS NOT 1>
		<cfqueryparam value="#arguments.thestruct.theid#" cfsqltype="CF_SQL_VARCHAR">
	<cfelse>
		<cfqueryparam value="#newfolderid#" cfsqltype="CF_SQL_VARCHAR">
	</cfif>,
	<cfif Val(arguments.thestruct.rid)>
		<cfqueryparam value="#arguments.thestruct.rid#" cfsqltype="CF_SQL_VARCHAR">
	<cfelse>
		<cfqueryparam value="#newfolderid#" cfsqltype="CF_SQL_VARCHAR">
	</cfif>,
	<cfqueryparam value="#arguments.thestruct.userid#" cfsqltype="CF_SQL_VARCHAR">,
	<cfqueryparam value="#now()#" cfsqltype="cf_sql_date">,
	<cfqueryparam value="#now()#" cfsqltype="cf_sql_date">,
	<cfqueryparam value="#now()#" cfsqltype="cf_sql_timestamp">,
	<cfqueryparam value="#now()#" cfsqltype="cf_sql_timestamp">,
	<cfqueryparam value="#arguments.thestruct.link_path#" cfsqltype="cf_sql_varchar">,
	<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	<cfif arguments.thestruct.coll_folder EQ "T">
		,<cfqueryparam value="T" cfsqltype="cf_sql_varchar">
	</cfif>
	)
	</cfquery>
	<!--- Update the folder table when the id is emtpy so we have the folder_id_r and folder_main_id_r done
	<cfif #level# EQ 1>
		<cfquery datasource="#arguments.thesource#">
			UPDATE #arguments.theprefix#folders
			SET folder_id_r = <cfqueryparam value="#insertid.folder_id#" cfsqltype="cf_sql_numeric">,
			    folder_main_id_r = <cfqueryparam value="#insertid.folder_id#" cfsqltype="cf_sql_numeric">
			WHERE folder_id = <cfqueryparam value="#insertid.folder_id#" cfsqltype="cf_sql_numeric">
		</cfquery>
	</cfif> --->
	<!--- Insert the DESCRIPTION (only if not from CFC files.extractZip coming) --->
	<cfif StructIsEmpty(arguments.thefolderparam)>
		<cfloop list="#arguments.thestruct.langcount#" index="langindex">
			<cfset thisfield="arguments.thestruct.folder_desc_" & "#langindex#">
			<cfif #thisfield# CONTAINS "#langindex#">
				<cftransaction>
					<cfquery datasource="#application.razuna.datasource#">
					INSERT INTO #session.hostdbprefix#folders_desc
					(folder_id_r, lang_id_r, folder_desc, host_id, rec_uuid)
					VALUES(
					<cfqueryparam value="#newfolderid#" cfsqltype="CF_SQL_VARCHAR">,
					<cfqueryparam value="#langindex#" cfsqltype="cf_sql_numeric">,
					<cfqueryparam value="#evaluate(thisfield)#" cfsqltype="cf_sql_varchar">,
					<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">,
					<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
					)
					</cfquery>
				</cftransaction>
			</cfif>
		</cfloop>
	</cfif>
	<!--- Insert the Group and Permission --->
	<cfloop collection="#arguments.thestruct#" item="myform">
		<cfif myform CONTAINS "grp_">
			<cfset grpid = ReplaceNoCase(myform, "grp_", "")>
			<cfset grpidno = Replace(grpid, "-", "", "all")>
			<cfset theper = "per_" & "#grpidno#">
			<cftransaction>
				<cfquery datasource="#application.razuna.datasource#">
				INSERT INTO #session.hostdbprefix#folders_groups
				(folder_id_r, grp_id_r, grp_permission, host_id, rec_uuid)
				VALUES(
				<cfqueryparam value="#newfolderid#" cfsqltype="CF_SQL_VARCHAR">,
				<cfqueryparam value="#grpid#" cfsqltype="CF_SQL_VARCHAR">,
				<cfqueryparam value="#evaluate(theper)#" cfsqltype="cf_sql_varchar">,
				<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">,
				<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
				)
				</cfquery>
			</cftransaction>
		</cfif>
	</cfloop>
	<!--- Log --->
	<cfset log = #log_folders(theuserid=session.theuserid,logaction='Add',logdesc='Added: #arguments.thestruct.folder_name# (ID: #newfolderid#, Level: #arguments.thestruct.level#)')#>
	<!--- Flush Cache --->
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders" />
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_desc" />
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_groups" />
	<!--- Return --->
	<cfreturn newfolderid />
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- REMOVE THIS FOLDER ALL SUBFOLDER AND FILES WITHIN --->
<cffunction name="remove" output="true">
	<cfargument name="thestruct" type="struct">
		<!--- <cfinvoke method="remove_folder_thread" thestruct="#arguments.thestruct#" /> --->
		<!--- <cfset var tt = createuuid()> --->
		<cfthread name="#createuuid()#" intstruct="#arguments.thestruct#">
			<cfinvoke method="remove_folder_thread" thestruct="#attributes.intstruct#" />
		</cfthread>
		<!--- <cfthread action="join" name="#tt#" /> --->
	<cfreturn />
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- THREAD : REMOVE THIS FOLDER ALL SUBFOLDER AND FILES WITHIN --->
<cffunction name="remove_folder_thread" output="false">
	<cfargument name="thestruct" type="struct">
	<!--- function internal vars --->
	<cfset var foldernames = 0>
	<cfset var parentid = 0>
	<cfset var folderids = 0>
	<!--- function body --->
	<cftry>
		<!--- Get the Folder Name for the Log --->
		<cfquery datasource="#application.razuna.datasource#" name="foldername">
		SELECT folder_name, folder_level
		FROM #session.hostdbprefix#folders
		WHERE folder_id = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Get the parent folder id so we redirect correctly --->
		<cfquery datasource="#application.razuna.datasource#" name="parentid">
		SELECT folder_id_r, folder_level
		FROM #session.hostdbprefix#folders
		WHERE folder_id = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- If on top folder level then reset referenced folder id --->
		<cfif parentid.folder_level EQ 1>
			<cfset parentid.folder_id_r = 0>
		</cfif>
		<cfif foldername.recordcount NEQ 0>
			<!--- Call to get the recursive folder ids --->
			<cfinvoke method="recfolder" returnvariable="folderids">
				<cfinvokeargument name="thelist" value="#arguments.thestruct.folder_id#">
				<cfinvokeargument name="thelevel" value="#foldername.folder_level#">
			</cfinvoke>
			<!--- no looping through sub-folders or deleting in related tables, all is done by cascading foreing-keys in DB --->
			<!--- MSSQL: Drop all constraints --->
			<cfif application.razuna.thedatabase EQ "mssql">
				<cfquery datasource="#application.razuna.datasource#">
				ALTER TABLE #application.razuna.theschema#.#session.hostdbprefix#folders DROP CONSTRAINT
				</cfquery>
			<!--- MySQL --->
			<cfelseif application.razuna.thedatabase EQ "mysql">
				<cfquery datasource="#application.razuna.datasource#">
				SET foreign_key_checks = 0
				</cfquery>
			<!--- H2 --->
			<cfelseif application.razuna.thedatabase EQ "h2">
				<cfquery datasource="#application.razuna.datasource#">
				ALTER TABLE #session.hostdbprefix#folders SET REFERENTIAL_INTEGRITY false
				</cfquery>
			</cfif>
			<cfquery datasource="#application.razuna.datasource#">
			DELETE FROM	#session.hostdbprefix#folders
			WHERE folder_id = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
			<!--- Delete labels --->
			<cfinvoke component="labels" method="label_ct_remove" id="#arguments.thestruct.folder_id#" />
			<!--- Delete files in this folder --->
			<cfinvoke method="deleteassetsinfolder" thefolderid="#arguments.thestruct.folder_id#" thestruct="#arguments.thestruct#" />
			<!--- Flush Cache --->
			<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders" />
			<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_desc" />
			<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_groups" />
			<!--- Loop to remove folder --->
			<cfloop list="#folderids#" index="thefolderid" delimiters=",">
				<cfset arguments.thestruct.folder_id = thefolderid>
				<!--- Delete in Lucene --->
				<cfinvoke component="lucene" method="index_delete_folder" thestruct="#arguments.thestruct#" dsn="#application.razuna.datasource#">
				<!--- Delete folder in DB --->
				<cfquery datasource="#application.razuna.datasource#">
				DELETE FROM	#session.hostdbprefix#folders
				WHERE folder_id = <cfqueryparam value="#thefolderid#" cfsqltype="CF_SQL_VARCHAR">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<!--- Delete labels --->
				<cfinvoke component="labels" method="label_ct_remove" id="#thefolderid#" />
				<!--- Delete all files which have the same folder_id_r, meaning they have not been moved --->
				<cfinvoke method="deleteassetsinfolder" thefolderid="#thefolderid#" thestruct="#arguments.thestruct#" />
			</cfloop>
			<!--- Flush Cache --->
			<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders" />
			<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_desc" />
			<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_groups" />
			<!--- Log --->
			<cfset log = #log_folders(theuserid=session.theuserid,logaction='Delete',logdesc='Deleted: #foldername.folder_name# (ID: #arguments.thestruct.folder_id#, Level: #foldername.folder_level#)')#>
		</cfif>
		<cfcatch type="any">
			<cfmail type="html" to="support@razuna.com" from="server@razuna.com" subject="Error removing folder - #cgi.http_host#">
				<cfdump var="#cfcatch#" />
				<cfdump var="#arguments.thestruct#" />
			</cfmail>
		</cfcatch>
	</cftry>
	<!--- Return --->
	<cfreturn parentid.folder_id_r>
</cffunction>

<!--- Delete files from folder removal --->
<cffunction name="deleteassetsinfolder" output="false">
	<cfargument name="thefolderid" type="string" />
	<cfargument name="thestruct" type="struct">
	<!--- Set sessions into struct since we need them in the remove many cfc --->
	<cfset arguments.thestruct.hostdbprefix = session.hostdbprefix>
	<cfset arguments.thestruct.hostid = session.hostid>
	<cfset arguments.thestruct.theuserid = session.theuserid>
	<!--- Images --->
	<cfquery datasource="#application.razuna.datasource#" name="qryimg">
	Select img_id 
	FROM #session.hostdbprefix#images
	WHERE folder_id_r = <cfqueryparam value="#arguments.thefolderid#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<cfif qryimg.recordcount NEQ 0>
		<cfset arguments.thestruct.id = valuelist(qryimg.img_id)>
		<cfinvoke component="images" method="removeimagemany" thestruct="#arguments.thestruct#" />
	</cfif>
	<!--- Videos --->
	<cfquery datasource="#application.razuna.datasource#" name="qryvid">
	Select vid_id 
	FROM #session.hostdbprefix#videos
	WHERE folder_id_r = <cfqueryparam value="#arguments.thefolderid#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<cfif qryvid.recordcount NEQ 0>
		<cfset arguments.thestruct.id = valuelist(qryvid.vid_id)>
		<cfinvoke component="videos" method="removevideomany" thestruct="#arguments.thestruct#" />
	</cfif>
	<!--- Audios --->
	<cfquery datasource="#application.razuna.datasource#" name="qryaud">
	Select aud_id 
	FROM #session.hostdbprefix#audios
	WHERE folder_id_r = <cfqueryparam value="#arguments.thefolderid#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<cfif qryaud.recordcount NEQ 0>
		<cfset arguments.thestruct.id = valuelist(qryaud.aud_id)>
		<cfinvoke component="audios" method="removeaudiomany" thestruct="#arguments.thestruct#" />
	</cfif>
	<!--- Docs --->
	<cfquery datasource="#application.razuna.datasource#" name="qrydoc">
	Select file_id 
	FROM #session.hostdbprefix#files
	WHERE folder_id_r = <cfqueryparam value="#arguments.thefolderid#" cfsqltype="CF_SQL_VARCHAR">
	</cfquery>
	<cfif qrydoc.recordcount NEQ 0>
		<cfset arguments.thestruct.id = valuelist(qrydoc.file_id)>
		<cfinvoke component="files" method="removefilemany" thestruct="#arguments.thestruct#" />
	</cfif>
	<!--- Now check in all asset dbs again for the same folder. If we have no record anymore, remove the folder from the file system --->
	<cfquery datasource="#application.razuna.datasource#" name="qryfolder">
	SELECT img_id as id
	FROM #session.hostdbprefix#images
	WHERE path_to_asset LIKE '#arguments.thefolderid#%'
	UNION ALL
	SELECT aud_id as id
	FROM #session.hostdbprefix#audios
	WHERE path_to_asset LIKE '#arguments.thefolderid#%'
	UNION ALL
	SELECT file_id as id
	FROM #session.hostdbprefix#files
	WHERE path_to_asset LIKE '#arguments.thefolderid#%'
	UNION ALL
	SELECT vid_id as id
	FROM #session.hostdbprefix#videos
	WHERE path_to_asset LIKE '#arguments.thefolderid#%'
	</cfquery>
	<!--- If no asset is found which has this folder id in its path then it is safe to remove the folder --->
	<cfif qryfolder.recordcount EQ 0>
		<!--- Delete Folder --->
		<cfif application.razuna.storage EQ "local">
			<cfif directoryexists("#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thefolderid#")>
				<cfdirectory action="delete" directory="#arguments.thestruct.assetpath#/#session.hostid#/#arguments.thefolderid#" recurse="true">
			</cfif>
		<cfelseif application.razuna.storage EQ "nirvanix">
			<cfinvoke component="nirvanix" method="DeleteFolders" nvxsession="#arguments.thestruct.nvxsession#" folderpath="/#arguments.thefolderid#">
		<cfelseif application.razuna.storage EQ "amazon">
			<cfinvoke component="amazon" method="deletefolder" folderpath="#arguments.thefolderid#" awsbucket="#arguments.thestruct.awsbucket#" />
		</cfif>
	</cfif>
	<!--- Flush Cache --->
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_images" />
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_files" />
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_videos" />
	<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_audios" />
	<!--- Return --->
	<cfreturn />
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- SAVE FOLDER PROPERTIES --->
<cffunction name="update" output="true" returntype="string">
	<cfargument name="thestruct" type="struct">
	<!--- Param --->
	<cfset arguments.thestruct.grpno = "T">
	<cfparam name="arguments.thestruct.folder_shared" default="F">
	<cfparam name="arguments.thestruct.folder_name_shared" default="#arguments.thestruct.folder_id#">
	<cfparam name="arguments.thestruct.share_order_user" default="0">
	<!--- Check for the same name --->
	<cfquery datasource="#variables.dsn#" name="samefolder">
	SELECT folder_name
	FROM #session.hostdbprefix#folders
	WHERE lower(folder_name) = <cfqueryparam value="#lcase(arguments.thestruct.folder_name)#" cfsqltype="cf_sql_varchar">
	AND folder_level = <cfqueryparam value="#arguments.thestruct.level#" cfsqltype="cf_sql_numeric">
	AND folder_id <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2"><><cfelse>!=</cfif> <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
	AND lower(folder_of_user) <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2"><><cfelse>!=</cfif> <cfqueryparam value="t" cfsqltype="cf_sql_varchar">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- If there is not a record with the same name continue --->
	<cfif #samefolder.recordcount# EQ 0>
		<!--- Get Folder Name for the Log
		<cfquery datasource="#variables.dsn#" name="thisfolder">
			SELECT folder_name
			FROM #session.hostdbprefix#folders
			WHERE folder_id = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="cf_sql_numeric">
		</cfquery> --->
		<!--- Update Folders DB --->
		<cfquery datasource="#variables.dsn#">
		UPDATE #session.hostdbprefix#folders
		SET
		folder_name = <cfqueryparam value="#arguments.thestruct.folder_name#" cfsqltype="cf_sql_varchar">,
		folder_change_date = <cfqueryparam value="#now()#" cfsqltype="cf_sql_date">,
		folder_change_time = <cfqueryparam value="#now()#" cfsqltype="cf_sql_timestamp">,
		folder_shared = <cfqueryparam value="#arguments.thestruct.folder_shared#" cfsqltype="cf_sql_varchar">,
		folder_name_shared = <cfqueryparam value="#arguments.thestruct.folder_name_shared#" cfsqltype="cf_sql_varchar">
		<cfif structkeyexists(arguments.thestruct,"share_dl_org")>
			,
			share_dl_org = <cfqueryparam value="#arguments.thestruct.share_dl_org#" cfsqltype="cf_sql_varchar">,
			share_upload = <cfqueryparam value="#arguments.thestruct.share_upload#" cfsqltype="cf_sql_varchar">,
			share_comments = <cfqueryparam value="#arguments.thestruct.share_comments#" cfsqltype="cf_sql_varchar">,
			share_order = <cfqueryparam value="#arguments.thestruct.share_order#" cfsqltype="cf_sql_varchar">,
			share_order_user = <cfqueryparam value="#arguments.thestruct.share_order_user#" cfsqltype="CF_SQL_VARCHAR">
		</cfif>
		WHERE folder_id = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Update the Desc --->
		<cfloop list="#arguments.thestruct.langcount#" index="langindex">
			<cfset thisfield="arguments.thestruct.folder_desc_" & "#langindex#">
			<cfif #thisfield# CONTAINS "#langindex#">
				<!--- Check if description in this language exists --->
				<cfquery datasource="#variables.dsn#" name="langDesc">
				SELECT folder_id_r
				FROM #session.hostdbprefix#folders_desc
				WHERE folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
				AND lang_id_r = <cfqueryparam value="#langindex#" cfsqltype="cf_sql_numeric">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<!--- Update existing or insert new description --->
				<cfif langDesc.recordCount GT 0>
					<cfquery datasource="#variables.dsn#">
					UPDATE #session.hostdbprefix#folders_desc
					SET folder_desc = <cfqueryparam value="#evaluate(thisfield)#" cfsqltype="cf_sql_varchar">
					WHERE folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
					AND lang_id_r = <cfqueryparam value="#langindex#" cfsqltype="cf_sql_numeric">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					</cfquery>
				<cfelse>
					<cfquery datasource="#variables.dsn#">
					INSERT INTO #session.hostdbprefix#folders_desc
					(folder_id_r, lang_id_r, folder_desc, host_id, rec_uuid)
					VALUES (
					<cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">,
					<cfqueryparam value="#langindex#" cfsqltype="cf_sql_numeric">,
					<cfqueryparam value="#evaluate(thisfield)#" cfsqltype="cf_sql_varchar">,
					<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">,
					<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
					)
					</cfquery>
				</cfif>
			</cfif>
		</cfloop>
		<!--- Update the Groups --->
		<!--- First delete all the groups --->
		<cfquery datasource="#variables.dsn#">
		DELETE FROM #session.hostdbprefix#folders_groups
		WHERE folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Now add the new groups --->
		<cfloop delimiters="," index="myform" list="#arguments.thestruct.fieldnames#">
			<cfif myform CONTAINS "grp_">
				<cfset arguments.thestruct.grpno = "F">
				<cfset grpid = ReplaceNoCase(#myform#, "grp_", "", "one")>
				<cfset grpidno = Replace(grpid, "-", "", "all")>
				<cfset theper = "per_" & "#grpidno#">
				<cfquery datasource="#variables.dsn#">
				INSERT INTO #session.hostdbprefix#folders_groups
				(folder_id_r, grp_id_r, grp_permission, host_id, rec_uuid)
				VALUES(
				<cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">,
				<cfqueryparam value="#grpid#" cfsqltype="CF_SQL_VARCHAR">,
				<cfif evaluate(theper) EQ "">
					 <cfqueryparam value="R" cfsqltype="cf_sql_varchar">,
				<cfelse>
					<cfqueryparam value="#evaluate(theper)#" cfsqltype="cf_sql_varchar">,
				</cfif>
				<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">,
				<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
				)
				</cfquery>
				<!--- Set user folder to f --->
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#folders
				SET folder_of_user = <cfqueryparam value="f" cfsqltype="cf_sql_varchar">
				WHERE folder_id = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
			</cfif>
		</cfloop>
		<!--- If the user want this folder to himself then we set appropriate --->
		<cfif arguments.thestruct.grpno EQ "T">
			<!--- Set user folder to T --->
			<cfquery datasource="#variables.dsn#">
			UPDATE #session.hostdbprefix#folders
			SET folder_of_user = <cfqueryparam value="t" cfsqltype="cf_sql_varchar">
			WHERE folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfif>
		<!--- If the User wants to inherit this group/permission to subfolders then --->
		<cfif structkeyexists(arguments.thestruct,"perm_inherit")>
			<!--- Get the subfolders --->
			<cfquery datasource="#variables.dsn#" name="arguments.thestruct.qrysubfolder">
			SELECT folder_id
			FROM #session.hostdbprefix#folders
			WHERE folder_id_r = <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND folder_id <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> <cfqueryparam value="#arguments.thestruct.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
			<!--- Call recursive function to inherit permissions --->
			<!--- If there are any then call this function again --->
			<cfif arguments.thestruct.qrysubfolder.recordcount NEQ 0>
				<cfinvoke method="folderinheritperm" thestruct="#arguments.thestruct#">
			</cfif>
		</cfif>
		<!--- Log --->
		<cfset log = #log_folders(theuserid=session.theuserid,logaction='Update',logdesc='Updated: #arguments.thestruct.folder_name# (ID: #arguments.thestruct.folder_id#)')#>
		<!--- Set the Action2 var --->
		<cfset this.action2="done">
		<cfreturn this.action2>
		<!--- Flush Cache --->
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders" />
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_desc" />
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_groups" />
	<!--- Same Folder exists --->
	<cfelse>
		<cfset this.action2="exists">
		<cfreturn this.action2>
	</cfif>

</cffunction>

<!--- Change folder permissions inherited --->
<cffunction name="folderinheritperm" output="true">
	<cfargument name="thestruct" required="yes" type="struct">
		<!--- Put the query of folder ids into a list --->
		<cfset var thefolderidlist = valuelist(arguments.thestruct.qrysubfolder.folder_id)>
		<!--- First delete all the groups --->
		<cfquery datasource="#variables.dsn#">
		DELETE FROM #session.hostdbprefix#folders_groups
		WHERE folder_id_r IN (<cfqueryparam value="#thefolderidlist#" cfsqltype="CF_SQL_VARCHAR" list="true">)
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Now add the new groups --->
		<cfloop collection="#arguments.thestruct#" item="myform">
			<cfif myform CONTAINS "grp_">
				<cfset grpid = ReplaceNoCase(myform, "grp_", "")>
				<cfset grpidno = Replace(grpid, "-", "", "all")>
				<cfset theper = "per_" & "#grpidno#">
				<cfloop index="thisfolderid" list="#thefolderidlist#">
					<!--- Insert permission into folder_groups --->
					<cfquery datasource="#variables.dsn#">
					INSERT INTO #session.hostdbprefix#folders_groups
					(folder_id_r, grp_id_r, grp_permission, host_id, rec_uuid)
					VALUES(
					<cfqueryparam value="#thisfolderid#" cfsqltype="CF_SQL_VARCHAR">,
					<cfqueryparam value="#grpid#" cfsqltype="CF_SQL_VARCHAR">,
					<cfif #evaluate(theper)# EQ "">
						 <cfqueryparam value="R" cfsqltype="cf_sql_varchar">,
					<cfelse>
						<cfqueryparam value="#evaluate(theper)#" cfsqltype="cf_sql_varchar">,
					</cfif>
					<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">,
					<cfqueryparam value="#createuuid()#" CFSQLType="CF_SQL_VARCHAR">
					)
					</cfquery>
					<!--- Set user folder to f --->
					<cfquery datasource="#variables.dsn#">
					UPDATE #session.hostdbprefix#folders
					SET folder_of_user = <cfqueryparam value="f" cfsqltype="cf_sql_varchar">
					WHERE folder_id = <cfqueryparam value="#thisfolderid#" cfsqltype="CF_SQL_VARCHAR">
					AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					</cfquery>
					<!--- Query if there are any subfolder --->
					<!--- <cfquery datasource="#variables.dsn#" name="arguments.thestruct.qrysubfolder">
					SELECT folder_id
					FROM #session.hostdbprefix#folders
					WHERE folder_id_r = <cfqueryparam value="#thisfolderid#" cfsqltype="cf_sql_numeric">
					</cfquery>
					<!--- If there are any then call this function again --->
					<cfif arguments.thestruct.qrysubfolder.recordcount NEQ 0>
						<!--- Now call this method again --->
						<cfinvoke method="folderinheritperm">
							<cfinvokeargument name="thestruct" value="#arguments.thestruct#">
						</cfinvoke>
					</cfif> --->
				</cfloop>
			</cfif>
		</cfloop>
		<!--- If the user want this folder to himself then we set appropriate --->
		<cfif arguments.thestruct.grpno EQ "T">
			<!--- Set user folder to T --->
			<cfquery datasource="#variables.dsn#">
			UPDATE #session.hostdbprefix#folders
			SET folder_of_user = <cfqueryparam value="t" cfsqltype="cf_sql_varchar">
			WHERE folder_id_r IN (<cfqueryparam value="#thefolderidlist#" cfsqltype="CF_SQL_VARCHAR" list="true">)
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfif>
		<!--- Query if there are any subfolder --->
		<cfquery datasource="#variables.dsn#" name="arguments.thestruct.qrysubfolder">
		SELECT folder_id
		FROM #session.hostdbprefix#folders
		WHERE folder_id_r IN (<cfqueryparam value="#thefolderidlist#" cfsqltype="CF_SQL_VARCHAR" list="true">)
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- If there are any then call this function again --->
		<cfif arguments.thestruct.qrysubfolder.recordcount NEQ 0>
			<!--- Now call this method again --->
			<cfinvoke method="folderinheritperm">
				<cfinvokeargument name="thestruct" value="#arguments.thestruct#">
			</cfinvoke>
		</cfif>
		<!--- 
		<!--- If the user want this folder to himself then we set appropriate --->
		<cfif arguments.thestruct.grpno EQ "T">
			<!--- Set user folder to T --->
			<cfquery datasource="#variables.dsn#">
			UPDATE #session.hostdbprefix#folders
			SET folder_of_user = <cfqueryparam value="t" cfsqltype="cf_sql_varchar">
			WHERE folder_id_r IN (<cfqueryparam value="#arguments.thestruct.qrysubfolder.folder_id#" cfsqltype="CF_SQL_VARCHAR" list="true">)
			</cfquery>
			<!--- Query if there are any subfolder --->
			<cfquery datasource="#variables.dsn#" name="arguments.thestruct.qrysubfolder">
			SELECT folder_id
			FROM #session.hostdbprefix#folders
			WHERE folder_id_r IN (<cfqueryparam value="#arguments.thestruct.qrysubfolder.folder_id#" cfsqltype="CF_SQL_VARCHAR" list="true">)
			</cfquery>
			<!--- If there are any then call this function again --->
			<cfif arguments.thestruct.qrysubfolder.recordcount NEQ 0>
				<!--- Now call this method again --->
				<cfinvoke method="folderinheritperm">
					<cfinvokeargument name="thestruct" value="#arguments.thestruct#">
				</cfinvoke>
			</cfif>
		</cfif> --->
		<!--- Flush Cache --->
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders" />
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders_groups" />
	<cfreturn />
</cffunction>

<!--- Call from API to filetotalcount --->
<cffunction name="apifiletotalcount" output="false">
	<cfargument name="folder_id" default="" required="yes" type="string">
	<cfargument name="apidsn" default="F" required="yes" type="string">
	<cfargument name="apiprefix" default="F" required="yes" type="string">
	<cfargument name="apidatabase" default="F" required="yes" type="string">
	<cfargument name="host_id" default="" required="yes" type="numeric">
	<!--- Set Values --->
	<cfset session.showsubfolders = "F">
	<cfset variables.dsn = arguments.apidsn>
	<cfset session.hostdbprefix = arguments.apiprefix>
	<cfset application.razuna.thedatabase = arguments.apidatabase>
	<cfset session.hostid = arguments.host_id>
	<cfset session.theuserid = arguments.host_id>
	<!--- Call function --->
	<cfinvoke method="filetotalcount" folder_id="#arguments.folder_id#" theoverall="F" returnvariable="total">
	<!--- Return --->
	<cfreturn total>
</cffunction>

<!--- Call from API to filetotaltype --->
<cffunction name="apifiletotaltype" output="false">
	<cfargument name="folder_id" default="" required="yes" type="string">
	<cfargument name="apidsn" default="F" required="yes" type="string">
	<cfargument name="apiprefix" default="F" required="yes" type="string">
	<cfargument name="apidatabase" default="F" required="yes" type="string">
	<cfargument name="host_id" default="" required="yes" type="numeric">
	<!--- Set Values --->
	<cfset session.showsubfolders = "F">
	<cfset variables.dsn = arguments.apidsn>
	<cfset session.hostdbprefix = arguments.apiprefix>
	<cfset application.razuna.thedatabase = arguments.apidatabase>
	<cfset session.hostid = arguments.host_id>
	<cfset session.theuserid = arguments.host_id>
	<!--- Set struct --->
	<cfset totaltypes = structnew()>
	<cfset arguments.thestruct = structnew()>
	<cfset arguments.thestruct.folder_id = arguments.folder_id>
	<!--- Call function for IMG --->
	<cfset arguments.thestruct.kind = "img">
	<cfinvoke method="filetotaltype" thestruct="#arguments.thestruct#" returnvariable="totalimg">
	<cfset totaltypes.img = totalimg.thetotal>
	<!--- Call function for VID --->
	<cfset arguments.thestruct.kind = "vid">
	<cfinvoke method="filetotaltype" thestruct="#arguments.thestruct#" returnvariable="totalvid">
	<cfset totaltypes.vid = totalvid.thetotal>
	<!--- Call function for AUD --->
	<cfset arguments.thestruct.kind = "aud">
	<cfinvoke method="filetotaltype" thestruct="#arguments.thestruct#" returnvariable="totalaud">
	<cfset totaltypes.aud = totalaud.thetotal>
	<!--- Call function for DOC --->
	<cfset arguments.thestruct.kind = "doc">
	<cfinvoke method="filetotaltype" thestruct="#arguments.thestruct#" returnvariable="totaldoc">
	<cfset totaltypes.doc = totaldoc.thetotal>
	<!--- Return --->
	<cfreturn totaltypes>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- HOW MANY FILES ARE IN TOTAL IN THIS FOLDER --->
<cffunction name="filetotalcount" output="false">
	<cfargument name="folder_id" default="" required="yes" type="string">
	<cfargument name="theoverall" default="F" required="no" type="string">
	<!--- Show assets from subfolders or not --->
	<cfif session.showsubfolders EQ "T">
		<cfinvoke method="getfoldersinlist" dsn="#variables.dsn#" folder_id="#arguments.folder_id#" database="#variables.database#" hostid="#session.hostid#" returnvariable="thefolders">
		<cfset thefolderlist = arguments.folder_id & "," & ValueList(thefolders.folder_id)>
	<cfelse>
		<cfset thefolderlist = arguments.folder_id & ",">
	</cfif>
	<!--- Query --->	
	<cfquery datasource="#variables.dsn#" name="total" cachename="#session.hostdbprefix##session.hostid#filetotalcount#arguments.folder_id#" cachedomain="#session.theuserid#_folders">
	SELECT
		(
		SELECT count(fi.file_id)
		FROM #session.hostdbprefix#files fi, #session.hostdbprefix#folders f
		WHERE fi.folder_id_r = f.folder_id 
		AND (f.folder_is_collection IS NULL OR folder_is_collection = '')
		AND fi.folder_id_r IS NOT NULL
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		AND fi.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<cfif arguments.theoverall EQ "F">
			AND fi.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		</cfif>
		)
		+
		(
		SELECT count(i.img_id)
		FROM #session.hostdbprefix#images i, #session.hostdbprefix#folders f
		WHERE i.folder_id_r = f.folder_id 
		AND (f.folder_is_collection IS NULL OR folder_is_collection = '')
		AND (i.img_group IS NULL OR i.img_group = '')
		AND i.folder_id_r IS NOT NULL
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		AND i.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<cfif arguments.theoverall EQ "F">
			AND i.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		</cfif>
		)
		+
		(
		SELECT count(v.vid_id)
		FROM #session.hostdbprefix#videos v, #session.hostdbprefix#folders f
		WHERE v.folder_id_r = f.folder_id 
		AND (f.folder_is_collection IS NULL OR folder_is_collection = '')
		AND (v.vid_group IS NULL OR v.vid_group = '')
		AND v.folder_id_r IS NOT NULL
		AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<cfif arguments.theoverall EQ "F">
			AND v.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		</cfif>
		) 
		+
		(
		SELECT count(a.aud_id)
		FROM #session.hostdbprefix#audios a, #session.hostdbprefix#folders f
		WHERE a.folder_id_r = f.folder_id 
		AND (f.folder_is_collection IS NULL OR folder_is_collection = '')
		AND (a.aud_group IS NULL OR a.aud_group = '')
		AND a.folder_id_r IS NOT NULL
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<cfif arguments.theoverall EQ "F">
			AND a.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		</cfif>
		) as
		thetotal
		<cfif application.razuna.thedatabase EQ "db2">
			FROM sysibm.sysdummy1
		<cfelseif application.razuna.thedatabase NEQ "mssql">
			FROM dual
		</cfif>
	</cfquery>
	<cfreturn total>
</cffunction>

<!--- GET COUNT OF FILE TYPES --->
<cffunction name="filetotaltype" output="false">
	<cfargument name="thestruct" required="yes" type="struct">
	<!--- Show assets from subfolders or not --->
	<cfif session.showsubfolders EQ "T">
		<cfinvoke method="getfoldersinlist" dsn="#variables.dsn#" folder_id="#arguments.thestruct.folder_id#" database="#variables.database#" hostid="#session.hostid#" returnvariable="thefolders">
		<cfset thefolderlist = arguments.thestruct.folder_id & "," & ValueList(thefolders.folder_id)>
	<cfelse>
		<cfset thefolderlist = arguments.thestruct.folder_id & ",">
	</cfif>
	<!--- Images --->
	<cfif arguments.thestruct.kind EQ "img">
		<cfquery datasource="#variables.dsn#" name="total" cachename="img#session.hostdbprefix##session.hostid#filetotaltype#arguments.thestruct.folder_id#" cachedomain="#session.theuserid#_images">
		SELECT count(img_id) as thetotal
		FROM #session.hostdbprefix#images
		WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND (img_group IS NULL OR img_group = '')
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	<!--- Videos --->
	<cfelseif arguments.thestruct.kind EQ "vid">
		<cfquery datasource="#variables.dsn#" name="total" cachename="vid#session.hostdbprefix##session.hostid#filetotaltype#arguments.thestruct.folder_id#" cachedomain="#session.theuserid#_videos">
		SELECT count(vid_id) as thetotal
		FROM #session.hostdbprefix#videos
		WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND (vid_group IS NULL OR vid_group = '')
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	<!--- Audios --->
	<cfelseif arguments.thestruct.kind EQ "aud">
		<cfquery datasource="#variables.dsn#" name="total" cachename="aud#session.hostdbprefix##session.hostid#filetotaltype#arguments.thestruct.folder_id#" cachedomain="#session.theuserid#_audios">
		SELECT count(aud_id) as thetotal
		FROM #session.hostdbprefix#audios
		WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND (aud_group IS NULL OR aud_group = '')
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	<!--- All Docs in this folder --->
	<cfelseif arguments.thestruct.kind EQ "doc">
		<cfquery datasource="#variables.dsn#" name="total" cachename="doc#session.hostdbprefix##session.hostid#filetotaltype#arguments.thestruct.folder_id#" cachedomain="#session.theuserid#_files">
		SELECT count(file_id) as thetotal
		FROM #session.hostdbprefix#files
		WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	<!--- Files --->
	<cfelse>
		<cfquery datasource="#variables.dsn#" name="total" cachename="doc#session.hostid##session.hostdbprefix#filetotaltype#arguments.thestruct.folder_id##arguments.thestruct.kind#" cachedomain="#session.theuserid#_files">
		SELECT count(file_id) as thetotal
		FROM #session.hostdbprefix#files
		WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		AND 
		<cfif arguments.thestruct.kind NEQ "other">
			(
			lower(file_extension) = <cfqueryparam value="#arguments.thestruct.kind#" cfsqltype="cf_sql_varchar">
			OR lower(file_extension) = <cfqueryparam value="#arguments.thestruct.kind#x" cfsqltype="cf_sql_varchar">
			)
		<cfelse>
			lower(file_extension) NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="doc,xls,docx,xlsx,pdf" list="true">)
		</cfif>
		</cfquery>
	</cfif>
	<!--- Return --->
	<cfreturn total>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- CREATE QUERY TABLE WITH AMOUNT OF DIFFERENT FILE TYPES FOR TAB DISPLAY --->
<cffunction name="fileTotalAllTypes" output="false" hint="CREATE QUERY TABLE WITH AMOUNT OF DIFFERENT FILE TYPES FOR TAB DISPLAY">
	<cfargument name="folder_id" default="" required="yes" type="string">
	<cfquery datasource="#variables.dsn#" name="qTab" cachename="#session.hostdbprefix##session.hostid#fileTotalAllTypes#arguments.folder_id#" cachedomain="#session.theuserid#_assets">
		SELECT 'doc' as ext, count(file_id) as cnt, 'doc' as typ, 'tab_word' as scr
		FROM #session.hostdbprefix#files
		WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
		AND SUBSTR<cfif variables.database EQ "mssql">ING</cfif>(file_extension,1,3) = 'doc'
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		UNION ALL
			SELECT 'xls' as ext, count(file_id) as cnt, 'doc' as typ, 'tab_excel' as scr
			FROM #session.hostdbprefix#files
			WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND SUBSTR<cfif variables.database EQ "mssql">ING</cfif>(file_extension,1,3) = 'xls'
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		UNION ALL
			SELECT 'pdf' as ext, count(file_id) as cnt, 'doc' as typ, 'tab_pdf' as scr
			FROM #session.hostdbprefix#files
			WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND SUBSTR<cfif variables.database EQ "mssql">ING</cfif>(file_extension,1,3) = 'pdf'
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		UNION ALL
			SELECT 'other' as ext, count(file_id) as cnt, 'doc' as typ, 'tab_others' as scr
			FROM #session.hostdbprefix#files
			WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND ((SUBSTR<cfif variables.database EQ "mssql">ING</cfif>(file_extension,1,3) <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2"><><cfelse>!=</cfif> 'doc'
			AND SUBSTR<cfif variables.database EQ "mssql">ING</cfif>(file_extension,1,3) <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2"><><cfelse>!=</cfif> 'xls'
			AND file_extension <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2"><><cfelse>!=</cfif> 'pdf')
			OR  file_type = 'other')
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		UNION ALL
			SELECT 'img' as ext, count(img_id) as cnt, 'img' as typ, 'tab_images' as scr
			FROM #session.hostdbprefix#images
			WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND (img_group IS NULL OR img_group = '')
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		UNION ALL
			SELECT 'vid' as ext, count(vid_id) as cnt, 'vid' as typ, 'tab_videos' as scr
			FROM #session.hostdbprefix#videos
			WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND (vid_group IS NULL OR vid_group = '')
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		UNION ALL
			SELECT 'aud' as ext, count(aud_id) as cnt, 'aud' as typ, 'tab_audios' as scr
			FROM #session.hostdbprefix#audios
			WHERE folder_id_r = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
			AND (aud_group IS NULL OR aud_group = '')
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		ORDER BY cnt DESC, scr
	</cfquery>

	<cfreturn qTab>

</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- SET ACCESS PERMISSION --->
<cffunction hint="SET ACCESS PERMISSION" name="setaccess" output="true">
	<cfargument name="folder_id" default="" required="yes" type="string">
	<cfquery datasource="#variables.dsn#" name="fprop" cachename="#session.hostdbprefix##session.hostid#setaccess#arguments.folder_id#" cachedomain="#session.theuserid#_folders">
	SELECT f.folder_name, f.folder_owner, fg.grp_id_r, fg.grp_permission
	FROM #session.hostdbprefix#folders f LEFT JOIN #session.hostdbprefix#folders_groups fg ON f.folder_id = fg.folder_id_r AND f.host_id = fg.host_id
	WHERE f.folder_id = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
	AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- If there is no session for webgroups set --->
	<cfparam default="" name="session.webgroups">
	<!--- Set the access rights for this folder --->
	<cfset session.folderaccess = "n">
	<cfloop query="fprop">
		<!--- if the groupid is emtpy --->
		<cfif grp_id_r EQ "">
			<cfset session.folderaccess = "n">
		<!--- if the groupid is set to all --->
		<cfelseif grp_id_r EQ 0>
			<cfset session.folderaccess = "#grp_permission#">
		<!--- if we find the groupid in the webgroups of this user --->
		<cfelseif listfind(session.webgroups, "#grp_id_r#")>
			<!--- see if this session var is already set from another group and let the group with the better permission set the petter permission --->
			<cfif session.folderaccess EQ "n">
				<cfset session.folderaccess = "#grp_permission#">
			<cfelseif session.folderaccess EQ "R" AND grp_permission EQ "W">
				<cfset session.folderaccess = "#grp_permission#">
			<cfelseif session.folderaccess EQ "W" AND grp_permission EQ "X">
				<cfset session.folderaccess = "#grp_permission#">
			</cfif>
		<cfelse>
			<cfset session.folderaccess = "#grp_permission#">
		</cfif>
	</cfloop>
	<!--- If the user is a sys or admin or the owner of the folder give full access --->
	<cfif (Request.securityObj.CheckSystemAdminUser() OR Request.securityObj.CheckAdministratorUser()) OR fprop.folder_owner EQ session.theuserid>
		<cfset session.folderaccess = "x">
	</cfif>
	<cfreturn fprop.folder_name />
</cffunction>

<!--- THE FOLDERS OF THIS HOST --------------------------------------------------->
<cffunction name="getserverdir" output="true">
	<cfargument name="thepath"      type="string"  default="">
	<cfdirectory action="list" directory="#arguments.thepath#" name="thedirs" sort="name ASC">
	<!--- exclude special folders --->
	<cfquery name="folderlist" dbtype="query">
		SELECT *
		FROM thedirs
		WHERE type = 'Dir'
		AND lower(name) NOT IN (<cfqueryparam cfsqltype="cf_sql_varchar" list="true" value="outgoing,js,images,.svn,parsed,model,controller,translations,views,.DS_Store,bluedragon,global,incoming,web-inf">)
	</cfquery>
	<cfreturn folderlist>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- MOVE THE FOLDER TO THE GIVEN POSITION --->
<cffunction hint="MOVE THE FOLDER TO THE GIVEN POSITION" name="move" output="true">
	<cfargument name="thestruct" type="struct">
	<!--- Wrap this in with a try catch --->
	<cftry>
		<!--- If there is a 0 in intolevel we assume the folder is coming from level 1, thus assign level 1 so 
		we can increase the level further down in the code --->
		<cfif arguments.thestruct.intolevel EQ 0>
			<cfset arguments.thestruct.intolevel = 1>
		</cfif>
		<!--- Get the Folder Name/Folder Level for the Log --->
		<cfquery datasource="#variables.dsn#" name="foldername">
		SELECT folder_name, folder_level
		FROM #session.hostdbprefix#folders
		WHERE folder_id = <cfqueryparam value="#arguments.thestruct.tomovefolderid#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Call the compontent above to get the recursive folder ids --->
		<cfinvoke method="recfolder" returnvariable="folderids">
			<cfinvokeargument name="thelist" value="#arguments.thestruct.tomovefolderid#">
			<cfinvokeargument name="thelevel" value="#foldername.folder_level#">
		</cfinvoke>
		<!--- Take the results from the compontent call above and add the root folder id --->
		<cfset folderids="#folderids#">
		<!--- Get the folder_main_id_r from the folder we move the folder in --->
		<cfquery datasource="#variables.dsn#" name="thenewrootid">
		SELECT folder_main_id_r, folder_name, folder_level
		FROM #session.hostdbprefix#folders
		WHERE folder_id = <cfqueryparam value="#arguments.thestruct.intofolderid#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Change the folder_id_r of the folder we want to move --->
		<cfquery datasource="#variables.dsn#">
		UPDATE #session.hostdbprefix#folders
		SET folder_id_r = <cfqueryparam value="#arguments.thestruct.intofolderid#" cfsqltype="CF_SQL_VARCHAR">, 
		folder_main_id_r = <cfif #arguments.thestruct.intolevel# EQ 1><cfqueryparam value="#arguments.thestruct.intofolderid#" cfsqltype="CF_SQL_VARCHAR"><cfelse><cfqueryparam value="#thenewrootid.folder_main_id_r#" cfsqltype="CF_SQL_VARCHAR"></cfif>
		WHERE folder_id = <cfqueryparam value="#arguments.thestruct.tomovefolderid#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
		<!--- Now loop trough the folderids and change the folder_main_id_r and the folder_level --->
		<cfloop list="#folderids#" index="thenr" delimiters=",">
			<cfset arguments.thestruct.intolevel = arguments.thestruct.intolevel + 1>
			<cfquery datasource="#variables.dsn#">
			UPDATE #session.hostdbprefix#folders
			SET folder_main_id_r = <cfif #arguments.thestruct.intolevel# EQ 1><cfqueryparam value="#arguments.thestruct.intofolderid#" cfsqltype="CF_SQL_VARCHAR"><cfelse><cfqueryparam value="#thenewrootid.folder_main_id_r#" cfsqltype="CF_SQL_VARCHAR"></cfif>,
			folder_level = <cfqueryparam value="#arguments.thestruct.intolevel#" cfsqltype="cf_sql_numeric"><!--- folder_level + #arguments.thestruct.difflevel# --->
			WHERE folder_id = <cfqueryparam value="#thenr#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfloop>
		<!--- Log --->
		<cfset log = #log_folders(theuserid=session.theuserid,logaction='Move',logdesc='Moved: #foldername.folder_name# (ID: #arguments.thestruct.tomovefolderid#, Level: #foldername.folder_level#)')#>
		<!--- Flush Cache --->
		<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_folders" />
	<!--- Ups something went wrong --->
	<cfcatch type="any">
		<cfmail type="html" to="support@razuna.com" from="server@razuna.com" subject="error folder move - #cgi.HTTP_HOST#">
			<cfdump var="#arguments.thestruct#" />
		</cfmail>
	</cfcatch>
	</cftry>
	<cfreturn />
</cffunction>

<!--- RECURSIVE SUBQUERY TO READ FOLDERS --->
<cffunction name="recfolder" output="false" access="public" returntype="string">
	<cfargument name="thelist" required="yes" hint="list of parent folder-ids">
	<cfargument name="thelevel" required="false" hint="the level">
	<!--- function internal vars --->
	<cfset var local_query = 0>
	<cfset var local_list = "">
	<!--- Query --->
	<cfquery datasource="#application.razuna.datasource#" name="local_query">
	SELECT folder_id, folder_level
	FROM #session.hostdbprefix#folders
	WHERE folder_id_r IN (<cfqueryparam value="#arguments.thelist#" cfsqltype="CF_SQL_VARCHAR" list="true">)
	AND folder_level <cfif application.razuna.thedatabase EQ "oracle" OR application.razuna.thedatabase EQ "h2" OR application.razuna.thedatabase EQ "db2"><><cfelse>!=</cfif> <cfqueryparam value="1" cfsqltype="cf_sql_numeric">
	<!--- AND folder_level <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2"><><cfelse>!=</cfif> <cfqueryparam value="#arguments.thelevel#" cfsqltype="cf_sql_numeric"> --->
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- get child-folders of next level but only if this is not the same folder_id. This fixes a bug some experiences where folders would not get removed --->
	<cfif local_query.RecordCount NEQ 0 AND arguments.thelist NEQ local_query.folder_id>
		<cfinvoke method="recfolder" returnvariable="local_list">
			<cfinvokeargument name="thelist" value="#ValueList(local_query.folder_id)#">
			<cfinvokeargument name="thelevel" value="#local_query.folder_level#">
		</cfinvoke>
		<cfset Arguments.thelist = Arguments.thelist & "," & local_list>
	</cfif>
	<cfreturn Arguments.thelist>
</cffunction>

<!--- GET FOLDER OF USER --------------------------------------------------->
<cffunction name="getuserfolder" output="false">
	<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid##session.theuserid#getuserfolder" cachedomain="#session.theuserid#_folders">
		SELECT folder_id
		FROM #session.hostdbprefix#folders
		WHERE lower(folder_of_user) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
		AND folder_owner = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.theuserid#">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	<cfreturn qry.folder_id>
</cffunction>

<!--- ------------------------------------------------------------------------------------- --->
<!--- Get all assets of this folder --->
<cffunction name="getallassets" output="true" returnType="query">
	<cfargument name="thestruct" type="struct" required="true">
	<!--- Set pages var --->
	<cfparam name="arguments.thestruct.pages" default="">
	<cfparam name="arguments.thestruct.thisview" default="">
	<!--- Show assets from subfolders or not --->
	<cfif session.showsubfolders EQ "T">
		<cfinvoke method="getfoldersinlist" dsn="#variables.dsn#" folder_id="#arguments.thestruct.folder_id#" database="#variables.database#" hostid="#session.hostid#" returnvariable="thefolders">
		<cfset thefolderlist = arguments.thestruct.folder_id & "," & ValueList(thefolders.folder_id)>
	<cfelse>
		<cfset thefolderlist = arguments.thestruct.folder_id & ",">
	</cfif>
	<!--- 
	This is for Oracle and MSQL
	Calculate the offset .Show the limit only if pages is null or current (from print) 
	--->
	<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
		<cfif arguments.thestruct.offset EQ 0>
			<cfset var min = 0>
			<cfset var max = arguments.thestruct.rowmaxpage>
		<cfelse>
			<cfset var min = arguments.thestruct.offset * arguments.thestruct.rowmaxpage>
			<cfset var max = (arguments.thestruct.offset + 1) * arguments.thestruct.rowmaxpage>
			<cfif variables.database EQ "db2">
				<cfset min = min + 1>
			</cfif>
		</cfif>
	<cfelse>
		<cfset var min = 0>
		<cfset var max = 1000>
	</cfif>
	<!--- Oracle --->
	<cfif variables.database EQ "oracle">
		<!--- Query --->
		<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid#getallassets#arguments.thestruct.folder_id##theoffset##max##arguments.thestruct.thisview#" cachedomain="#session.theuserid#_assets">
		SELECT rn, id, filename, folder_id_r, ext, filename_org, kind, date_create, date_change, link_kind, link_path_url,
		path_to_asset, cloud_url, cloud_url_org, description, keywords
		FROM (
			SELECT ROWNUM AS rn, id, filename, folder_id_r, ext, filename_org, kind, date_create, date_change, link_kind, 
			link_path_url, path_to_asset, cloud_url, cloud_url_org, description, keywords
			FROM (
				SELECT i.img_id id, i.img_filename filename, i.folder_id_r, i.thumb_extension ext, i.img_filename_org filename_org, 
				'img' as kind, i.img_create_date, i.img_create_time date_create, i.img_change_date date_change, 
				i.link_kind, i.link_path_url, i.path_to_asset, i.cloud_url, i.cloud_url_org,
				it.img_description description, it.img_keywords keywords, '0' as vheight, '0' as vwidth,
				(
					SELECT so.asset_format
					FROM #session.hostdbprefix#share_options so
					WHERE i.img_id = so.group_asset_id
					AND so.folder_id_r = i.folder_id_r
					AND so.asset_type = 'img'
					AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
				) AS theformat
				FROM #session.hostdbprefix#images i LEFT JOIN #session.hostdbprefix#images_text it ON i.img_id = it.img_id_r AND it.lang_id_r = 1
				WHERE i.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND (i.img_group IS NULL OR i.img_group = '')
				AND i.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				UNION ALL
				SELECT v.vid_id id, v.vid_filename filename, v.folder_id_r, v.vid_extension ext, v.vid_name_image filename_org, 
				'vid' as kind, v.vid_create_time date_create, v.vid_change_date date_change, v.link_kind, v.link_path_url,
				v.path_to_asset, v.cloud_url, v.cloud_url, vt.vid_description description, vt.vid_keywords keywords, v.vid_height as vheight, v.vid_width as vwidth,
				(
					SELECT so.asset_format
					FROM #session.hostdbprefix#share_options so
					WHERE v.vid_id = so.group_asset_id
					AND so.folder_id_r = v.folder_id_r
					AND so.asset_type = 'vid'
					AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
				) AS theformat
				FROM #session.hostdbprefix#videos v LEFT JOIN #session.hostdbprefix#videos_text vt ON v.vid_id = vt.vid_id_r AND vt.lang_id_r = 1
				WHERE v.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#CF_SQL_VARCHAR#" list="true">)
				AND (v.vid_group IS NULL OR v.vid_group = '')
				AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				UNION ALL
				SELECT f.file_id id, f.file_name filename, f.folder_id_r, f.file_extension ext, f.file_name_org filename_org, 
				f.file_type as kind, f.file_create_time date_create, f.file_change_date date_change, f.link_kind, 
				f.link_path_url, f.path_to_asset, f.cloud_url, f.cloud_url,
				ft.file_desc description, ft.file_keywords keywords, '0' as vheight, '0' as vwidth, '0' as theformat
				FROM #session.hostdbprefix#files f LEFT JOIN #session.hostdbprefix#files_desc ft ON f.file_id = ft.file_id_r AND ft.lang_id_r = 1
				WHERE f.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				UNION ALL
				SELECT a.aud_id id, a.aud_name filename, a.folder_id_r, a.aud_extension ext, a.aud_name_org filename_org, 
				a.aud_type as kind, a.aud_create_time date_create, a.aud_change_date date_change, a.link_kind, 
				a.link_path_url, a.path_to_asset, a.cloud_url, i.cloud_url_org
				aut.aud_description description, aut.aud_keywords keywords, '0' as vheight, '0' as vwidth,
				(
					SELECT so.asset_format
					FROM #session.hostdbprefix#share_options so
					WHERE a.aud_id = so.group_asset_id
					AND so.folder_id_r = a.folder_id_r
					AND so.asset_type = 'aud'
					AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
				) AS theformat
				FROM #session.hostdbprefix#audios a LEFT JOIN #session.hostdbprefix#audios_text aut ON a.aud_id = aut.aud_id_r AND aut.lang_id_r = 1
				WHERE a.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				ORDER BY filename
				)
			WHERE ROWNUM <= <cfqueryparam cfsqltype="cf_sql_numeric" value="#max#">
			)
		WHERE rn > <cfqueryparam cfsqltype="cf_sql_numeric" value="#min#">
		</cfquery>
	<!--- DB2 --->
	<cfelseif variables.database EQ "db2">
		<!--- Query --->
		<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid#getallassets#arguments.thestruct.folder_id##theoffset##max##arguments.thestruct.thisview#" cachedomain="#session.theuserid#_assets">
		SELECT id, filename, folder_id_r, ext, filename_org, kind, is_available, date_create, date_change, link_kind, link_path_url,
		path_to_asset, cloud_url, cloud_url_org, description, keywords
		FROM (
			SELECT row_number() over() as rownr, i.img_id id, i.img_filename filename, 
			i.folder_id_r, i.thumb_extension ext, i.img_filename_org filename_org, 'img' as kind, i.is_available,
			i.img_create_time date_create, i.img_change_date date_change, i.link_kind, i.link_path_url,
			i.path_to_asset, i.cloud_url, i.cloud_url_org, it.img_description description, it.img_keywords keywords, '0' as vheight, '0' as vwidth,
			(
				SELECT so.asset_format
				FROM #session.hostdbprefix#share_options so
				WHERE i.img_id = so.group_asset_id
				AND so.folder_id_r = i.folder_id_r
				AND so.asset_type = 'img'
				AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
			) AS theformat
			FROM #session.hostdbprefix#images i LEFT JOIN #session.hostdbprefix#images_text it ON i.img_id = it.img_id_r AND it.lang_id_r = 1
			WHERE i.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
			AND (i.img_group IS NULL OR i.img_group = '')
			AND i.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			UNION ALL
			SELECT row_number() over() as rownr, v.vid_id id, v.vid_filename filename, v.folder_id_r, 
			v.vid_extension ext, v.vid_name_image filename_org, 'vid' as kind, v.is_available,
			v.vid_create_time date_create, v.vid_change_date date_change, v.link_kind, v.link_path_url,
			v.path_to_asset, v.cloud_url, v.cloud_url_org, vt.vid_description description, vt.vid_keywords keywords, v.vid_height as vheight, v.vid_width as vwidth,
			(
				SELECT so.asset_format
				FROM #session.hostdbprefix#share_options so
				WHERE v.vid_id = so.group_asset_id
				AND so.folder_id_r = v.folder_id_r
				AND so.asset_type = 'vid'
				AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
			) AS theformat
			FROM #session.hostdbprefix#videos v LEFT JOIN #session.hostdbprefix#videos_text vt ON v.vid_id = vt.vid_id_r AND vt.lang_id_r = 1
			WHERE v.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
			AND (v.vid_group IS NULL OR v.vid_group = '')
			AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			UNION ALL
			SELECT row_number() over() as rownr, a.aud_id id, a.aud_name filename, a.folder_id_r, 
			a.aud_extension ext, a.aud_name_org filename_org, 'aud' as kind, a.is_available,
			a.aud_create_time date_create, a.aud_change_date date_change, a.link_kind, a.link_path_url,
			a.path_to_asset, a.cloud_url, a.cloud_url_org, aut.aud_description description, aut.aud_keywords keywords, '0' as vheight, '0' as vwidth,
			(
				SELECT so.asset_format
				FROM #session.hostdbprefix#share_options so
				WHERE a.aud_id = so.group_asset_id
				AND so.folder_id_r = a.folder_id_r
				AND so.asset_type = 'aud'
				AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
			) AS theformat
			FROM #session.hostdbprefix#audios a LEFT JOIN #session.hostdbprefix#audios_text aut ON a.aud_id = aut.aud_id_r AND aut.lang_id_r = 1
			WHERE a.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
			AND (a.aud_group IS NULL OR a.aud_group = '')
			AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			UNION ALL
			SELECT row_number() over() as rownr, f.file_id id, f.file_name filename, f.folder_id_r, 
			f.file_extension ext, f.file_name_org filename_org, f.file_type as kind, f.is_available,
			f.file_create_time date_create, f.file_change_date date_change, f.link_kind, f.link_path_url,
			f.path_to_asset, f.cloud_url, f. cloud_url_org, ft.file_desc description, ft.file_keywords keywords, '0' as vheight, '0' as vwidth, '0' as theformat
			FROM #session.hostdbprefix#files f LEFT JOIN #session.hostdbprefix#files_desc ft ON f.file_id = ft.file_id_r AND ft.lang_id_r = 1
			WHERE f.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
			AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			ORDER BY filename
		)
		<!--- Show the limit only if pages is null or current (from print) --->
		<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
			WHERE rownr between #min# AND #max#
		</cfif>
		</cfquery>
	<!--- Other DB's --->
	<cfelse>
		<!--- Calculate the offset --->
		<cfset var theoffset = arguments.thestruct.offset * arguments.thestruct.rowmaxpage>
		<!--- Query --->
		<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid#getallassets#arguments.thestruct.folder_id##theoffset##max##arguments.thestruct.thisview#" cachedomain="#session.theuserid#_assets">
		SELECT <cfif variables.database EQ "mssql">TOP #max# </cfif>i.img_id id, i.img_filename filename, 
		i.folder_id_r, i.thumb_extension ext, i.img_filename_org filename_org, 'img' as kind, i.is_available,
		i.img_create_time date_create, i.img_change_date date_change, i.link_kind, i.link_path_url,
		i.path_to_asset, i.cloud_url, i.cloud_url_org, it.img_description description, it.img_keywords keywords, '0' as vwidth, '0' as vheight, 
		(
			SELECT so.asset_format
			FROM #session.hostdbprefix#share_options so
			WHERE i.img_id = so.group_asset_id
			AND so.folder_id_r = i.folder_id_r
			AND so.asset_type = 'img'
			AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
		) AS theformat
		FROM #session.hostdbprefix#images i LEFT JOIN #session.hostdbprefix#images_text it ON i.img_id = it.img_id_r AND it.lang_id_r = 1
		WHERE i.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND (i.img_group IS NULL OR i.img_group = '')
		AND i.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<!--- MSSQL --->
		<cfif variables.database EQ "mssql">
			AND i.img_id NOT IN (
				SELECT TOP #min# img_id
				FROM #session.hostdbprefix#images
				WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND (img_group IS NULL OR img_group = '')
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			)	
		</cfif>
		UNION ALL
		SELECT <cfif variables.database EQ "mssql">TOP #max# </cfif>v.vid_id id, v.vid_filename filename, v.folder_id_r, 
		v.vid_extension ext, v.vid_name_image filename_org, 'vid' as kind, v.is_available,
		v.vid_create_time date_create, v.vid_change_date date_change, v.link_kind, v.link_path_url,
		v.path_to_asset, v.cloud_url, v.cloud_url_org, vt.vid_description description, vt.vid_keywords keywords, CAST(v.vid_width AS CHAR) as vwidth, CAST(v.vid_height AS CHAR) as vheight,
		(
			SELECT so.asset_format
			FROM #session.hostdbprefix#share_options so
			WHERE v.vid_id = so.group_asset_id
			AND so.folder_id_r = v.folder_id_r
			AND so.asset_type = 'vid'
			AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
		) AS theformat
		FROM #session.hostdbprefix#videos v LEFT JOIN #session.hostdbprefix#videos_text vt ON v.vid_id = vt.vid_id_r AND vt.lang_id_r = 1
		WHERE v.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND (v.vid_group IS NULL OR v.vid_group = '')
		AND v.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<!--- MSSQL --->
		<cfif variables.database EQ "mssql">
			AND v.vid_id NOT IN (
				SELECT TOP #min# vid_id
				FROM #session.hostdbprefix#videos
				WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND (vid_group IS NULL OR vid_group = '')
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			)	
		</cfif>
		UNION ALL
		SELECT <cfif variables.database EQ "mssql">TOP #max# </cfif>a.aud_id id, a.aud_name filename, a.folder_id_r, 
		a.aud_extension ext, a.aud_name_org filename_org, 'aud' as kind, a.is_available,
		a.aud_create_time date_create, a.aud_change_date date_change, a.link_kind, a.link_path_url,
		a.path_to_asset, a.cloud_url, a.cloud_url_org, aut.aud_description description, aut.aud_keywords keywords, '0' as vwidth, '0' as vheight,
		(
			SELECT so.asset_format
			FROM #session.hostdbprefix#share_options so
			WHERE a.aud_id = so.group_asset_id
			AND so.folder_id_r = a.folder_id_r
			AND so.asset_type = 'aud'
			AND so.asset_selected = <cfqueryparam CFSQLType="CF_SQL_VARCHAR" value="1">
		) AS theformat
		FROM #session.hostdbprefix#audios a LEFT JOIN #session.hostdbprefix#audios_text aut ON a.aud_id = aut.aud_id_r AND aut.lang_id_r = 1
		WHERE a.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND (a.aud_group IS NULL OR a.aud_group = '')
		AND a.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<!--- MSSQL --->
		<cfif variables.database EQ "mssql">
			AND a.aud_id NOT IN (
				SELECT TOP #min# aud_id
				FROM #session.hostdbprefix#audios
				WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND (aud_group IS NULL OR aud_group = '')
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			)	
		</cfif>
		UNION ALL
		SELECT <cfif variables.database EQ "mssql">TOP #max# </cfif>f.file_id id, f.file_name filename, f.folder_id_r, 
		f.file_extension ext, f.file_name_org filename_org, f.file_type as kind, f.is_available,
		f.file_create_time date_create, f.file_change_date date_change, f.link_kind, f.link_path_url,
		f.path_to_asset, f.cloud_url, f.cloud_url_org, ft.file_desc description, ft.file_keywords keywords, '0' as vwidth, '0' as vheight, '0' as theformat
		FROM #session.hostdbprefix#files f LEFT JOIN #session.hostdbprefix#files_desc ft ON f.file_id = ft.file_id_r AND ft.lang_id_r = 1
		WHERE f.folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		<!--- MSSQL --->
		<cfif variables.database EQ "mssql">
			AND f.file_id NOT IN (
				SELECT TOP #min# file_id
				FROM #session.hostdbprefix#files
				WHERE folder_id_r IN (<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#thefolderlist#" list="true">)
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			)	
		</cfif>
		ORDER BY filename
		<!--- Show the limit only if pages is null or current (from print) --->
		<cfif arguments.thestruct.pages EQ "" OR arguments.thestruct.pages EQ "current">
			<!--- MySQL / H2 --->
			<cfif variables.database EQ "mysql" OR variables.database EQ "h2">
				LIMIT #theoffset#,#arguments.thestruct.rowmaxpage#
			</cfif>
		</cfif>
		</cfquery>
	</cfif>
	<!--- JSON Response for datatables
	<cfif arguments.thestruct.json EQ "t">
		<!--- Put columns into var --->
		<cfset thecols = arguments.thestruct.scolumns>
		<!--- If the first char in the scolumns is a coma --->
		<cfset thecolumns = findoneof(arguments.thestruct.scolumns,",")>
		<cfif thecolumns EQ 1>
			<cfset thecols = mid(arguments.thestruct.scolumns, 2, 1000)>
			<!---
<cfset thecolumns = findoneof(thecols,",")>
			<cfif thecolumns EQ 1>
				<cfset thecols = mid(thecols, 2, 1000)>
			</cfif>
--->
		</cfif>
		<!--- list of database columns which should be read and sent back to DataTables --->
		<cfset listColumns = thecols />
		<!--- <cfdump var="#arguments.thestruct#"><cfabort> --->
		<!--- Select again. We do this for sorting and searching --->
		<cfquery dbtype="query" name="qry">
		    Select #listColumns#
		    FROM qry
		    <cfif arguments.thestruct.ssearch NEQ "">
		    	WHERE lower(filename) LIKE '%#lcase(arguments.thestruct.ssearch)#%'
		    </cfif>
		    <cfif structkeyexists(arguments.thestruct,"iSortCol_0")>
			    ORDER BY
				<cfloop from="0" to="#arguments.thestruct.iSortingCols-1#" index="i">
				    #listGetAt(listColumns,arguments.thestruct["iSortCol_#i#"])# #arguments.thestruct["sSortDir_#i#"]# 
				    <cfif i is not arguments.thestruct.iSortingCols-1>, </cfif>
				</cfloop>
			</cfif>
		</cfquery>
		<!--- create the JSON response --->
		<cfsavecontent variable="qry"><cfoutput>{
		    "sEcho": #val(arguments.thestruct.sEcho)#,
		    "iTotalRecords": #arguments.thestruct.qry_filecount#,
		    "iTotalDisplayRecords": #qry.recordcount#,
		    "aaData": [ 
			<cfoutput query="qry" startrow="#val(arguments.thestruct.iDisplayStart+1)#" maxrows="#val(arguments.thestruct.iDisplayLength)#">
				<cfif currentRow gt (arguments.thestruct.iDisplayStart+1)>,</cfif>
				["<img src=\"http://datatables.net/examples/examples_support/details_open.png\">",<cfloop list="#listColumns#" index="thisColumn"><cfif thisColumn neq listFirst(listColumns)>,</cfif>"<cfif qry[thisColumn][qry.currentRow] EQ "img">image<cfelseif qry[thisColumn][qry.currentRow] EQ "vid">Video<cfelseif qry[thisColumn][qry.currentRow] EQ "aud">Audio<cfelseif qry[thisColumn][qry.currentRow] EQ "aud">Document<cfelse>#jsStringFormat(qry[thisColumn][qry.currentRow])#</cfif>"</cfloop>]
			</cfoutput> ]
		}</cfoutput></cfsavecontent>
	</cfif>
	 --->
	<!--- Return --->
	<cfreturn qry>
</cffunction>

<!--- Remove all selected records. Mixed data types thus get them here --->
<cffunction name="removeall" output="true">
	<cfargument name="thestruct" type="struct" required="true">
	<cfset theids = structnew()>
	<cfset theids.imgids = "">
	<cfset theids.docids = "">
	<cfset theids.vidids = "">
	<cfset theids.audids = "">
	<!--- Get the ids and put them into the right struct --->
	<cfloop list="#arguments.thestruct.id#" delimiters="," index="i">
		<cfif i CONTAINS "-img">
			<cfset imgid = listfirst(i,"-")>
			<cfset theids.imgids = imgid & "," & theids.imgids >
		<cfelseif  i CONTAINS "-doc">
			<cfset docid = listfirst(i,"-")>
			<cfset theids.docids = docid & "," & theids.docids >
		<cfelseif  i CONTAINS "-vid">
			<cfset vidid = listfirst(i,"-")>
			<cfset theids.vidids = vidid & "," & theids.vidids >
		<cfelseif  i CONTAINS "-aud">
			<cfset audid = listfirst(i,"-")>
			<cfset theids.audids = audid & "," & theids.audids >
		</cfif>
	</cfloop>
	<!--- Return --->
	<cfreturn theids>
</cffunction>

<!--- Get all assets of this folder this coming from a external call --->
<cffunction name="getfoldersinlist" output="false">
	<cfargument name="dsn" type="string" required="true">
	<cfargument name="database" type="string" required="true">
	<cfargument name="folder_id" type="string" required="true">
	<cfargument name="hostid" type="numeric" required="true">
	<cfargument name="prefix" default="" type="string" required="false">
	<cfif arguments.prefix EQ "">
		<cfset arguments.prefix = session.hostdbprefix>
	</cfif>
	<cfif NOT structkeyexists(session, "theuserid")>
		<cfset session.theuserid = 0>
	</cfif>
	<!--- Query --->
	<cfquery datasource="#arguments.dsn#" name="qry" cachename="#arguments.prefix##arguments.hostid#getfoldersinlist#arguments.folder_id#" cachedomain="#session.theuserid#_folders">
	SELECT folder_id
	FROM #arguments.prefix#folders f
	WHERE f.folder_id <cfif arguments.database EQ "oracle" OR arguments.database EQ "db2"><><cfelse>!=</cfif> f.folder_id_r
	AND f.folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.folder_id#">
	AND (f.folder_is_collection IS NULL OR folder_is_collection = '')
	AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#arguments.hostid#">
	</cfquery>
	<!--- Return --->
	<cfreturn qry>
</cffunction>

<!--- Retrieve folders --->
<cffunction name="getfoldersfortree" access="public" output="true">
	<cfargument name="thestruct" type="struct" required="true">
	<cfargument name="id" type="string" required="true">
	<cfargument name="col" type="string" required="true">
	<!--- If col is T or the id contains col- --->
	<cfif arguments.col EQ "T" or arguments.id CONTAINS "col-">
		<cfset var iscol = "T">
		<cfset var theid = listlast(arguments.id, "-")>
	<cfelse>
		<cfset var iscol = "F">
		<cfset var theid = arguments.id>
	</cfif>
	<!--- Param --->
	<cfparam default="0" name="session.thefolderorg">
	<cfparam default="0" name="session.type">
	<cfparam default="F" name="arguments.thestruct.actionismove">
	<!--- Query --->
	<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid##session.theuserid##arguments.id##arguments.col##session.thefolderorg##arguments.thestruct.actionismove##session.type#" cachedomain="#session.theuserid#_folders">
	SELECT f.folder_id, f.folder_name, f.folder_id_r, f.folder_of_user, f.folder_owner, f.folder_level, <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2">NVL<cfelseif variables.database EQ "mysql">ifnull<cfelseif variables.database EQ "mssql">isnull</cfif>(u.user_login_name,'Obsolete') as username,
		<!--- Permission follow but not for sysadmin and admin --->
		<cfif not Request.securityObj.CheckSystemAdminUser() and not Request.securityObj.CheckAdministratorUser()>
			CASE
				<!--- Check permission on this folder --->
				WHEN EXISTS(
					SELECT fg.folder_id_r
					FROM #session.hostdbprefix#folders_groups fg
					WHERE fg.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					AND fg.folder_id_r = f.folder_id
					AND lower(fg.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
					AND fg.grp_id_r IN (SELECT ct_g_u_grp_id FROM ct_groups_users WHERE ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">)
					) THEN 'unlocked'
				<!--- When folder is shared for everyone --->
				WHEN EXISTS(
					SELECT fg2.folder_id_r
					FROM #session.hostdbprefix#folders_groups fg2
					WHERE fg2.grp_id_r = '0'
					AND fg2.folder_id_r = f.folder_id
					AND fg2.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					AND lower(fg2.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
					) THEN 'unlocked'
				<!--- If this is the user folder or he is the owner --->
				WHEN ( lower(f.folder_of_user) = 't' OR f.folder_owner = '#Session.theUserID#' ) THEN 'unlocked'
				<!--- If this is the upload bin --->
				WHEN f.folder_id = '1' THEN 'unlocked'
				<!--- If this is a collection --->
				<!--- WHEN lower(f.folder_is_collection) = 't' THEN 'unlocked' --->
				<!--- If nothing meets the above lock the folder --->
				ELSE 'locked'
			END AS perm
		<cfelse>
			'unlocked' AS perm
		</cfif>
		<!--- Check for subfolders --->
		,
			CASE
				<!--- First check if there is a subfolder --->
				WHEN EXISTS(
					SELECT <cfif variables.database EQ "mssql">TOP 1 </cfif>*
						FROM #session.hostdbprefix#folders s1 
						WHERE s1.folder_id <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> f.folder_id
						AND s1.folder_id_r = f.folder_id
						AND s1.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
						<!--- AND lower(s.folder_of_user) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">  --->
						<cfif not Request.securityObj.CheckSystemAdminUser() and not Request.securityObj.CheckAdministratorUser()>
							AND s1.folder_owner = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">
						</cfif>
						<!--- If this is a move then dont show the folder that we are moving --->
						<cfif arguments.thestruct.actionismove EQ "T" AND session.type EQ "movefolder">
							AND s1.folder_id != <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.thefolderorg#">
						</cfif>
						<cfif variables.database EQ "oracle">
							AND ROWNUM = 1
						<cfelseif  variables.database EQ "mysql" OR variables.database EQ "h2">
							LIMIT 1
						</cfif>
					) THEN 1
					<!--- Check permission on this folder --->
					WHEN EXISTS(
						SELECT <cfif variables.database EQ "mssql">TOP 1 </cfif>*
						FROM #session.hostdbprefix#folders s2, #session.hostdbprefix#folders_groups fg3
						WHERE s2.folder_id <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> f.folder_id
						AND s2.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
						AND fg3.host_id = s2.host_id
						AND s2.folder_id_r = f.folder_id
						AND fg3.folder_id_r = s2.folder_id
						AND lower(fg3.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
						AND fg3.grp_id_r IN (SELECT ct_g_u_grp_id FROM ct_groups_users <cfif not Request.securityObj.CheckSystemAdminUser() and not Request.securityObj.CheckAdministratorUser()>WHERE ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#"></cfif>)
						<cfif variables.database EQ "oracle">
							AND ROWNUM = 1
						<cfelseif  variables.database EQ "mysql" OR variables.database EQ "h2">
							LIMIT 1
						</cfif>
						) THEN 1
					<!--- When folder is shared for everyone --->
					WHEN EXISTS(
						SELECT <cfif variables.database EQ "mssql">TOP 1 </cfif>*
						FROM #session.hostdbprefix#folders s3, #session.hostdbprefix#folders_groups fg4
						WHERE s3.folder_id <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> f.folder_id
						AND s3.folder_id_r = f.folder_id
						AND fg4.grp_id_r = '0'
						AND fg4.folder_id_r = s3.folder_id
						AND lower(fg4.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
						AND s3.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
						AND s3.host_id = fg4.host_id
						<cfif variables.database EQ "oracle">
							AND ROWNUM = 1
						<cfelseif  variables.database EQ "mysql" OR variables.database EQ "h2">
							LIMIT 1
						</cfif>
						) THEN 1
					<!--- If nothing meets the above lock the folder --->
					ELSE 0
				END AS subhere
		FROM #session.hostdbprefix#folders f LEFT JOIN users u ON u.user_id = f.folder_owner
		WHERE 
		<cfif theid gt 0>
			f.folder_id <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> f.folder_id_r
			AND
			f.folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
		<cfelse>
			f.folder_id = f.folder_id_r
		</cfif>
		<cfif iscol EQ "F">
			AND (f.folder_is_collection IS NULL OR folder_is_collection = '')
		<cfelse>
			AND lower(f.folder_is_collection) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
		</cfif>
		<!--- filter user folders, but not for collections --->
		<cfif iscol EQ "F" AND (NOT Request.securityObj.CheckSystemAdminUser() AND NOT Request.securityObj.CheckAdministratorUser())>
			AND
				(
				LOWER(<cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2">NVL<cfelseif variables.database EQ "mysql">ifnull<cfelseif variables.database EQ "mssql">isnull</cfif>(f.folder_of_user,<cfqueryparam cfsqltype="cf_sql_varchar" value="f">)) <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
				OR f.folder_owner = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.theuserid#">
				)
		</cfif>
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		ORDER BY lower(folder_name)
		</cfquery>
		<!--- Query to get unlocked folders only --->
		<cfquery dbtype="query" name="qRet">
		SELECT *
		FROM qry
		WHERE perm = <cfqueryparam cfsqltype="cf_sql_varchar" value="unlocked">
		<!--- If this is a move then dont show the folder that we are moving --->
		<cfif arguments.thestruct.actionismove EQ "T" AND session.type EQ "movefolder">
			AND folder_id != <cfqueryparam cfsqltype="cf_sql_varchar" value="#session.thefolderorg#">
		</cfif>
		</cfquery>
		<!--- Create the XML --->
		<cfif theid EQ 0>
			<!--- This is the ROOT level  --->
			<cfif session.showmyfolder EQ "F" AND iscol NEQ "T">
				<cfquery dbtype="query" name="qRet">
				SELECT *
				FROM qRet
				WHERE folder_of_user = <cfqueryparam cfsqltype="cf_sql_varchar" value="f">
				OR (lower(folder_name) = <cfqueryparam cfsqltype="cf_sql_varchar" value="my folder"> AND folder_owner = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.theuserid#">)
				OR folder_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="1">
				OR folder_owner = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.theuserid#">
				</cfquery>
			</cfif>
		</cfif>
	<!--- Tree for the Explorer --->
	<cfif arguments.thestruct.actionismove EQ "F">
		<cfoutput query="qRet">
		<li id="<cfif iscol EQ "T">col-</cfif>#folder_id#"<cfif subhere EQ "1"> class="closed"</cfif>><a href="##" onclick="$('##rightside').load('index.cfm?fa=<cfif iscol EQ "T">c.collections<cfelse>c.folder</cfif>&col=F&folder_id=<cfif iscol EQ "T">col-</cfif>#folder_id#');" rel="prefetch"><ins>&nbsp;</ins>#folder_name#
		<cfif theid EQ 0><cfif iscol EQ "F" AND (Request.securityObj.CheckSystemAdminUser() OR Request.securityObj.CheckAdministratorUser())><cfif session.theuserid NEQ folder_owner AND folder_owner NEQ ""> (#username#)</cfif></cfif></cfif></a></li>
		</cfoutput>
	<!--- If we come from a move action --->
	<cfelse>
		<cfoutput query="qRet">
		<li id="<cfif iscol EQ "T">col-</cfif>#folder_id#"<cfif subhere EQ "1"> class="closed"</cfif>>
		<!--- movefile --->
		<cfif session.type EQ "movefile">
			<a href="##" onclick="loadcontent('rightside','index.cfm?fa=#session.savehere#&folder_id=#folder_id#&folder_name=#URLEncodedFormat(folder_name)#');destroywindow<cfif NOT session.thefileid CONTAINS ",">(2)<cfelse>(1)</cfif>;<cfif NOT session.thefileid CONTAINS ",">loadcontent('thewindowcontent1','index.cfm?fa=c.<cfif session.thetype EQ "doc">files<cfelseif session.thetype EQ "img">images<cfelseif session.thetype EQ "vid">videos<cfelseif session.thetype EQ "aud">audios</cfif>_detail&file_id=#session.thefileid#&what=<cfif session.thetype EQ "doc">files<cfelseif session.thetype EQ "img">images<cfelseif session.thetype EQ "vid">videos<cfelseif session.thetype EQ "aud">audios</cfif>&loaddiv=&folder_id=#folder_id#')</cfif>;loadcontent('rightside','index.cfm?fa=c.folder&folder_id=#session.thefolderorg#');">
		<!--- movefolder --->
		<cfelseif session.type EQ "movefolder">
			<a href="##" onclick="loadcontent('rightside','index.cfm?fa=#session.savehere#&intofolderid=#folder_id#&intolevel=#folder_level#');destroywindow(1);loadcontent('explorer','index.cfm?fa=c.explorer');return false;">
		<!--- saveaszip or as a collection --->
		<cfelseif session.type EQ "saveaszip" OR session.type EQ "saveascollection">
			<a href="##" onclick="loadcontent('win_choosefolder','index.cfm?fa=#session.savehere#&folder_id=#folder_id#&folder_name=#URLEncodedFormat(folder_name)#');">
		<!--- scheduler --->
		<cfelseif session.type EQ "scheduler">
			<a href="##" onclick="javascript:document.schedulerform.folder_id.value = '#folder_id#'; document.schedulerform.folder_name.value = '#folder_name#';destroywindow(2);">
		<!--- choose a collection --->
		<cfelseif session.type EQ "choosecollection">
			<a href="##" onclick="loadcontent('div_choosecol','index.cfm?fa=c.collection_chooser&withfolder=T&folder_id=#folder_id#');">
		</cfif>
		<ins>&nbsp;</ins>#folder_name#<cfif iscol EQ "F" AND folder_name EQ "my folder" AND (Request.securityObj.CheckSystemAdminUser() OR Request.securityObj.CheckAdministratorUser())><cfif session.theuserid NEQ folder_owner AND folder_owner NEQ ""> (#username#)</cfif></cfif></a>
		</li>
		</cfoutput>
	</cfif>
	<cfreturn />
</cffunction>

<!--- Clean folderid of it is a collection --->
<cffunction name="cleanid" access="public" output="true">
	<cfargument name="id" type="string">
	<cfset var theid = listlast(arguments.id, "-")>
	<cfreturn theid>
</cffunction>

<!--- Share: Check on folder permissions --->
<cffunction name="sharecheckperm" output="true">
	<cfargument name="thestruct" type="struct" required="true">
	<!--- Param --->
	<cfset shared = structnew()>
	<cfparam name="session.theuserid" default="">
	<cfparam name="session.iscol" default="F">
	<!--- Check if folder is even shared or not --->
	<cfif session.iscol EQ "F">
		<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid##session.theuserid#sharecheckperm#arguments.thestruct.fid#" cachedomain="#session.theuserid#_folders">
		SELECT folder_shared shared
		FROM #session.hostdbprefix#folders
		WHERE folder_id = <cfqueryparam value="#arguments.thestruct.fid#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	<cfelse>
		<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid#sharecheckperm2#arguments.thestruct.fid#" cachedomain="#session.theuserid#_folders">
		SELECT col_shared shared
		FROM #session.hostdbprefix#collections
		WHERE col_id = <cfqueryparam value="#arguments.thestruct.fid#" cfsqltype="CF_SQL_VARCHAR">
		AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	</cfif>
	<!--- Set qry in struct --->
	<cfset shared.sharedfolder = qry.shared>
	<!--- If the folder is shared, check if the folder is for everyone --->
	<cfif qry.shared EQ "T">
		<cfif session.iscol EQ "F">
			<cfquery datasource="#variables.dsn#" name="qryfolder" cachename="#session.hostdbprefix##session.hostid##session.theuserid#sharecheckperm3#arguments.thestruct.fid#" cachedomain="#session.theuserid#_folders">
			SELECT grp_id_r
			FROM #session.hostdbprefix#folders_groups
			WHERE folder_id_r = <cfqueryparam value="#arguments.thestruct.fid#" cfsqltype="CF_SQL_VARCHAR">
			AND grp_id_r = <cfqueryparam value="0" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		<cfelse>
			<cfquery datasource="#variables.dsn#" name="qryfolder" cachename="#session.hostdbprefix##session.hostid##session.theuserid#sharecheckperm4#arguments.thestruct.fid#" cachedomain="#session.theuserid#_folders">
			SELECT grp_id_r
			FROM #session.hostdbprefix#collections_groups
			WHERE col_id_r = <cfqueryparam value="#arguments.thestruct.fid#" cfsqltype="CF_SQL_VARCHAR">
			AND grp_id_r = <cfqueryparam value="0" cfsqltype="CF_SQL_VARCHAR">
			</cfquery>
		</cfif>
		<!--- If the folder has the group 0 (everyone) --->
		<cfif qryfolder.recordcount EQ 1>
			<cfset shared.everyone = "T">
		<cfelse>
			<cfset shared.everyone = "F">
		</cfif>	
	<cfelse>
		<cfset shared.everyone = "F">
	</cfif>
	<!--- Return --->
	<cfreturn shared>
</cffunction>

<!--- Share: Check for folder permissions --->
<cffunction name="sharecheckpermfolder" access="public" output="true">
	<cfargument name="fid" type="string">
	<!--- Query --->
	<cfif session.iscol EQ "F">
		<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid##session.theuserid#sharecheckpermfolder#arguments.fid#" cachedomain="#session.theuserid#_folders">
		SELECT folder_id,
			<!--- Permission follow but not for sysadmin and admin --->
			<cfif not Request.securityObj.CheckSystemAdminUser() and not Request.securityObj.CheckAdministratorUser()>
				CASE
					WHEN EXISTS(
						SELECT fg.folder_id_r
						FROM #session.hostdbprefix#folders_groups fg LEFT JOIN ct_groups_users gu ON gu.ct_g_u_grp_id = fg.grp_id_r AND gu.ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">
						WHERE fg.folder_id_r = f.folder_id
						AND lower(fg.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
						) THEN 'unlocked'
					<!--- If this is the user folder or he is the owner --->
					WHEN ( lower(f.folder_of_user) = 't' AND f.folder_owner = '#Session.theUserID#' ) THEN 'unlocked'
					<!--- If this is the upload bin
					WHEN f.folder_id = 1 THEN 'unlocked' --->
					<!--- If this is a collection
					WHEN lower(f.folder_is_collection) = 't' THEN 'unlocked' --->
					<!--- If nothing meets the above lock the folder --->
					ELSE 'locked'
				END AS perm
			<cfelse>
				'unlocked' AS perm
			</cfif>
		FROM #session.hostdbprefix#folders f
		WHERE f.folder_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.fid#">
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	<cfelse>
		<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid##session.theuserid#sharecheckpermfolder#arguments.fid#" cachedomain="#session.theuserid#_folders">
		SELECT col_id,
			<!--- Permission follow but not for sysadmin and admin --->
			<cfif not Request.securityObj.CheckSystemAdminUser() and not Request.securityObj.CheckAdministratorUser()>
				CASE
					WHEN EXISTS(
						SELECT fg.col_id_r
						FROM #session.hostdbprefix#collections_groups fg LEFT JOIN ct_groups_users gu ON gu.ct_g_u_grp_id = fg.grp_id_r AND gu.ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">
						WHERE fg.col_id_r = f.col_id
						AND lower(fg.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
						) THEN 'unlocked'
					<!--- If this is the user folder or he is the owner --->
					WHEN ( f.col_owner = '#Session.theUserID#' ) THEN 'unlocked'
					<!--- If nothing meets the above lock the folder --->
					ELSE 'locked'
				END AS perm
			<cfelse>
				'unlocked' AS perm
			</cfif>
		FROM #session.hostdbprefix#collections f
		WHERE f.col_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.fid#">
		AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
		</cfquery>
	</cfif>
	<cfoutput>#qry.perm#</cfoutput>
	<!--- Return --->
	<cfreturn />
</cffunction>

<!--- Sharing for selected assets --->
<cffunction name="batch_sharing" output="true">
	<cfargument name="thestruct" type="struct" required="true">
	<!--- Loop over the file ids --->
	<cfloop list="#arguments.thestruct.file_ids#" index="i">
		<!--- Get the ID and the type --->
		<cfset theid = listfirst(i,"-")>
		<cfset thetype = listlast(i,"-")>
		<!--- Decide on the type what to do --->
		<!--- DOCUMENTS --->
		<cfif thetype EQ "doc">
			<!--- Save sharing state --->
			<cfquery datasource="#variables.dsn#">
            UPDATE #session.hostdbprefix#files
            SET shared = <cfqueryparam value="#arguments.thestruct.state#" cfsqltype="cf_sql_varchar">
            WHERE file_id = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
            AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
			<!--- Get filename --->
			<cfquery datasource="#variables.dsn#" name="qry">
			SELECT file_name_org
			FROM #session.hostdbprefix#files
			WHERE file_id = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		<!--- IMAGES --->
		<cfelseif thetype EQ "img">
			<!--- Save sharing state --->
			<cfquery datasource="#variables.dsn#">
            UPDATE #session.hostdbprefix#images
            SET shared = <cfqueryparam value="#arguments.thestruct.state#" cfsqltype="cf_sql_varchar">
            WHERE img_id = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
            </cfquery>
			<cfquery datasource="#variables.dsn#" name="qry">
			SELECT img_filename_org, thumb_extension
			FROM #session.hostdbprefix#images
			WHERE img_id = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
			<!--- Get all related records --->
			<cfquery datasource="#variables.dsn#" name="qryrel">
			SELECT folder_id_r, img_id, img_filename_org, thumb_extension
			FROM #session.hostdbprefix#images
			WHERE img_group = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		<!--- VIDEOS --->
		<cfelseif thetype EQ "vid">
			<!--- Save sharing state --->
			<cfquery datasource="#variables.dsn#">
            UPDATE #session.hostdbprefix#videos
            SET shared = <cfqueryparam value="#arguments.thestruct.state#" cfsqltype="cf_sql_varchar">
            WHERE vid_id = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
            </cfquery>
			<cfquery datasource="#variables.dsn#" name="qry">
			SELECT vid_name_org
			FROM #session.hostdbprefix#videos
			WHERE vid_id = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
			<!--- Get all related records --->
			<cfquery datasource="#variables.dsn#" name="qryrel">
			SELECT folder_id_r, vid_id, vid_name_org
			FROM #session.hostdbprefix#videos
			WHERE vid_group = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
			AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
			</cfquery>
		</cfif>
	</cfloop>
</cffunction>

<!--- Get foldername --->
<cffunction name="getfoldername" output="false">
	<cfargument name="folder_id" required="yes" type="string">
	<cfquery datasource="#variables.dsn#" name="qry">
	SELECT folder_name
	FROM #session.hostdbprefix#folders
	WHERE folder_id = <cfqueryparam value="#arguments.folder_id#" cfsqltype="CF_SQL_VARCHAR">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<cfreturn qry.folder_name>
</cffunction>

<!--- Save the combined view --->
<cffunction name="combined_save" output="false">
	<cfargument name="thestruct" type="struct" required="true">
	<cfthread name="#createuuid()#" intstruct="#arguments.thestruct#">
		<cfinvoke method="combined_save_thread" thestruct="#attributes.intstruct#" />
	</cfthread>
	<cfreturn />
</cffunction>

<!--- THREAD: Save the combined view --->
<cffunction name="combined_save_thread" output="true">
	<cfargument name="thestruct" type="struct" required="true">
	<!---
<cfdump var="#arguments.thestruct#">
	<cfabort>
--->
	<!--- Param --->
	<cfset var docid = 0>
	<cfset var audid = 0>
	<cfset var imgid = 0>
	<cfset var vidid = 0>
	<!--- Loop over the form fields --->
	<cfloop delimiters="," index="myform" list="#arguments.thestruct.fieldnames#">
		<!--- Images --->
		<cfif myform CONTAINS "img_">
			<!--- First part of the _ --->
			<cfset theid = listfirst(myform,"_")>
			<cfif imgid NEQ theid>
				<!--- Set the file name --->
				<cfset fname = theid & "_img_filename">
				<!--- Set the description --->
				<cfset fdesc = theid & "_img_desc_1">
				<!--- Set the keywords --->
				<cfset fkeys = theid & "_img_keywords_1">
				<!--- Finally update the record --->
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#images
				SET img_filename = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fname#"]#">
				WHERE img_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<!--- And the keywords & desc --->
				<cfquery datasource="#variables.dsn#" name="here_img">
				SELECT img_id_r
				FROM #session.hostdbprefix#images_text
				WHERE img_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
				</cfquery>
				<cfif here_img.recordcount NEQ 0>
					<cfquery datasource="#variables.dsn#">
					UPDATE #session.hostdbprefix#images_text
					SET 
					img_description = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fdesc#"]#">,
					<cfif trim(form["#fkeys#"]) EQ ",">
						img_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="">
					<cfelse>
						img_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fkeys#"]#">
					</cfif>
					WHERE img_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
					AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
					</cfquery>
				<cfelse>
					<cfquery datasource="#variables.dsn#">
					INSERT INTO #session.hostdbprefix#images_text
					(id_inc, img_description, img_keywords, img_id_r, lang_id_r, host_id)
					VALUES(
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#replace(createuuid(),"-","","all")#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fdesc#"]#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fkeys#"]#">,
						<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="1">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					)
					</cfquery>
				</cfif>
				<!--- Store the id in a temp var --->
				<cfset imgid = theid>
				<!--- Flush Cache --->
				<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_images" />
				<!--- Lucene --->
				<!--- Get file detail --->
				<cfinvoke component="images" method="filedetail" theid="#theid#" thecolumn="path_to_asset, link_kind, img_filename_org filenameorg, lucene_key, link_path_url" returnvariable="arguments.thestruct.qrydetail">
				<cfset arguments.thestruct.filenameorg = arguments.thestruct.qrydetail.filenameorg>
				<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#theid#" category="img" notfile="F">
				<cfinvoke component="lucene" method="index_update" dsn="#variables.dsn#" thestruct="#arguments.thestruct#" assetid="#theid#" category="img" notfile="F">
			</cfif>
		<!--- Videos --->
		<cfelseif myform CONTAINS "vid_">
			<!--- First part of the _ --->
			<cfset theid = listfirst(myform,"_")>
			<cfif vidid NEQ theid>
				<!--- Set the file name --->
				<cfset fname = theid & "_vid_filename">
				<!--- Set the description --->
				<cfset fdesc = theid & "_vid_desc_1">
				<!--- Set the keywords --->
				<cfset fkeys = theid & "_vid_keywords_1">
				<!--- If the keyword only contains a then empty it --->
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#videos
				SET vid_filename = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fname#"]#">
				WHERE vid_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<!--- And the keywords & desc --->
				<cfquery datasource="#variables.dsn#" name="here_vid">
				SELECT vid_id_r
				FROM #session.hostdbprefix#videos_text
				WHERE vid_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
				</cfquery>
				<cfif here_vid.recordcount NEQ 0>
					<!--- And the keywords & desc --->
					<cfquery datasource="#variables.dsn#">
					UPDATE #session.hostdbprefix#videos_text
					SET 
					vid_description = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fdesc#"]#">,
					<cfif trim(form["#fkeys#"]) EQ ",">
						vid_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="">
					<cfelse>
						vid_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fkeys#"]#">
					</cfif>
					WHERE vid_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
					AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
					</cfquery>
				<cfelse>
					<cfquery datasource="#variables.dsn#">
					INSERT INTO #session.hostdbprefix#videos_text
					(id_inc, vid_description, vid_keywords, vid_id_r, lang_id_r, host_id)
					VALUES(
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#replace(createuuid(),"-","","all")#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fdesc#"]#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fkeys#"]#">,
						<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="1">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					)
					</cfquery>
				</cfif>
				<!--- Store the id in a temp var --->
				<cfset vidid = theid>
				<!--- Flush Cache --->
				<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_videos" />
				<!--- Lucene --->
				<!--- Get file detail --->
				<cfinvoke component="videos" method="getdetails" vid_id="#theid#" ColumnList="v.path_to_asset, v.link_kind, v.vid_name_org filenameorg, v.lucene_key, v.link_path_url" returnvariable="arguments.thestruct.qrydetail">
				<cfset arguments.thestruct.filenameorg = arguments.thestruct.qrydetail.filenameorg>
				<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#theid#" category="vid" notfile="F">
				<cfinvoke component="lucene" method="index_update" dsn="#variables.dsn#" thestruct="#arguments.thestruct#" assetid="#theid#" category="vid" notfile="F">
			</cfif>
		<!--- Audios --->
		<cfelseif myform CONTAINS "aud_">
			<!--- First part of the _ --->
			<cfset theid = listfirst(myform,"_")>
			<cfif audid NEQ theid>
				<!--- Set the file name --->
				<cfset fname = theid & "_aud_filename">
				<!--- Set the description --->
				<cfset fdesc = theid & "_aud_desc_1">
				<!--- Set the keywords --->
				<cfset fkeys = theid & "_aud_keywords_1">
				<!--- If the keyword only contains a then empty it --->
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#audios
				SET aud_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fname#"]#">
				WHERE aud_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<cfquery datasource="#variables.dsn#" name="here_aud">
				SELECT aud_id_r
				FROM #session.hostdbprefix#audios_text
				WHERE aud_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
				</cfquery>
				<cfif here_aud.recordcount NEQ 0>
					<!--- And the keywords & desc --->
					<cfquery datasource="#variables.dsn#">
					UPDATE #session.hostdbprefix#audios_text
					SET 
					aud_description = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fdesc#"]#">,
					<cfif trim(form["#fkeys#"]) EQ ",">
						aud_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="">
					<cfelse>
						aud_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fkeys#"]#">
					</cfif>
					WHERE aud_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
					AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
					</cfquery>
				<cfelse>
					<cfquery datasource="#variables.dsn#">
					INSERT INTO #session.hostdbprefix#audios_text
					(id_inc, aud_description, aud_keywords, aud_id_r, lang_id_r, host_id)
					VALUES(
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#replace(createuuid(),"-","","all")#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fdesc#"]#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fkeys#"]#">,
						<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="1">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					)
					</cfquery>
				</cfif>
				<!--- Store the id in a temp var --->
				<cfset audid = theid>
				<!--- Flush Cache --->
				<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_audios" />		
				<!--- Lucene --->
				<!--- Get file detail --->
				<cfquery datasource="#application.razuna.datasource#" name="arguments.thestruct.qrydetail">
				SELECT link_kind, link_path_url, aud_name_org filenameorg, lucene_key, path_to_asset
				FROM #session.hostdbprefix#audios
				WHERE aud_id = <cfqueryparam value="#theid#" cfsqltype="CF_SQL_VARCHAR">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<cfset arguments.thestruct.filenameorg = arguments.thestruct.qrydetail.filenameorg>
				<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#theid#" category="aud" notfile="F">
				<cfinvoke component="lucene" method="index_update" dsn="#variables.dsn#" thestruct="#arguments.thestruct#" assetid="#theid#" category="aud" notfile="F">
			</cfif>
		<!--- Files --->
		<cfelseif myform CONTAINS "doc_">
			<!--- First part of the _ --->
			<cfset theid = listfirst(myform,"_")>
			<cfif docid NEQ theid>
				<!--- Set the file name --->
				<cfset fname = theid & "_doc_filename">
				<!--- Set the description --->
				<cfset fdesc = theid & "_doc_desc_1">
				<!--- Set the keywords --->
				<cfset fkeys = theid & "_doc_keywords_1">
				<!--- If the keyword only contains a then empty it --->
				<cfquery datasource="#variables.dsn#">
				UPDATE #session.hostdbprefix#files
				SET file_name = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fname#"]#">
				WHERE file_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				</cfquery>
				<!--- And the keywords & desc --->
				<cfquery datasource="#variables.dsn#" name="here_doc">
				SELECT file_id_r
				FROM #session.hostdbprefix#files_desc
				WHERE file_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
				AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
				</cfquery>
				<cfif here_doc.recordcount NEQ 0>
					<cfquery datasource="#variables.dsn#">
					UPDATE #session.hostdbprefix#files_desc
					SET 
					file_desc = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fdesc#"]#">,
					<cfif trim(form["#fkeys#"]) EQ ",">
						file_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="">
					<cfelse>
						file_keywords = <cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fkeys#"]#">
					</cfif>
					WHERE file_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">
					AND lang_id_r = <cfqueryparam cfsqltype="cf_sql_numeric" value="1">
					</cfquery>
				<cfelse>
					<cfquery datasource="#variables.dsn#">
					INSERT INTO #session.hostdbprefix#files_desc
					(id_inc, file_desc, file_keywords, file_id_r, lang_id_r, host_id)
					VALUES(
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#replace(createuuid(),"-","","all")#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fdesc#"]#">,
						<cfqueryparam cfsqltype="cf_sql_varchar" value="#form["#fkeys#"]#">,
						<cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#theid#">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="1">,
						<cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
					)
					</cfquery>
				</cfif>
				<!--- Store the id in a temp var --->
				<cfset docid = theid>
				<!--- Flush Cache --->
				<cfinvoke component="global" method="clearcache" theaction="flushall" thedomain="#session.theuserid#_files" />
				<!--- Lucene --->
				<!--- Get file detail --->
				<cfinvoke component="files" method="filedetail" theid="#theid#" thecolumn="path_to_asset, link_kind, file_name_org filenameorg, lucene_key, link_path_url" returnvariable="arguments.thestruct.qrydetail">
				<cfset arguments.thestruct.filenameorg = arguments.thestruct.qrydetail.filenameorg>
				<cfinvoke component="lucene" method="index_delete" thestruct="#arguments.thestruct#" assetid="#theid#" category="doc" notfile="F">
				<cfinvoke component="lucene" method="index_update" dsn="#variables.dsn#" thestruct="#arguments.thestruct#" assetid="#theid#" category="doc" notfile="F">
			</cfif>
		</cfif>
	</cfloop>
	<!--- <cfoutput>Filename: #form["#fname#"]# Desc: #form["#fdesc#"]# Keywords: #form["#fkeys#"]#<br /></cfoutput> --->
	<cfreturn />
</cffunction>

<!--- LINK: Check Folder --->
<cffunction name="link_check" output="false">
	<cfargument name="thestruct" type="struct" required="true">
		<!--- Param --->
		<cfset status = structnew()>
		<!--- Does the dir exists --->
		<cfset status.dir = directoryexists("#arguments.thestruct.link_path#")>
		<cfif status.dir>
			<!--- List the content of the Dir --->
			<cfdirectory action="list" directory="#arguments.thestruct.link_path#" name="thedir">
			<!--- Count the files --->
			<cfquery dbtype="query" name="status.countfiles">
			SELECT count(name) thecount
			FROM thedir
			WHERE type = 'File'
			</cfquery>
			<!--- Count the dirs --->
			<cfquery dbtype="query" name="status.countdirs">
			SELECT count(name) thecount
			FROM thedir
			WHERE type = 'Dir'
			AND attributes != 'H'
			</cfquery>
		</cfif>
	<cfreturn status>
</cffunction>

<!--- Get Subfolders --->
<cffunction name="getsubfolders" output="false">
	<cfargument name="folder_id" type="string" required="true">
	<cfargument name="external" type="string" required="false">
	<!--- Query --->
	<cfquery datasource="#variables.dsn#" name="qry" cachename="#session.hostdbprefix##session.hostid##session.theuserid##arguments.folder_id#" cachedomain="#session.theuserid#_folders">
	SELECT f.folder_id, f.folder_name, f.folder_id_r, f.folder_of_user, f.folder_owner, f.folder_level, <cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2">NVL<cfelseif variables.database EQ "mysql">ifnull<cfelseif variables.database EQ "mssql">isnull</cfif>(u.user_login_name,'Obsolete') as username,
	<!--- Permission follow but not for sysadmin and admin --->
	<cfif NOT Request.securityObj.CheckSystemAdminUser() AND NOT Request.securityObj.CheckAdministratorUser() AND NOT structkeyexists(arguments,"external")>
		CASE
			<!--- Check permission on this folder --->
			WHEN EXISTS(
				SELECT fg.folder_id_r
				FROM #session.hostdbprefix#folders_groups fg
				WHERE fg.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				AND fg.folder_id_r = f.folder_id
				AND lower(fg.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
				AND fg.grp_id_r IN (SELECT ct_g_u_grp_id FROM ct_groups_users WHERE ct_g_u_user_id = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#Session.theUserID#">)
				) THEN 'unlocked'
			<!--- When folder is shared for everyone --->
			WHEN EXISTS(
				SELECT fg2.folder_id_r
				FROM #session.hostdbprefix#folders_groups fg2
				WHERE fg2.grp_id_r = '0'
				AND fg2.folder_id_r = f.folder_id
				AND fg2.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
				AND lower(fg2.grp_permission) IN (<cfqueryparam cfsqltype="cf_sql_varchar" value="r,w,x" list="true">)
				) THEN 'unlocked'
			<!--- If this is the user folder or he is the owner --->
			WHEN ( lower(f.folder_of_user) = 't' OR f.folder_owner = '#Session.theUserID#' ) THEN 'unlocked'
			<!--- If this is the upload bin --->
			WHEN f.folder_id = '1' THEN 'unlocked'
			<!--- If this is a collection --->
			<!--- WHEN lower(f.folder_is_collection) = 't' THEN 'unlocked' --->
			<!--- If nothing meets the above lock the folder --->
			ELSE 'locked'
		END AS perm
	<cfelse>
		'unlocked' AS perm
	</cfif>
	FROM #session.hostdbprefix#folders f LEFT JOIN users u ON u.user_id = f.folder_owner
	WHERE 
	<cfif arguments.folder_id gt 0>
		f.folder_id <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> f.folder_id_r
		AND
		f.folder_id_r = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#arguments.folder_id#">
	<cfelse>
		f.folder_id = f.folder_id_r
	</cfif>
	<!--- <cfif iscol EQ "F"> --->
		AND (f.folder_is_collection IS NULL OR folder_is_collection = '')
	<!---
<cfelse>
		AND lower(f.folder_is_collection) = <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
	</cfif>
--->
	<!--- filter user folders, but not for collections --->
	<cfif (NOT Request.securityObj.CheckSystemAdminUser() AND NOT Request.securityObj.CheckAdministratorUser()) AND NOT structkeyexists(arguments,"external")>
		AND
			(
			LOWER(<cfif variables.database EQ "oracle" OR variables.database EQ "h2" OR variables.database EQ "db2">NVL<cfelseif variables.database EQ "mysql">ifnull<cfelseif variables.database EQ "mssql">isnull</cfif>(f.folder_of_user,<cfqueryparam cfsqltype="cf_sql_varchar" value="f">)) <cfif variables.database EQ "oracle" OR variables.database EQ "db2"><><cfelse>!=</cfif> <cfqueryparam cfsqltype="cf_sql_varchar" value="t">
			OR f.folder_owner = <cfqueryparam cfsqltype="CF_SQL_VARCHAR" value="#session.theuserid#">
			)
	</cfif>
	AND f.host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	ORDER BY lower(folder_name)
	</cfquery>
	<!--- Query to get unlocked folders only --->
	<cfquery dbtype="query" name="qRet">
	SELECT *
	FROM qry
	WHERE perm = <cfqueryparam cfsqltype="cf_sql_varchar" value="unlocked">
	</cfquery>
	<cfreturn qret>
</cffunction>

<!--- Get folder breadcrumb (backwards) --->
<cffunction name="getbreadcrumb" output="false">
	<cfargument name="folder_id_r" required="yes" type="string">
	<cfargument name="folderlist" required="false" type="string">
	<!--- Param --->
	<cfparam name="arguments.folderlist" default="">
	<cfparam name="flist" default="">
	<!--- Query: Get current folder_id_r --->
	<cfquery datasource="#variables.dsn#" name="qry">
	SELECT folder_name, folder_id_r, folder_id
	FROM #session.hostdbprefix#folders
	WHERE folder_id = <cfqueryparam value="#arguments.folder_id_r#" cfsqltype="CF_SQL_VARCHAR">
	AND host_id = <cfqueryparam cfsqltype="cf_sql_numeric" value="#session.hostid#">
	</cfquery>
	<!--- Set the current values into the list --->
	<cfset flist = qry.folder_name & "|" & qry.folder_id & "|" & qry.folder_id_r & ";" & arguments.folderlist>
	<!--- If the folder_id_r is not the same the passed one --->
	<cfif qry.folder_id_r NEQ arguments.folder_id_r>
		<!--- Call this function again --->
		<cfinvoke method="getbreadcrumb" folder_id_r="#qry.folder_id_r#" folderlist="#flist#" />
	</cfif>
	<!--- Return --->	
	<cfreturn flist>
</cffunction>

</cfcomponent>
