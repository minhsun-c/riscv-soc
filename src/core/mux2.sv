`timescale 1ns / 1ps

/**
 * Module: mux2
 *
 * Description:
 * A generic 2-to-1 multiplexer used throughout the datapath for 
 * signal selection.
 *
 * @param WIDTH         The bit-width of the data inputs and output.
 *
 * @port sel_i          [Input]  [1:0]       Selection signal (0: selects a_i, 
 *                                           1: selects b_i).
 * @port a_i            [Input]  [WIDTH-1:0] Data input 0.
 * @port b_i            [Input]  [WIDTH-1:0] Data input 1.
 *
 * @port out_o          [Output] [WIDTH-1:0] Selected data output.
 */

module mux2 #(
    parameter WIDTH = 32
) (
    input              sel_i,
    input  [WIDTH-1:0] a_i,
    input  [WIDTH-1:0] b_i,
    output [WIDTH-1:0] out_o
);

  assign out_o = (sel_i) ? b_i : a_i;

endmodule
