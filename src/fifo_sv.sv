`timescale 1ns / 1ps
`include "fifo_if.sv"

module fifo_sv(fifo_if fifo);

fifo FIFO(
    .clk(fifo.clock),
    .rst(fifo.rst),
    .wr(fifo.wr),
    .rd(fifo.rd),
    .din(fifo.data_in),
    .dout(fifo.data_out),
    .full(fifo.full),
    .empty(fifo.empty)
);

endmodule
