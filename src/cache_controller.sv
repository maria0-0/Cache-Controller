
`timescale 1ns/1ps

module cache_controller #(
    parameter BLOCK_SIZE = 256,
    parameter ADDRESS_WIDTH = 21,
    parameter INDEX_WIDTH = 8,
    parameter TAG_WIDTH = 10,
    parameter OFFSET_WIDTH = 3,
    parameter WORD_SIZE = 32,
    parameter NSETS = 256,
    parameter NWAYS = 4
) (
    input logic                                  clock,
    input logic                                  rst_n,
    input logic [ADDRESS_WIDTH - 1:0]            caddress,
    input logic [WORD_SIZE - 1:0]                cdin,
    input logic [BLOCK_SIZE - 1:0]               mdin,
    input logic                                  rden,
    input logic                                  wren,
    output logic                                 hit,
    output logic [WORD_SIZE - 1:0]               cdout,
    output logic [BLOCK_SIZE - 1:0]              mdout,
    output logic [TAG_WIDTH + INDEX_WIDTH - 1:0] maddress,
    output logic                                 mrden,
    output logic                                 mwren
);

   localparam TAG_MSB           = 20;
   localparam TAG_LSB           = 11;
   localparam INDEX_MSB         = 10;
   localparam INDEX_LSB         = 3;
   localparam BLOCK_OFFSET_MSB  = 2;
   localparam BLOCK_OFFSET_LSB  = 0;

   wire [2:0] current_state;
   wire is_idle = (current_state == 3'b000); // STATE_IDLE
   wire is_fill = (current_state == 3'b111); // STATE_FILL
   wire is_evict = (current_state == 3'b101); // STATE_REPLACE
   
   wire latch_en = is_idle && (rden || wren);

   // Internal Latches explicitly built with registers
   logic [ADDRESS_WIDTH - 1:0]   req_addr;
   logic                         req_read;
   logic                         req_write;
   logic [WORD_SIZE - 1:0]       req_wdata;
   logic [1:0]                   latched_hit_way;
   logic [1:0]                   latched_evict_way;

   register #(.WIDTH(ADDRESS_WIDTH)) reg_req_addr (.clk(clock), .rst_n(rst_n), .en(latch_en), .d(caddress), .q(req_addr));
   dff reg_req_read (.clk(clock), .rst_n(rst_n), .en(latch_en), .d(rden), .q(req_read));
   dff reg_req_write (.clk(clock), .rst_n(rst_n), .en(latch_en), .d(wren), .q(req_write));
   register #(.WIDTH(WORD_SIZE)) reg_req_wdata (.clk(clock), .rst_n(rst_n), .en(latch_en), .d(cdin), .q(req_wdata));

   wire [ADDRESS_WIDTH - 1:0] active_addr = is_idle ? caddress : req_addr;
   wire [INDEX_WIDTH - 1:0]   active_index = active_addr[INDEX_MSB:INDEX_LSB];
   wire [TAG_WIDTH - 1:0]     active_tag = active_addr[TAG_MSB:TAG_LSB];
   wire [OFFSET_WIDTH - 1:0]  active_offset = active_addr[BLOCK_OFFSET_MSB:BLOCK_OFFSET_LSB];

   wire try_read, try_write, do_fill, do_write_hit, do_lru_update;
   wire [1:0] mem_hit_way, mem_evict_way;
   wire [BLOCK_SIZE-1:0] mem_data_out;
   wire [TAG_WIDTH-1:0] mem_tag_out;
   wire mem_dirty_out;

   wire latch_way_en = latch_en || is_fill;
   wire [1:0] next_latched_hit_way = is_fill ? latched_evict_way : mem_hit_way;
   
   register #(.WIDTH(2)) reg_hit_way (.clk(clock), .rst_n(rst_n), .en(latch_way_en), .d(next_latched_hit_way), .q(latched_hit_way));
   register #(.WIDTH(2)) reg_evict_way (.clk(clock), .rst_n(rst_n), .en(latch_en), .d(mem_evict_way), .q(latched_evict_way));

   wire [1:0] target_way = is_idle ? mem_hit_way : (is_fill || is_evict) ? latched_evict_way : latched_hit_way;

   cache_cu cu (
       .clk(clock),
       .rst_n(rst_n),
       .rden(rden),
       .wren(wren),
       .req_read(req_read),
       .req_write(req_write),
       .hit(hit),
       .dirty(mem_dirty_out),
       .try_read(try_read),
       .try_write(try_write),
       .do_fill(do_fill),
       .do_write_hit(do_write_hit),
       .do_lru_update(do_lru_update),
       .mrden(mrden),
       .mwren(mwren),
       .current_state_out(current_state)
   );

   cache_memory #(
       .BLOCK_SIZE(BLOCK_SIZE),
       .TAG_WIDTH(TAG_WIDTH),
       .INDEX_WIDTH(INDEX_WIDTH),
       .WORD_SIZE(WORD_SIZE),
       .NSETS(NSETS)
   ) mem_array (
       .clk(clock),
       .rst_n(rst_n),
       .index(active_index),
       .do_fill(do_fill),
       .do_write_hit(do_write_hit),
       .do_lru_update(do_lru_update),
       .in_tag(active_tag),
       .in_data(is_fill ? mdin : block_set_word(mem_data_out, active_offset, req_wdata)),
       .target_way(target_way),
       .hit(hit),
       .hit_way(mem_hit_way),
       .evict_way(mem_evict_way),
       .data_out(mem_data_out),
       .dirty_out(mem_dirty_out),
       .tag_out(mem_tag_out)
   );

   function automatic logic [WORD_SIZE - 1:0] block_get_word(
      input logic [BLOCK_SIZE - 1:0] block,
      input logic [OFFSET_WIDTH - 1:0] word_offset
   );
      return block[32 * word_offset +: WORD_SIZE];
   endfunction

   function automatic logic [BLOCK_SIZE - 1:0] block_set_word(
      input logic [BLOCK_SIZE - 1:0] block,
      input logic [OFFSET_WIDTH - 1:0] word_offset,
      input logic [WORD_SIZE - 1:0] word
   );
      logic [BLOCK_SIZE - 1:0] result;
      result = block;
      result[32 * word_offset +: WORD_SIZE] = word;
      return result;
   endfunction

   assign cdout = block_get_word(mem_data_out, active_offset);
   assign mdout = mem_data_out;
   assign maddress = is_evict ? {mem_tag_out, active_index} : {active_tag, active_index};

endmodule
