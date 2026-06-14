`timescale 1ns/1ps

module cache_line #(
    parameter BLOCK_SIZE = 256,
    parameter TAG_WIDTH = 10,
    parameter WORD_SIZE = 32
) (
    input  logic                   clk,
    input  logic                   rst_n,
    
    // Inputs
    input  logic [TAG_WIDTH-1:0]   in_tag,
    input  logic [BLOCK_SIZE-1:0]  in_data,
    input  logic                   write_data_en,
    input  logic                   write_tag_en,
    input  logic                   write_valid_en,
    input  logic                   in_valid,
    input  logic                   write_dirty_en,
    input  logic                   in_dirty,
    input  logic                   write_lru_en,
    input  logic [1:0]             in_lru,
    
    // Outputs
    output logic                   hit,
    output logic                   valid_out,
    output logic                   dirty_out,
    output logic [TAG_WIDTH-1:0]   tag_out,
    output logic [BLOCK_SIZE-1:0]  data_out,
    output logic [1:0]             lru_out
);

    // Structural Registers
    register #(.WIDTH(BLOCK_SIZE)) data_reg (
        .clk(clk), .rst_n(rst_n), .en(write_data_en), .d(in_data), .q(data_out)
    );
    
    register #(.WIDTH(TAG_WIDTH)) tag_reg (
        .clk(clk), .rst_n(rst_n), .en(write_tag_en), .d(in_tag), .q(tag_out)
    );
    
    dff valid_reg (
        .clk(clk), .rst_n(rst_n), .en(write_valid_en), .d(in_valid), .q(valid_out)
    );
    
    dff dirty_reg (
        .clk(clk), .rst_n(rst_n), .en(write_dirty_en), .d(in_dirty), .q(dirty_out)
    );
    
    register #(.WIDTH(2)) lru_reg (
        .clk(clk), .rst_n(rst_n), .en(write_lru_en), .d(in_lru), .q(lru_out)
    );
    
    // Tag Matching
    logic tag_match;
    comparator #(.WIDTH(TAG_WIDTH)) tag_cmp (
        .a(tag_out), .b(in_tag), .eq(tag_match)
    );
    
    // Hit Logic
    assign hit = valid_out & tag_match;

endmodule
