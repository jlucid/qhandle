\c 1000 1000
\d .handle
// DEBUG : boolean scalar 
//     Set to 1b for writing debug messages to stdout 
//     Set to 0b to surpress debug messages
// --------------------------------------------------------------

DEBUG:1b;

// initialConfig: Keyed table 
//     Table used to store the initial configuration read from the csv file		 
// --------------------------------------------------------------

initialConfig:(
  [serviceName    :`symbol$()];
   handleName     :`symbol$();
   handleValue    :`int$();
   primary        :`symbol$();
   secondary      :`symbol$();
   autoSwitch     :`boolean$();
   connectActions :();
   activeHost     :`symbol$()
 );

// currentConfig: Keyed table 
//     Table used to display current connections state		 
// --------------------------------------------------------------

currentConfig:initialConfig;  

// readConfig: Function taking a single argument; the file path to csv config file 
//     Fuction used to read the config csv and populate initialConfig table		 
// --------------------------------------------------------------

readConfig:{[path]
  if[.handle.DEBUG;-1 ".handle.readConfig"];
  if[()~@[key;path;()];-2 "File path to config csv not valid: ";exit 0];    	
  @[`.handle;`initialConfig;0#];
  types:ssr[upper exec t from (meta .handle.initialConfig);" ";"*"]; 
  .handle.initialConfig:1!(types;enlist ",") 0: path;
 }

// init: Function taking a single argument; the file path to csv config file 
//     Fuction called on process startup. 
//     Used to initiate connections to primary hosts and perform actions if required
//     Function will automatically attempt connection to secondary if primary unavailable
// --------------------------------------------------------------

init:{[path]
  if[.handle.DEBUG;-1 ".handle.init"];
  .handle.readConfig[path];
  .handle.currentConfig:.handle.initialConfig;  
  services:exec serviceName from .handle.currentConfig;
  handlesPreviouslyInitialised:services where services in key .handle;
  @[hclose;;0Ni]'[.handle[handlesPreviouslyInitialised]];
  @[`.handle;services;:;0Ni];
  update handleValue:0Ni,activeHost:`none from `.handle.currentConfig;
  .handle.hostConnect[;`primary]'[exec serviceName from .handle.currentConfig];
 }


// hostStatus: Function taking two arguments; serviceName and host ( `primary or `secondary ) 
//     Function returns 1b if handle can be opened to service given host details
//     Function returns 0b if handle cannot be opened to service given host details
// --------------------------------------------------------------

hostStatus:{[servicename;host]  
  if[.handle.DEBUG;-1 ".handle.hostStatus"];
  h:@[hopen;hsym .handle.currentConfig[servicename][host];0Ni]; 
  $[0Ni~h;
     :0b
    [
     hclose h;
     :1b
    ]
  ];
 }

// updateConfig: Function taking 3 arguments argument
//     Function used to update handleValue and activeHost values in currentConfig table
// --------------------------------------------------------------

updateConfig:{[hvalue;ahost;sname]
  if[.handle.DEBUG;-1 ".handle.updateConfig"];
  update handleValue:hvalue,
         activeHost:ahost 
  from `.handle.currentConfig 
  where serviceName in sname;
 }

// handleClose: Function taking a single argument, the service name
//     Function used to close the current handle to a given service
//     Function updates the currentConfig table to reflect closing
// --------------------------------------------------------------

handleClose:{[servicename] 
  if[.handle.DEBUG;-1 ".handle.handleClose"];
  g:@[hclose;.handle[servicename];0Ni];
  .handle[servicename]:0Ni;
  updateConfig[0Ni;`none;servicename];
 }

// handleStatus: Function taking a single argument, the service name
//     Function used to determine if handle variable is still valid
//     Returns 1b if handle is valid
//     Returns 0b if handle is invalid
// --------------------------------------------------------------
                 
handleStatus:{[servicename] 
  if[.handle.DEBUG;-1 ".handle.handleStatus"];
  @[.handle[servicename];"1b";0b] 
 }

// hostCOnnect: Function taking two arguments, the service name and level
//     Function used to initialise connection to requested service
//     Updates status of currentConfig table
//     Performs failover switiching to backup service

hostConnect:{[servicename;requestedLevel]                          
  if[.handle.DEBUG;-1 ".handle.hostConnect"];
  .handle.handleClose[servicename];

  .handle[servicename]:@[hopen;hsym .handle.currentConfig[servicename][requestedLevel];0Ni];
  if[not 0Ni~.handle[servicename];
     updateConfig[.handle[servicename];requestedLevel;servicename];
     value .handle.currentConfig[servicename][`connectActions]
  ];

  if[(0Ni~.handle[servicename]) & (.handle.currentConfig[servicename;`autoSwitch]);
     if[.handle.DEBUG;-1 ".handle.hostConnect: Selecting backup"];
     backup:first (`primary`secondary except requestedLevel);
     .handle[servicename]:@[hopen;hsym .handle.currentConfig[servicename][backup];0Ni];
     if[not 0Ni~.handle[servicename];
        if[.handle.DEBUG;-1 ".handle.hostConnect: Performing actions on backup"];
	updateConfig[.handle[servicename];backup;servicename];
	value .handle.currentConfig[servicename][`connectActions]
     ];
  ];
 }

// tryPrimary: Function used to switch back to primary when connection to secondary is established
//     or no connections is available


tryPrimary:{
  onSecondary:exec serviceName
              from .handle.currentConfig
              where activeHost in `none`secondary;
  if[not count onSecondary;:()];

  primaryAvailable:onSecondary where (hostStatus[;`primary] each onSecondary);
  if[not count primaryAvailable;:()];


  {[service]

    if[.handle.DEBUG;-1 ".handle.tryPrimary"];
    name:first service;
    if[.handle.DEBUG;-1 ".handle.tryPrimary: Switching service ",string[name]];
    .handle.handleClose[name];
    if[.handle.DEBUG;-1 ".handle.tryPrimary: Closing current Handle for ",string[name]];
    .handle[name]:@[hopen;hsym .handle.currentConfig[name][`primary];0Ni];
    if[.handle.DEBUG;-1 ".handle.tryPrimary: New handle value is ",string[.handle[name]]];
    if[not 0Ni~.handle[name];
       updateConfig[.handle[name];`primary;name];
       value .handle.currentConfig[name][`connectActions]
    ];
  } each primaryAvailable;

 }




// portClose: Function taking a single argument, the handle value of closed service
//     Function used to update currentConfig table of port close event 
//     Handle to service is initialised back to 0Ni

portClose:{[x]

  if[.handle.DEBUG;-1 ".handle.portClose"];
  if[not x in abs value .handle.currentConfig[;`handleValue]; 
     if[.handle.DEBUG;-1 ".handle.portClose Disconnected host not in currentConfig"];
     :()
  ];    

  closedService:first exec serviceName 
                from .handle.currentConfig 
                where handleValue in abs[x]; 
  activeHostWas:.handle.currentConfig[closedService;`activeHost];

  .handle[closedService]:0Ni;
  updateConfig[.handle[closedService];`none;closedService];

  if[(.handle.currentConfig[closedService;`autoSwitch]);
     backup:first (`primary`secondary except activeHostWas);
     .handle[closedService]:@[hopen;hsym .handle.currentConfig[closedService][backup];0Ni];
     if[not 0Ni~.handle[closedService];
	updateConfig[.handle[closedService];backup;closedService];
        value .handle.currentConfig[closedService][`connectActions]
     ];
  ];
 }
\d .
�
