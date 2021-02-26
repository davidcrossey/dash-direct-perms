# Dashboards Direct Permissions Module
## Outline
This project contains a wrapper API suite to facilitate implementation of basic permissions within Dashboards Direct.

The current logged in user is validated by cross referencing userID to configured list of permitted dashboards.

If the user is not permitted to view a dashboard, the 'Error' dashboard will be returned instead.

---
## Setup
Copy all files to your ~/dash folder.

Note - You will need to an extra dashboard 'Error' and update the GUID in dash.q to return the error dashboard to a user who doesn't have permission to view the chosen dashboard. 

---
## Pre-requisite files 

In order to enable permission on Dashboards Direct in the absence of the Control infrastructure, the below steps can be followed in order to enable permissions across the dashboards:

1. Ensure the below files are present in the ROOT directory of your Dashboard Direct installation:
    - dashboards.csv (CSV with list of Dashboard GUIDS and associated user groups)
    - usergroups.csv (CSV with list of users, and their associated user groups)
    - dash.q (modified version of original file to enable permissioning- loads permissions.q)
    - permissions.q (custom permissions logic- called by dash.q)
    - data/connections/webserver.json (webserver connection)
        - this is an example file. If not used, please ensure you create a "kdb connection" to your websever on the data sources within the Permissions Manager module. 

    Note - if the dashboards.csv and/or usergroups.csv are not added, default files will be created on startup.

2. Ensure the following two lines are present in your startup q file (permissions.q), so that the PERMISSIONS_DIR environmental variable is set for the Permissions Manager Dashboard to be usable.

