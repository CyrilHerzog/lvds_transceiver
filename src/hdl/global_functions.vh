/*
    Module  : GLOBAL_FUNCTIONS
    Version : 1.0
    Author  : Herzog Cyril
    Date    : 11.08.2024

*/


`ifndef GLOBAL_FUNCTIONS_VH
`define GLOBAL_FUNCTIONS_VH

// fun_sizeof_byte => return number of bytes to represent the data width
`define fun_sizeof_byte(width) (((((width) % 8) == 0) ? (width) : ((width) + 8 - ((width) % 8))) / 8)

// fun_padding_bits => return number of padding bits 
`define fun_padding_bits(WIDTH) ((8 - ((WIDTH) % 8)) % 8)

// fun_max => return the higher input
`define fun_max(a, b) (((a) >= (b)) ? (a) : (b))

`endif

 
