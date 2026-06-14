`timescale 1ns/1ps

module cache_cu (
    input  logic clk,
    input  logic rst_n,
    
    input  logic rden,
    input  logic wren,
    input  logic req_read,
    input  logic req_write,
    input  logic hit,
    input  logic dirty,
    
    output logic try_read,
    output logic try_write,
    output logic do_fill,
    output logic do_write_hit,
    output logic do_lru_update,
    output logic mrden,
    output logic mwren,
    output logic [2:0] current_state_out
);
    typedef enum logic [2:0] {
      STATE_IDLE,
      STATE_READ_HIT,
      STATE_READ_MISS,
      STATE_WRITE_HIT,
      STATE_WRITE_MISS,
      STATE_REPLACE,
      STATE_FETCH,
      STATE_FILL
   } state_t;

   state_t current_state, next_state;
   assign current_state_out = current_state;

   always_ff @(posedge clk) begin
       if (!rst_n) current_state <= STATE_IDLE;
       else current_state <= next_state;
   end

   always_comb begin
      next_state = current_state;
      try_read = 1'b0;
      try_write = 1'b0;
      do_fill = 1'b0;
      do_write_hit = 1'b0;
      do_lru_update = 1'b0;
      mrden = 1'b0;
      mwren = 1'b0;

      case (current_state)
         STATE_IDLE: begin
            if (rden && hit) begin
               next_state = STATE_READ_HIT;
               do_lru_update = 1'b1;
            end else if (rden) begin
               next_state = STATE_READ_MISS;
            end else if (wren && hit) begin
               next_state = STATE_WRITE_HIT;
               do_lru_update = 1'b1;
            end else if (wren) begin
               next_state = STATE_WRITE_MISS;
            end
            
            if (rden || wren) begin
                try_read = rden;
                try_write = wren;
            end
         end

         STATE_READ_HIT: begin
            next_state = STATE_IDLE;
         end

         STATE_READ_MISS: begin
            if (dirty)
               next_state = STATE_REPLACE;
            else
               next_state = STATE_FETCH;
         end

         STATE_WRITE_MISS: begin
            if (dirty)
               next_state = STATE_REPLACE;
            else
               next_state = STATE_FETCH;
         end

         STATE_REPLACE: begin
            mwren = 1'b1;
            next_state = STATE_FETCH;
         end

         STATE_FETCH: begin
            mrden = 1'b1;
            next_state = STATE_FILL;
         end

         STATE_FILL: begin
            do_fill = 1'b1;
            if (req_read)
               next_state = STATE_READ_HIT;
            else if (req_write)
               next_state = STATE_WRITE_HIT;
            else
               next_state = STATE_IDLE;
         end

         STATE_WRITE_HIT: begin
            do_write_hit = 1'b1;
            next_state = STATE_IDLE;
         end

         default: begin
            next_state = STATE_IDLE;
         end
      endcase
   end
endmodule
