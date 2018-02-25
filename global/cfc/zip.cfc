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
<cfcomponent displayname = "Zip Component"
             hint        = "A collections of functions that supports the Zip and GZip functionality by using the Java Zip file API.">

	<cfscript>

		/* Create Objects */
		ioFile      = CreateObject("java","java.io.File");
		ioInput     = CreateObject("java","java.io.FileInputStream");
		ioOutput    = CreateObject("java","java.io.FileOutputStream");
		ioBufOutput = CreateObject("java","java.io.BufferedOutputStream");
		zipFile     = CreateObject("java","java.util.zip.ZipFile");
		zipEntry    = CreateObject("java","java.util.zip.ZipEntry");
		zipInput    = CreateObject("java","java.util.zip.ZipInputStream");
		zipOutput   = CreateObject("java","java.util.zip.ZipOutputStream");
		gzInput     = CreateObject("java","java.util.zip.GZIPInputStream");
		gzOutput    = CreateObject("java","java.util.zip.GZIPOutputStream");
		objDate     = CreateObject("java","java.util.Date");
		jthread     = CreateObject("java","java.lang.Thread");

		/* Set Variables */
		this.os = Server.OS.Name;
		this.slash = "/";
		
		/*
		if(FindNoCase("Windows", this.os)) this.slash = "\";
		else                               this.slash = "/";
		*/

	</cfscript>

	<!--- -------------------------------------------------- --->
	<!--- AddFiles --->
	<cffunction name="AddFiles" access="public" output="no" returntype="boolean" >

		<!--- Function Arguments --->
		<cfargument name="zipFilePath" required="yes" type="string"                >
		<cfargument name="files"       required="no"  type="string"                >
		<cfargument name="directory"   required="no"  type="string"                >
		<cfargument name="filter"      required="no"  type="string"  default=""    >
		<cfargument name="recurse"     required="no"  type="boolean" default="no"  >
		<cfargument name="compression" required="no"  type="numeric" default="9"   >
		<cfargument name="savePaths"   required="no"  type="boolean" default="no"  >

		<cfscript>

			/* Default variables */
			var i = 0;
			var l = 0;
			var buffer    = RepeatString(" ",1024).getBytes();
			var entryPath = "";
			var entryFile = "";

			try
			{
				/* Initialize Zip file */
				ioOutput.init(PathFormat(arguments.zipFilePath));
				zipOutput.init(ioOutput);
				zipOutput.setLevel(arguments.compression);

				/* Get files list array */
				if(IsDefined("arguments.files"))
					files = ListToArray(PathFormat(arguments.files), "|");

				else if(IsDefined("arguments.directory"))
				{
					files = FilesList(arguments.directory, arguments.filter, arguments.recurse);
					arguments.directory = PathFormat(arguments.directory);
				}

				/* Loop over files array */
				for(i=1; i LTE ArrayLen(files); i=i+1)
				{
					if(FileExists(files[i]))
					{
						path = files[i];
						
						jthread.yield();
						
						// Get entry path and file
						entryPath = GetDirectoryFromPath(path);
						entryFile = GetFileFromPath(path);

						// Remove drive letter from path
						if(arguments.savePaths EQ "yes" AND Right(ListFirst(entryPath, this.slash), 1) EQ ":")
							entryPath = ListDeleteAt(entryPath, 1, this.slash);

						// Remove directory from path
						else if(arguments.savePaths EQ "no")
						{
							if(IsDefined("arguments.directory"))  entryPath = ReplaceNoCase(entryPath, arguments.directory, "", "ALL");
							else if(IsDefined("arguments.files")) entryPath = "";
						}

						// Remove slash at first
						if(Len(entryPath) GT 1 AND Left(entryPath, 1) EQ this.slash)      entryPath = Right(entryPath, Len(entryPath)-1);
						else if(Len(entryPath) EQ 1 AND Left(entryPath, 1) EQ this.slash) entryPath = "" ;

						//  Skip if entry with the same name already exsits
						try
						{
							ioFile.init(path);
							ioInput.init(ioFile.getPath());
							
							jthread.yield();
							
							zipEntry.init(entryPath & entryFile);
							zipOutput.putNextEntry(zipEntry);
							
							jthread.yield();

							l = ioInput.read(buffer);
							
							jthread.yield();
							
							while(l GT 0)
							{
								zipOutput.write(buffer, 0, l);
								l = ioInput.read(buffer);
							}
							
							jthread.yield();
							
							zipOutput.closeEntry();
							ioInput.close();
							
							jthread.yield();
							
						}

						catch(java.util.zip.ZipException ex)
						{ skip = "yes"; }
					}
				}
				
				jthread.yield();
				
				/* Close Zip file */
				zipOutput.close();
				
				jthread.yield();
				
				/* Return true */
				return true;
			}

			catch(Any expr)
			{
				/* Close Zip file */
				zipOutput.close();

				/* Return false */
				return false;
			}

		</cfscript>

	</cffunction>

	<!--- -------------------------------------------------- --->
	<!--- DeleteFiles --->
	<cffunction name="DeleteFiles" access="public" output="no" returntype="boolean" >

		<!--- Function Arguments --->
		<cfargument name="zipFilePath" required="yes" type="string" >
		<cfargument name="files"       required="yes" type="string" >

		<cfscript>

			/* NOTICE: There is no function in the Java API to delete entrys from a Zip file.
			           So we have to create a workaround for this function. At first we create
					   a new temporary Zip file and save there all entrys, excluded the delete
					   files. Then we delete the orginal Zip file and rename the temporary Zip
					   file. */

			/* Default variables */
			var l = 0;
			var buffer = RepeatString(" ",1024).getBytes();

			/* Convert to the right path format */
			arguments.zipFilePath = PathFormat(arguments.zipFilePath);

			try
			{
				/* Open Zip file and get Zip file entries */
				zipFile.init(arguments.zipFilePath);
				entries = zipFile.entries();

				/* Create a new temporary Zip file */
				ioOutput.init(PathFormat(arguments.zipFilePath & ".temp"));
				zipOutput.init(ioOutput);

				/* Loop over Zip file entries */
				while(entries.hasMoreElements())
				{
					entry = entries.nextElement();

					if(NOT entry.isDirectory())
					{
						/* Create a new entry in the temporary Zip file */
						if(NOT ListFindNoCase(arguments.files, entry.getName(), "|"))
						{
							// Set entry compression
							zipOutput.setLevel(entry.getMethod());

							// Create new entry in the temporary Zip file
							zipEntry.init(entry.getName());
							zipOutput.putNextEntry(zipEntry);

							inStream = zipFile.getInputStream(entry);
							l        = inStream.read(buffer);

							while(l GT 0)
							{
								zipOutput.write(buffer, 0, l);
								l = inStream.read(buffer);
							}

							// Close entry
							zipOutput.closeEntry();
						}
					}
				}

				/* Close the orginal Zip and the temporary Zip file */
				zipFile.close();
				zipOutput.close();

				/* Delete the orginal Zip file */
				ioFile.init(arguments.zipFilePath).delete();

				/* Rename the temporary Zip file */
				zipTemp   = ioFile.init(arguments.zipFilePath & ".temp");
				zipRename = ioFile.init(arguments.zipFilePath);
				zipTemp.renameTo(zipRename);

				/* Return true */
				return true;
			}

			catch(Any expr)
			{
				/* Close the orginal Zip and the temporary Zip file */
				zipOutput.close();
				zipFile.close();

				/* Delete the temporary Zip file, if exists */
				if(FileExists(arguments.zipFilePath & ".temp"))
					ioFile.init(arguments.zipFilePath & ".temp").delete();

				/* Return false */
				return false;
			}

		</cfscript>

	</cffunction>

	<!--- -------------------------------------------------- --->
	<!--- Extract --->
	<cffunction name="Extract" access="public" output="no" returntype="boolean" >

		<!--- Function Arguments --->
		<cfargument name="zipFilePath"      required="yes" type="string"                              >
		<cfargument name="extractPath"      required="no"  type="string"  default="#ExpandPath(".")#" >
		<cfargument name="extractFiles"     required="no"  type="string"                              >
		<cfargument name="useFolderNames"   required="no"  type="boolean" default="yes"               >
		<cfargument name="overwriteFiles"   required="no"  type="boolean" default="no"                >
		<cfargument name="suppressMetadata" required="no"  type="boolean" default="no"                >

		<cfscript>

			/* Default variables */
			var l = 0;
			var entries  = "";
			var entry    = "";
			var name     = "";
			var path     = "";
			var filePath = "";
			var buffer   = RepeatString(" ",1024).getBytes();

			/* Convert to the right path format */
			arguments.zipFilePath = PathFormat(arguments.zipFilePath);
			arguments.extractPath = PathFormat(arguments.extractPath);

			/* Check if the 'extractPath' string is closed */
			lastChr = Right(arguments.extractPath, 1);

			/* Set an slash at the end of string */
			if(lastChr NEQ this.slash)
				arguments.extractPath = arguments.extractPath & this.slash;

			try
			{
				/* Open Zip file */
				zipFile.init(arguments.zipFilePath);

				/* Zip file entries */
				entries = zipFile.entries();

				/* Loop over Zip file entries */
				while(entries.hasMoreElements())
				{
					entry = entries.nextElement();
					name  = entry.getName();

					/* Suppress Metadata only if 'suppressMetadata' is 'yes' */
					if((arguments.suppressMetadata EQ 'yes') AND 
					  ((name.substring(0,2) NEQ "__") AND (name.toLowerCase().indexOf("ds_store") LT 0) AND (name.indexOf("._") LT 0) AND (name.toLowerCase().indexOf("thumbs.db") LT 0)))
					{
						if(NOT entry.isDirectory())
						{
							/* Create directory only if 'useFolderNames' is 'yes' */
							if(arguments.useFolderNames EQ "yes")
							{
								lenPath = Len(name) - Len(GetFileFromPath(name));
	
								if(lenPath) path = extractPath & Left(name, lenPath);
								else        path = extractPath;
	
								if(NOT DirectoryExists(path))
								{
									ioFile.init(path);
									ioFile.mkdirs();
								}
							}
	
							/* Set file path */
							if(arguments.useFolderNames EQ "yes") filePath = arguments.extractPath & name;
							else                                  filePath = arguments.extractPath & GetFileFromPath(name);
	
							/* Extract files. Files would be extract when following conditions are fulfilled:
							   If the 'extractFiles' list is not defined,
							   or the 'extractFiles' list is defined and the entry filename is found in the list,
							   or the file already exists and 'overwriteFiles' is 'yes'. */
							if((NOT IsDefined("arguments.extractFiles")
							    OR (IsDefined("arguments.extractFiles") AND ListFindNoCase(arguments.extractFiles, GetFileFromPath(name), "|")))
							   AND (NOT FileExists(filePath) OR (FileExists(filePath) AND arguments.overwriteFiles EQ "yes")))
							{
								// Skip if entry contains special characters
								try
								{
									ioOutput.init(filePath);
									ioBufOutput.init(ioOutput);
	
									inStream = zipFile.getInputStream(entry);
									l        = inStream.read(buffer);
	
									while(l GTE 0)
									{
										ioBufOutput.write(buffer, 0, l);
										l = inStream.read(buffer);
									}
	
									inStream.close();
									ioBufOutput.close();
									ioOutput.close();
								}
	
								catch(Any Expr)
								{ skip = "yes"; }
							}
						}
					}
				}

				/* Close the Zip file */
				zipFile.close();

				/* Return true */
				return true;
			}

			catch(Any expr)
			{
				/* Close the Zip file */
				zipFile.close();

				/* Return false */
				return false;
			}

		</cfscript>

	</cffunction>

	<!--- -------------------------------------------------- --->
	<!--- List --->
	<cffunction name="List" access="public" output="no" returntype="query" >
		<!--- Function Arguments --->
		<cfargument name="zipFilePath" required="yes" type="string" >
		<cfargument name="suppressMetadata" required="no"  type="boolean" default="no" >

		<cfscript>

			/* Default variables */
			var i = 0;
			var entries = "";
			var entry   = "";
			var name    = "";
			var cols    = "entry,directory,filename,date,size,packed,ratio,crc";
			var query   = QueryNew(cols);

			cols = ListToArray(cols);

			/* Open Zip file */
			zipFile.init(arguments.zipFilePath);

			/* Zip file entries */
			entries = zipFile.entries();

			/* Fill query with data */
			while(entries.hasMoreElements())
			{
				entry = entries.nextElement();
				name  = entry.getName();

				/* Suppress Metadata only if 'suppressMetadata' is 'yes' */
				if((arguments.suppressMetadata EQ 'yes') AND 
				  ((name.substring(0,2) NEQ "__") AND (name.toLowerCase().indexOf("ds_store") LT 0) AND (name.indexOf("._") LT 0) AND (name.toLowerCase().indexOf("thumbs.db") LT 0)))
				{
					if(NOT entry.isDirectory())
					{
						QueryAddRow(query, 1);
	
						qEntry     = PathFormat(entry.getName());
						qDirectory = GetDirectoryFromPath(qEntry);
						qFileName  = GetFileFromPath(qEntry);
						qDate      = objDate.init(entry.getTime());
						qSize      = entry.getSize();
						qPacked    = entry.getCompressedSize();
						qCrc       = entry.getCrc();
	
						if(qSize GT 0) qRatio = Round(Evaluate(100-((qPacked*100)/qSize))) & "%";
						else           qRatio = "0%";
	
						for(i=1; i LTE ArrayLen(cols); i=i+1)
							QuerySetCell(query, cols[i], Trim(Evaluate("q#cols[i]#")));
					}
				}
			}

			/* Close the Zip File */
			zipFile.close();

			/* Return query */
			return query;

		</cfscript>

	</cffunction>

	<!--- -------------------------------------------------- --->
	<!--- gzipAddFile --->
	<cffunction name="gzipAddFile" access="public" output="no" returntype="boolean" >

		<!--- Function Arguments --->
		<cfargument name="gzipFilePath" required="yes" type="string" >
		<cfargument name="filePath"     required="yes" type="string" >

		<cfscript>

			/* Default variables */
			var l = 0;
			var buffer     = RepeatString(" ",1024).getBytes();
			var gzFileName = "";
			var outputFile = "";

			/* Convert to the right path format */
			arguments.gzipFilePath = PathFormat(arguments.gzipFilePath);
			arguments.filePath     = PathFormat(arguments.filePath);

			/* Check if the 'extractPath' string is closed */
			lastChr = Right(arguments.gzipFilePath, 1);

			/* Set an slash at the end of string */
			if(lastChr NEQ this.slash)
				arguments.gzipFilePath = arguments.gzipFilePath & this.slash;

			try
			{

				/* Set output gzip file name */
				gzFileName = getFileFromPath(arguments.filePath) & ".gz";
				outputFile = arguments.gzipFilePath & gzFileName;

				ioInput.init(arguments.filePath);
				ioOutput.init(outputFile);
				gzOutput.init(ioOutput);

				l = ioInput.read(buffer);

				while(l GT 0)
				{
					gzOutput.write(buffer, 0, l);
					l = ioInput.read(buffer);
				}

				/* Close the GZip file */
				gzOutput.close();
				ioOutput.close();
				ioInput.close();

				/* Return true */
				return true;
			}

			catch(Any expr)
			{ return false; }

		</cfscript>

	</cffunction>

	<!--- -------------------------------------------------- --->
	<!--- gzipExtract --->
	<cffunction name="gzipExtract" access="public" output="no" returntype="boolean" >

		<!--- Function Arguments --->
		<cfargument name="gzipFilePath" required="yes" type="string"                             >
		<cfargument name="extractPath"  required="no"  type="string" default="#ExpandPath(".")#" >

		<cfscript>

			/* Default variables */
			var l = 0;
			var buffer     = RepeatString(" ",1024).getBytes();
			var gzFileName = "";
			var outputFile = "";

			/* Convert to the right path format */
			arguments.gzipFilePath = PathFormat(arguments.gzipFilePath);
			arguments.extractPath  = PathFormat(arguments.extractPath);

			/* Check if the 'extractPath' string is closed */
			lastChr = Right(arguments.extractPath, 1);

			/* Set an slash at the end of string */
			if(lastChr NEQ this.slash)
				arguments.extractPath = arguments.extractPath & this.slash;

			try
			{
				/* Set output file name */
				gzFileName = getFileFromPath(arguments.gzipFilePath);
				outputFile = arguments.extractPath & Left(gzFileName, Len(gzFileName)-3);

				/* Initialize gzip file */
				ioOutput.init(outputFile);
				ioInput.init(arguments.gzipFilePath);
				gzInput.init(ioInput);

				while(l GTE 0)
				{
					ioOutput.write(buffer, 0, l);
					l = gzInput.read(buffer);
				}

				/* Close the GZip file */
				gzInput.close();
				ioInput.close();
				ioOutput.close();

				/* Return true */
				return true;
			}

			catch(Any expr)
			{ return false; }

		</cfscript>

	</cffunction>

	<!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->
	<!--- Private functions for this component --->
	<!--- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ --->

	<!--- -------------------------------------------------- --->
	<!--- FilesList --->
	<cffunction name="FilesList" access="private" output="no" returntype="array" >

		<!--- Function Arguments --->
		<cfargument name="directory" required="yes" type="string"               >
		<cfargument name="filter"    required="no"  type="string"  default=""   >
		<cfargument name="recurse"   required="no"  type="boolean" default="no" >

		<cfset var i = 0>
		<cfset var n = 0>
		<cfset var dir   = "">
		<cfset var array = ArrayNew(1)>

		<cfdirectory action    = "list"
					 name      = "dir"
		             directory = "#PathFormat(arguments.directory)#"
					 filter    = "#arguments.filter#">

		<cfscript>

			/* Loop over directory query */
			for(i=1; i LTE dir.recordcount; i=i+1)
			{
				path = PathFormat(dir.directory[i] & this.slash & dir.name[i]);

				/* Add file to array */
				if(dir.type[i] eq "file")
					ArrayAppend(array, path);

				/* Get files from sub directorys and add them to the array */
				else if(dir.type[i] EQ "dir" AND arguments.recurse EQ "yes")
				{
					subdir = FilesList(path, arguments.filter, arguments.recurse);

					for(n=1; n LTE ArrayLen(subdir); n=n+1)
						ArrayAppend(array, subdir[n]);
				}
			}

			/* Return array */
			return array;

		</cfscript>

	</cffunction>

	<!--- -------------------------------------------------- --->
	<!--- PathFormat --->
	<cffunction name="PathFormat" access="private" output="no" returntype="string" >

		<!--- Function Arguments --->
		<cfargument name="path" required="yes" type="string" >

		<cfif FindNoCase("Windows", this.os)>
			<cfset arguments.path = Replace(arguments.path, "/", "\", "ALL")>
		<cfelse>
			<cfset arguments.path = Replace(arguments.path, "\", "/", "ALL")>
		</cfif>

		<cfreturn arguments.path>

	</cffunction>

</cfcomponent>