/////////////////////////////////////////////////////////////
// Created by: Synopsys DC Expert(TM) in wire load mode
// Version   : O-2018.06-SP1
// Date      : Fri Apr 21 22:28:14 2023
/////////////////////////////////////////////////////////////
`timescale 1ns/1ps
`include "../18m.v"

module controller ( sclk, dclk, start, reset_n, inputL, inputR, frame, inReady, 
        outReady, outputL, outputR );
  input sclk, dclk, start, reset_n, inputL, inputR, frame;
  output inReady, outReady, outputL, outputR;
  wire   n19;

  TLATNX1M output_received_reg ( .D(1'b0), .GN(1'b1), .QN(n19) );
  TLATNX1M outputR_reg ( .D(1'b0), .GN(1'b1), .Q(outputR) );
  TLATNX1M outputL_reg ( .D(1'b0), .GN(1'b1), .Q(outputL) );
  AND2X1M U10 ( .A(frame), .B(n19), .Y(outReady) );
endmodule

