`timescale 1ns/1ps

module dff (
    input  logic clk,
    input  logic rst_n,
    input  logic en,
    input  logic d,
    output logic q
);
    always_ff @(posedge clk) begin
        if (!rst_n)
            q <= 1'b0;
        else if (en)
            q <= d;
    end
endmodule
