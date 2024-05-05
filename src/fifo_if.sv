`timescale 1ns / 1ps

interface fifo_if();

bit clock;
bit rst;
logic rd;
logic wr;
logic [7:0] data_in;
logic [7:0] data_out;
bit full;
bit empty;
    
endinterface
