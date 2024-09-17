`ifndef _LVDS_TRANSCEIVER_DEFINES_
`define _LVDS_TRANSCEIVER_DEFINES_


// ****************************************************************************************
// 8B10B Encoding
`define K_CODE_START_DLLP  8'b00011100  //K28.0 0x1C
`define K_CODE_START_TLP   8'b00111100 // K28.1 0x3c
`define K_CODE_STOP        8'b01011100 // K28.2 0x5c
`define K_CODE_SKP         8'b01111100 // K28.3 0x7c



// transceiver mode
`define CONNECTION_TYPE_SOURCE 0
`define CONNECTION_TYPE_SINK   1
`define DEFAULT_CONNECTION_TYPE   `CONNECTION_TYPE_SOURCE

// fixed config parameter's
`define CONFIG_DLLP_WIDTH             16
`define CONFIG_TLP_ID_WIDTH           4
`define CONFIG_DLLP_BUFFER_ADDR_WIDTH 4
`define TIMEOUT_WIDTH                 8
`define CONST_DLLP_WIDTH              16
`define CONST_DLLP_BUFFER_ADDR_WIDTH  4

`define DEFAULT_CDC_BUFFER_ADDR_WIDTH 6

// *****************************************************************************************
// default user parameter



// crc 
`define DEFAULT_CRC_INIT    8'b11111111
`define DEFAULT_CRC_POLY    8'b00000111            
// tlp
`define BUFFER_TYPE_SYNC              0
`define BUFFER_TYPE_ASYNC             1
`define DEFAULT_TLP_WIDTH             32
`define DEFAULT_TLP_BUFFER_TYPE       `BUFFER_TYPE_SYNC
`define DEFAULT_TLP_BUFFER_ADDR_WIDTH 8

// *****************************************************************************************



`endif