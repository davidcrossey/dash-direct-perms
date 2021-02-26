// setup dashboard direct permissioning
if[.z.o like "w*";`PERMISSIONS_DIR setenv (system "cd"),"\\"];
if[.z.o like "l*";`PERMISSIONS_DIR setenv raze (system "pwd"),"/"];

\d .perms
enabled:@[value;`enabled;1b];
defaultaccess:@[value;`defaultaccess;`];
/enabled:first (.Q.opt .z.X)[`u] like "users";

dashboards:{(hsym `$(getenv `PERMISSIONS_DIR),"dashboards.csv")};
usergroups:{(hsym `$(getenv `PERMISSIONS_DIR),"usergroups.csv")};

/ set empty configs, if none exist
if[not count key .perms.dashboards[];
    dashGuids:distinct "G"$(value {.j.k x[`description]} each .dash.dash)[`id];
    .perms.dashboards[] 0: csv 0: ([]dashboard:dashGuids;usergroups:count[dashGuids]#defaultaccess)];
if[not count key .perms.usergroups[];.perms.usergroups[] 0: csv 0: ([]user:`$();usergroups:`$())];

readCfg:{("SS";enlist csv) 0: x};
parseGroups:{`usergroups xkey ungroup update `$usergroups:"|" vs' string usergroups from x};

refresh:{
  .perms.ui:.perms.parseGroups .perms.readCfg .perms.dashboards[];
  .perms.readAll:exec dashboard from (0!.perms.ui) where null usergroups;
  .perms.ug:.perms.parseGroups .perms.readCfg .perms.usergroups[];
  .perms.cfg:`user xkey ungroup .perms.ui lj `usergroups xgroup .perms.ug;
  .perms.userList:select distinct dashboard by user from .perms.cfg
  };
refresh[];

refreshDash:{.perms.dashList:1!flip `id`name!(value {.j.k x[`description]} each .dash.dash)[`id`name]};
refreshDash[];

denyDashName:"Error"; / change here or set .perms.denyDashName in-memory to update default denied page
denyDashID:`$(`name xkey 0!.perms.dashList)[.perms.denyDashName][`id];

/ check to resolve any differences between .dash.dash and dashboards.csv; missing dashboards added to csv with readAll
checkConfig:{
    onDisk:asc (distinct (0!dashboards:1!.perms.readCfg .perms.dashboards[])`dashboard);
    inMem:asc `$exec id from .perms.dashList;

    if[not onDisk~inMem;
        .perms.dashboards[] 0: csv 0: {x upsert (y;defaultaccess)}/[dashboards;] inMem where not inMem in onDisk;
        .perms.refresh[]
        ]
    };
checkConfig[];

log.out:{0N!" - " sv string (.z.h;.z.p;`$x)};

\d .

// override dash[list|read|upsert|delete] API handlers for custom permissioning
/ dash list handler - restrict dropdown to accessible dashboards only; requires tab refresh to update
.api.dashList_old:.api.dashList;
.api.dashList:{.debug.dashList:x; dashList:.api.dashList_old x;
    if[.perms.enabled;
        dashList:.j.k each first each dashList;
        dashList:select from dashList where any id like/:string[.perms.readAll,.perms.userList[.dash.u][`dashboard]];
        dashList:([]description:.j.j each dashList);
        ];
    :dashList
    };

/ read handler - load error dashboard if not permissioned
.api.dashRead_old:.api.dashRead;
.api.dashRead:{.debug.dashRead:x; 
    if[.perms.enabled;
        .perms.refresh[]; 
        if[not x in .perms.readAll,.perms.userList[.dash.u][`dashboard]; x:.perms.denyDashID]]; 
    .api.dashRead_old x
    };

/ upsert handler - add permissions to all for new dashboard, refresh dashList and permissions.
.api.dashUpsert_old:.api.dashUpsert;
.api.dashUpsert:{.debug.dashUpsert:(x;y); .api.dashUpsert_old[x;y]; 
    if[.perms.enabled;
        dashboards:1!.perms.readCfg .perms.dashboards[];
        if[not x in key dashboards;
            .perms.dashboards[] 0: csv 0: dashboards upsert (x;defaultaccess);
            .perms.refreshDash[]]
        ]; 
    .api.dashRead x
    };

/ delete handler - clean up dashboard permissions on deletion and refresh dashlist
.api.dashDelete_old:.api.dashDelete;
.api.dashDelete:{.debug.dashDelete:x; .api.dashDelete_old x;
    if[.perms.enabled;
        .perms.dashboards[] 0: csv 0: delete from (.perms.readCfg .perms.dashboards[]) where dashboard=x;
        .perms.refreshDash[]]; 
    .api.dashRead x
    };

/ debug variables on server
/.z.ws_old:.z.ws;
/.z.ws:{0N!-9!.debug.ws:x; .z.ws_old x};