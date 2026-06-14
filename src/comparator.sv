`timescale 1ns/1ps

module comparator #(parameter WIDTH = 10) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    output logic eq
);
    assign eq = (a == b);
endmodule
