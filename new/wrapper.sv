`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/16/2020 07:17:54 PM
// Design Name: 
// Module Name: wrapper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module wrapper(
    input  logic                     clk_i,
    input  logic                     rst_ni,
    input  logic                     flush_i,
    input  fu_data_t                 fu_data_i,
    input  logic                     mult_valid_i,
    output logic [63:0]              result_o,
    output logic                     mult_valid_o,
    output logic                     mult_ready_o,
    output logic [TRANS_ID_BITS-1:0] mult_trans_id_o
    );
    
    logic        multi_cycle_o;
    logic [63:0] multi_cycle_result_o;
    
    alu i_alu (
        .clk_i,          // Clock
        .rst_ni,         // Asynchronous reset active low
        .fu_data_i,
        .multi_cycle_o (multi_cycle_o),        // for bext, bdep
        .multi_cycle_result_o (multi_cycle_result_o), // for bext, bdep
        .result_o(),
        .alu_branch_res_o ()
    );
    
    mult i_mult (
    .clk_i,
    .rst_ni,
    .flush_i,
    .fu_data_i ,
    .multi_cycle_i (multi_cycle_o),	   // for bext, bdep
    .multi_cycle_result_i (multi_cycle_result_o), // for bext, bdep
    .mult_valid_i,
    .result_o,
    .mult_valid_o,
    .mult_ready_o,
    .mult_trans_id_o
);


    
    
endmodule
