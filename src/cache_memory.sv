`timescale 1ns/1ps

module cache_memory #(
    parameter BLOCK_SIZE = 256,
    parameter TAG_WIDTH = 10,
    parameter INDEX_WIDTH = 8,
    parameter WORD_SIZE = 32,
    parameter NSETS = 256
) (
    input  logic                   clk,
    input  logic                   rst_n,
    
    // Command
    input  logic [INDEX_WIDTH-1:0] index,
    input  logic                   do_fill,
    input  logic                   do_write_hit,
    input  logic                   do_lru_update,
    
    // Data In
    input  logic [TAG_WIDTH-1:0]   in_tag,
    input  logic [BLOCK_SIZE-1:0]  in_data,
    input  logic [1:0]             target_way,
    
    // Data Out
    output logic                   hit,
    output logic [1:0]             hit_way,
    output logic [1:0]             evict_way,
    output logic [BLOCK_SIZE-1:0]  data_out,
    output logic                   dirty_out,
    output logic [TAG_WIDTH-1:0]   tag_out
);

    wire [NSETS-1:0] set_hit;
    wire [1:0]       set_hit_way   [0:NSETS-1];
    wire [1:0]       set_evict_way [0:NSETS-1];
    wire [BLOCK_SIZE-1:0] set_data [0:NSETS-1];
    wire [NSETS-1:0] set_dirty;
    wire [TAG_WIDTH-1:0] set_tag   [0:NSETS-1];

    genvar i;
    generate
        for (i = 0; i < NSETS; i = i + 1) begin : sets
            wire active = (index == i);
            four_way_set #(
                .BLOCK_SIZE(BLOCK_SIZE),
                .TAG_WIDTH(TAG_WIDTH),
                .WORD_SIZE(WORD_SIZE)
            ) set_inst (
                .clk(clk),
                .rst_n(rst_n),
                .active(active),
                .do_fill(do_fill & active),
                .do_write_hit(do_write_hit & active),
                .do_lru_update(do_lru_update & active),
                .in_tag(in_tag),
                .in_data(in_data),
                .target_way(target_way),
                
                .hit(set_hit[i]),
                .hit_way(set_hit_way[i]),
                .evict_way(set_evict_way[i]),
                .data_out(set_data[i]),
                .dirty_out(set_dirty[i]),
                .tag_out(set_tag[i])
            );
        end
    endgenerate

    // Output Muxing
    assign hit = set_hit[index];
    assign hit_way = set_hit_way[index];
    assign evict_way = set_evict_way[index];
    assign data_out = set_data[index];
    assign dirty_out = set_dirty[index];
    assign tag_out = set_tag[index];

endmodule
