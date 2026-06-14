`timescale 1ns/1ps

module four_way_set #(
    parameter BLOCK_SIZE = 256,
    parameter TAG_WIDTH = 10,
    parameter WORD_SIZE = 32
) (
    input  logic                   clk,
    input  logic                   rst_n,
    
    // Commands
    input  logic                   active,          // Set is active
    input  logic                   do_fill,         // Triggers a line fill (cache_write on miss)
    input  logic                   do_write_hit,    // Triggers a word write on hit
    input  logic                   do_lru_update,   // Triggers LRU update on read/write hit
    
    // Data Inputs
    input  logic [TAG_WIDTH-1:0]   in_tag,
    input  logic [BLOCK_SIZE-1:0]  in_data,
    input  logic [1:0]             target_way,      // Which way to write to
    
    // Outputs
    output logic                   hit,
    output logic [1:0]             hit_way,
    output logic [1:0]             evict_way,
    output logic [BLOCK_SIZE-1:0]  data_out,
    output logic                   dirty_out,
    output logic [TAG_WIDTH-1:0]   tag_out
);

    logic [3:0] line_hit;
    logic [3:0] valid_vec;
    logic [3:0] dirty_vec;
    logic [BLOCK_SIZE-1:0] data_vec [0:3];
    logic [1:0] lru_vec [0:3];
    logic [TAG_WIDTH-1:0] tag_vec [0:3];
    
    logic [3:0] write_data_en;
    logic [3:0] write_tag_en;
    logic [3:0] write_valid_en;
    logic [3:0] write_dirty_en;
    logic [3:0] write_lru_en;
    logic [1:0] in_lru [0:3];
    logic [3:0] in_dirty;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : lines
            cache_line #(
                .BLOCK_SIZE(BLOCK_SIZE),
                .TAG_WIDTH(TAG_WIDTH),
                .WORD_SIZE(WORD_SIZE)
            ) line_inst (
                .clk(clk),
                .rst_n(rst_n),
                
                .in_tag(in_tag),
                .in_data(in_data),
                
                .write_data_en(write_data_en[i]),
                .write_tag_en(write_tag_en[i]),
                .write_valid_en(write_valid_en[i]),
                .in_valid(1'b1),
                .write_dirty_en(write_dirty_en[i]),
                .in_dirty(in_dirty[i]),
                .write_lru_en(write_lru_en[i]),
                .in_lru(in_lru[i]),
                
                .hit(line_hit[i]),
                .valid_out(valid_vec[i]),
                .dirty_out(dirty_vec[i]),
                .tag_out(tag_vec[i]),
                .data_out(data_vec[i]),
                .lru_out(lru_vec[i])
            );
        end
    endgenerate

    // Hit Logic
    assign hit_way = line_hit[0] ? 2'd0 :
                     line_hit[1] ? 2'd1 :
                     line_hit[2] ? 2'd2 :
                     line_hit[3] ? 2'd3 : 2'd0;
                     
    assign hit = active & (|line_hit);
    
    // Eviction Selection
    always_comb begin
        evict_way = 2'd0;
        if (!valid_vec[0]) evict_way = 2'd0;
        else if (!valid_vec[1]) evict_way = 2'd1;
        else if (!valid_vec[2]) evict_way = 2'd2;
        else if (!valid_vec[3]) evict_way = 2'd3;
        else begin
            if (lru_vec[0] == 2'd0) evict_way = 2'd0;
            else if (lru_vec[1] == 2'd0) evict_way = 2'd1;
            else if (lru_vec[2] == 2'd0) evict_way = 2'd2;
            else if (lru_vec[3] == 2'd0) evict_way = 2'd3;
        end
    end

    // Write Enables & LRU Update Logic
    always_comb begin
        for (int j = 0; j < 4; j = j + 1) begin
            write_data_en[j] = 1'b0;
            write_tag_en[j]  = 1'b0;
            write_valid_en[j]= 1'b0;
            write_dirty_en[j]= 1'b0;
            write_lru_en[j]  = 1'b0;
            in_dirty[j]      = 1'b0;
            in_lru[j]        = 2'd0;
            
            if (active) begin
                if (do_fill && (target_way == j[1:0])) begin
                    write_data_en[j] = 1'b1;
                    write_tag_en[j]  = 1'b1;
                    write_valid_en[j]= 1'b1;
                    write_dirty_en[j]= 1'b1;
                    in_dirty[j]      = 1'b0; // Clean on fill
                end
                
                if (do_write_hit && (target_way == j[1:0])) begin
                    write_data_en[j] = 1'b1;
                    write_dirty_en[j]= 1'b1;
                    in_dirty[j]      = 1'b1; // Dirty on write hit
                end
                
                // LRU Updates
                if (do_fill) begin
                    write_lru_en[j] = 1'b1;
                    if (target_way == j[1:0])
                        in_lru[j] = 2'd3;
                    else if (valid_vec[j])
                        in_lru[j] = lru_vec[j] - 1;
                    else
                        in_lru[j] = lru_vec[j];
                end
                
                if (do_lru_update && hit) begin
                    write_lru_en[j] = 1'b1;
                    if (hit_way == j[1:0])
                        in_lru[j] = 2'd3;
                    else if (valid_vec[j] && (lru_vec[j] > lru_vec[hit_way]))
                        in_lru[j] = lru_vec[j] - 1;
                    else
                        in_lru[j] = lru_vec[j];
                end
            end
        end
    end
    
    // Output Routing
    assign data_out = data_vec[target_way];
    assign dirty_out = dirty_vec[target_way];
    assign tag_out = tag_vec[target_way];

endmodule
