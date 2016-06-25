/ Load qhandle.q utility
/ ---------------------------------------------------------------------

value "\\l ",(getenv `HOME),"/qhandle/lib/qhandle.q";

/ Create config variable to store path to qhandle config file
/ ---------------------------------------------------------------------

config:hsym `$(getenv `HOME) ,"/qhandle/example/config/config.csv";

/ Functions to be automatically called upon successful connection
/ ---------------------------------------------------------------------

getMKT:{ @[`.;`marketTimes;:;.handle.refRDB"marketTimes"] }
getPRC:{ @[`.;`priceData;:;.handle.refRDB"priceData"]     }
getADV:{ @[`.;`advData;:;.handle.refHDB"advData"]         }

/ .handle.init called within main to initialize connections on startup 
/ ---------------------------------------------------------------------

main:{
  .handle.init[config];
  show .handle.currentConfig;
 }

/ .handle.portClose located within .z.pc to handle disconnects
/ ---------------------------------------------------------------------

.z.pc:{
  .handle.portClose[x];
 }

main[`];