```
if[.z.o like "w*";`PERMISSIONS_DIR setenv (system "cd"),"\\"];
if[.z.o like "l*";`PERMISSIONS_DIR setenv raze (system "pwd"),"/"];
```

3. Ensure that the 'Permissions Manager' and 'Error' dashboards are both present in the /data/dashboards directory of your installation

The GUIDs of both these dashboards is listed below:

```
Permissions Manager | 6be07d93-e60c-cb79-d70d-a5b02b4f209f.JSON
Error | 10ec73be-e822-7e49-1159-037697f15bf1
```
The associated zip file included with this MD file will contain both of the above dashboards.

**Note** If the user wishes to use a seperate Error Dashboard, they simply need to update the .perms.denyDashName value in the permissions.q script, or update the value in memory on the q web server process.

---
## Starting Dashboards Direct

To start the application, execute the two following commands

```
q sample/demo.q
q dash.q -p 10001 -u users
```

Note demo.q is purely to provide sample data to various out of the box dashboards; it is not needed for any functional purpose regarding the permissions module.

---
## Accessing the Dashboards Direct application
Once both of the above q instances are initialised successfully, please navigate to the following URL: http://localhost:10001/edit.

In order to access the 'Permissions Manager' dashboard, the user logging in will need to be a member of the 'admin' usergroup, in order to access the UI and update permissions for other users.
In the default user file provided in this ZIP attachment, the user1 profile has such access, whereas user 2 does not. (see below):

user,usergroup
----------------
user1,admin
user2,developer|analyst

In the above example, user1 and user2 belong to multiple usergroups, which are separated by '|'. The updated dash.q file logic will then deconstruct the usergroup value and ensure each user has access to all dashboards associated with the group provided in the users file.

---
## Updating Permissions

On the 'Permissions Manager' there are two tabs:
- Dashboards
- User Groups

### Dashboards Permissions
- On the Dashboards Permission tab, this is a single datagrid that shows all available Dashboards within the application, with both the URL GUID value,associated display name and associated user groups. 
    - This reads in the dashboards.csv file from PERMISSIONS_DIR, which is created on startup of the process. 
- In order to update the dashboard permissions, simply click the 'Edit' button in the top right corner of the datagrid
    - Once this is clicked you will be able to edit the 'User Groups' value to add additional user groups, change the user group, add new dashboards via an additional row, or remove permissions for a specific dashboard. 
    - Once you are finished with editing, please ensure that the 'Submit Changes' icon is clicked. 
    - An 'Update Query Executed Successfully' message will appear once this is completed, and the dashboards.csv file on disk will be updated accordingly.

### User Group Permissions
- On the User Group Permissions tab, there is a single datagrid. This datagrid is used to view and update permissions for the usergroups.csv file on disk. 
- To update the permissions for a specific user, add permissions for a new user, or delete an existing user, simply click the 'Edit' icon in the top right corner of the dashboard.
    - Once all changes have been made, and you are ready to save, click the 'Submit Changes' icon. 
    - An 'Update Query Executed Successfully' message will appear once this is completed, and the usergroups.csv file on disk will be updated accordingly.

---
## Considerations
1. Before starting the application, ensure that the dashboards.csv and usergroups.csv are populated with valid values for the first user you intend to login as. 

    It is also recommended that on first load, the usergroups.csv should have at least one single user who is a member of the *admin* * user group. 

    That user will then be able to access the Permissions Manager dashboard, and from there set up all future permissions for other users.

2. When a specific user is logged into Dashboards Direct and permissioning is enabled, and is only permissioned to view a select number of dashboards, the dropdown dashboard list will only display the names of those dashboards which they have permission to view. This is accomplished through overriding the .api.dashList function (explained in detail below).

    If an admin user updates a user's permissions on the Permissions Manager UI, in order for the dashboard dropdown list to update for that user, they simply need to refresh their browser tab.

---
## Technical Notes

The below information provides more granular details on what changes have been made to the .dash.q and permissions.q files to facilitate permissions, for future developers to use to enhance the existing code base and debug were required.

### .dash.q changes

A new namespace was introduced to accommodate the permissions on DD: the *.perms* namespace loaded via the permissions.q file.

### .perms.namespace

#### .perms variables

The *.perms.path* namespace contains two filepaths:

1. .perms.paths.dashboards:filepath for the dashboards.csv file from disk.
2. .perms.paths.usergroups:filepath for the usergroups.csv file from disk.

Both of the above utilise the `PERMISSIONS_DIR environmental variable to find the root install directory where these CSV will reside.

The *.perms* namespace contains two variables:

1. perms.enabled: This is a boolean value which reads the command line parameters to see what the -u value was. If the 'users' file was included in the command line parameters when starting the q webserver process with the amended dash.q, the variable is set to TRUE and all modified functions below will be executed. If set to FALSE, then the below will not be executed, and the original code will execute as expected.

2. perms.denyDashName: This is a string value which takes the canonical name of the deny dashboard you wish to return to users who are not permissioned to view a given dashboard. This can be updated in-memory to point to another dashboard.

#### .perms tables
1. .perms.ui: a table with a list of the dashboards and the usergroup as a PK (Showing which user groups can access which dashboard). Is read in from disk using the .perms.paths.dashboard file location (and is parsed by the .perms.readCfg and .perms.parseGroup functions)
2. .perms.ug: a table with two columns, PK is the usergroups (.e.g. admin, developer), and the user column for each user associated with a user group. This is read in from disk using the .perms.paths.usergroups file location (and is parsed by the .perms.readCfg and .perms.parseGroup functions)
3. .perms.cfg: This table is the concatenation of the above two tables, with user as the PK, and the additional usergroups and dashboards for which they have access.
4. .perms.userList: Table with the user as the PK, and a list of the dashboard GUIDs that the user has access to. This table is explicitly used in the redefined .api.readDash, to check if the user should be allowed to view the dashboard or not.
5. .perms.dashList: a table with a list of the Dashboard GUIDs and their associated Display Names. Is written to the dashList flat file on startup and is updated as new dashboards are created and deleted.

#### .perms functions
1. .perms.readCfg: This function parses in both the dashboards.csv and usergroups.csv files on disk into KDB table format.
2. .perms.parseGroup: This function ungroups the usergroups value in both dashboards.csv and usergroups.csv files, so if there any values delimited by | (.e.g. admin|developer) a separate row will be included in the global tables for each user-usergroup pairing.
3. .perms.refreshDash: This function is called to ensure that the most up to date dashboards.csv and usergroups.csv files are loaded into memory and used for validation once the modified .api.dashRead function is called.
4. .perms.deniedDash: If the user is trying to access a dashboard they are not permitted access to, this function is called, which returns the "Error" dashboard details instead of the dashboard the user is trying to view. This is called within the modified .api.dashRead function.
5. .perms.checkConfig: On startup, this function checks if the dashboards in-memory align with the dashboards.csv config. If there are any additional dashboards in-memory, they are added to the dashboards.csv config with readAll access. For example, if the permissions module is disabled and other dashboards are created, this will ensure those dashboards have adequate baseline permisisons when the module is re-enabled.
6. .perms.log.out: This function adds simple logging messages to the server when the user adds/edit/deletes permissions on the Permissions Manager dashboard.

### API handler functions
To incorporate permissions, there were four .api functions that were overwritten

#### .api.dashRead
1. original function is redefined under *.api.dashRead_old*
2. If .perms.enabled is TRUE then the following is executed:
3. The .perms.refresh function is called to find the most update to date .perms.userList table to validate the user's dashboard access request. A comparison check is done to see if the dashboard GUID passed into the function as x exists in the table for that user. If the conditional check returns FALSE, the user doesn't have permission, and .perms.deniedDash is called to provide the 'Error' dashboard details in its place (instead of the target dashboard the user requested).
4. The original function is then called, *.api.dashRead_old*. If the user has permissions the Dashboard will load on localhost. If the user does not have permission they will be redirected to the 'Error' dashboard instead.
5. Please note, if .perms.enabled is set to FALSE, then none of the above takes place and the original .api.dashRead is called.

#### .api.dashUpsert
1. original function is redefined under *.api.dashUpsert_old*
2. If .perms.enabled is TRUE then the following is executed:
3. The dashboards.csv file is read in from disk using the .perms.readCfg function firstly, then the new dashboard is upserted to the KDB table. The new dashboard will always have the 'all' group listed under the usergroup value (Users will need to modify this on Permissions Manager once created). Once the new dashboard record is upserted, the updated table is saved back down to the dashboards.csv file on disk.
4. The .perms.refreshDash function is called to update the .perms.dashList table, and write the most up to date version to the dashList flat file on disk to be used by the Permissions Manager dashboard
5. Please note, if .perms.enabled is set to FALSE, then none of the above takes place and the original .api.dashUpsert function is called.

#### .api.dashDelete
1. original function is redefined under *.api.dashDelete_old*
2. If .perms.enabled is TRUE then the following is executed:
3. The dashboards.csv file is read in from disk using the .perms.readCfg function firstly, before the dashboard GUID present in X is subsequently deleted from the table. Once all dashboard records are removed, the updated table is saved back down to dashboards.csv on disk.
4. The .perms.refreshDash function is called to update the .perms.dashList table, and write the most up to date version to the dashList flat file on disk to be used by the Permissions Manager dashboard
5. Please note, if .perms.enabled is set to FALSE, then none of the above takes place and the original .api.dashDelete function is called.

#### .api.dashList
1. original function is redifined under *.api.dashList_old*
2. If .perms.enabled is TRUE then the following is executed:
3. Deserialise the json dash list object 
4. Update the dash list with readAll and current user permitted dashboards 
5. Reserialise the json dash list object and return
6. Please note, if .perms.enabled is set to FALSE, then none of the above takes place and the original .api.dashList function is called.

---
## Known Issues
- KXAX-22722: Permissions Manager can only be edited via the 'edit' URL i.e. https://localhost:10001/edit/#6be07d93-e60c-cb79-d70d-a5b02b4f209f

---
## Dashboards Version supported
- 1.2.3
- 1.2.4

## Authors
- David Crossey
- Gerard Dickson
---