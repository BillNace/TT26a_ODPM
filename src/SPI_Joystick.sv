/*
 * Copyright (c) 2026 Bill Nace
 *
 */

`default_nettype none
module SPI_Joystick
  (input  logic clock, reset,  // Clock is assumed to be 25 MHz
   output logic mosi, slave_select_n, sclk,
   input  logic miso,
   output logic [9:0] joy_x, joy_y,
   output logic       btn_j, btn_t,
   output logic       new_values,  // asserted for one clock period when
                                   // new data arrives
   input  logic [7:0] ledr, ledg, ledb
  );

  logic cmd_select; // 0 is GetXYBtns, 1 is cmdSetLedRGB
  logic msg_load, shift_out_en, shift_in_en, capture_incoming;

  logic [39:0] cmd_set_led_rgb, out_msg, shifting_in, in_msg;
  assign cmd_set_led_rgb = {8'b1000_0100, ledr, ledg, ledb, 8'h00};

  // Only two messages can be sent, the "get XYBtns" (i.e. 0) or the set LED
  // This Mux chooses between the two
  Mux2to1 #(5*8) msg_mux (.I0(40'h00_00_00_00_00),  // Get XYBtns
                          .I1(cmd_set_led_rgb),
                          .S(cmd_select),
                          .Y(out_msg)
                         );

  assign cmd_select = 1'b1; // Upon reflection, I think I can just send
                            // the LED command over and over

  // SRs to send/receive messages
  // Load a message from the message mux into the output SR with msg_load
  // Only enable one time per sclk period
  ShiftRegister_PISO #(.WIDTH(5*8),
                       .LEFT(1)
                      ) sr_out (
                       .D(out_msg),
                       .en(shift_out_en),
                       .load(msg_load),
                       .clock,
                       .serial_out(mosi)
                      );

  // Every message received includes 5 bytes, with X,Y and Button data
  ShiftRegister_SIPO #(.WIDTH(5*8),
                       .LEFT(1)
                      ) sr_in (
                       .serial_in(miso),
                       .en(shift_in_en),
                       .clock,
                       .Q(shifting_in)
                      );

  // I don't want to read the incoming message when it is in the middle of
  // being transmitted.  Thus I'll register it.
  always_ff @(posedge clock, posedge reset)
    if (reset)
      in_msg <= '0;
    else
      if (capture_incoming)
        in_msg <= shifting_in;

  // in_msg[39:32] is Low byte of X
  //       [31:26] are zero padding
  //       [25:24] are high 2 bits of X
  //       [23:16] are low byte of Y
  //       [15:10] are zero padding
  //       [ 9: 8] are high 2 bits of Y
  //       [    7] is EXTPKT
  //       [ 6: 2] are zero padding
  //       [    1] is TRIGGER
  //       [    0] is JOYSTICK
  assign joy_x = {in_msg[25:24], in_msg[39:32]};
  assign joy_y = {in_msg[ 9: 8], in_msg[23:16]};
  assign btn_j = in_msg[0];
  assign btn_t = in_msg[1];

  // Need to be able to count a few things
  // 15uS between chip_select_low and first byte -> at 25Mhz is 375 clocks
  // 10uS inter-byte delay -> 250 clocks
  // 25uS after last byte before chip_select_high -> 625 clocks
  // sclk low -> 12 clocks
  // sclk high -> 13 clocks
  // This is documented in attached spreadsheet

  SPI_Joystick_FSM fsm(.clock,
                       .reset,
                       .capture_incoming,
                       .shift_in_en,
                       .shift_out_en,
                       .msg_load,
                       .slave_select_n,
                       .sclk,
                       .new_values
                       );

endmodule : SPI_Joystick

module SPI_Joystick_FSM
  (input  logic clock, reset,
   output logic msg_load, capture_incoming, slave_select_n,
   output logic shift_in_en, shift_out_en, sclk, new_values);

  // FSM Sequences through a big cycle, over and over.
  // First, we wait for MAX_ALARM to give the PIC a chance to wake up.
  // CS_LOW, msg_load
  // Wait 15uS
  // sclk = 1, shift_in_en
  // wait 13 clocks
  // sclk = 0, shift_out_en, done with bit 1
  // wait 12 clocks
  // sclk = 1, shift_in_en
  // wait 13 clocks
  // sclk = 0, shift_out_en, done with bit 2
  // etc.
  // Then an inter-byte delay of 250 clocks
  // Then repeat for Byte 2
  // etc for a total of 5 bytes.
  // Then a pause for 625 clocks before CS_HIGH
  // Then a substantial wait (429 clocks) before repeating the message

  logic [11:0] count;

  always_ff @(posedge clock, posedge reset)
    if (reset)
      count <= '0;
    else if (count == 12'd3375)
      count <= 12'd375;
    else
      count <= count + 12'd1;

  assign msg_load = (count == 12'd375) ? 1'b1 : 1'b0;
  assign capture_incoming = (count == 12'd2320) ? 1'b1 : 1'b0;
  assign slave_select_n = (count >= 12'd376 && count < 12'd2946) ? 1'b0 : 1'b1;
  assign new_values = (count == 12'd2946) ? 1'b1 : 1'b0;

  always_comb
    case (count)
      12'd376,
      12'd401,
      12'd426,
      12'd451,
      12'd476,
      12'd501,
      12'd526,
      12'd551,
      12'd815,
      12'd840,
      12'd865,
      12'd890,
      12'd915,
      12'd940,
      12'd965,
      12'd990,
      12'd1254,
      12'd1279,
      12'd1304,
      12'd1329,
      12'd1354,
      12'd1379,
      12'd1404,
      12'd1429,
      12'd1693,
      12'd1718,
      12'd1743,
      12'd1768,
      12'd1793,
      12'd1818,
      12'd1843,
      12'd1868,
      12'd2132,
      12'd2157,
      12'd2182,
      12'd2207,
      12'd2232,
      12'd2257,
      12'd2282,
      12'd2307: shift_in_en = 1'b1;
      default: shift_in_en = 1'b0;
    endcase

  always_comb
    case (count)
      12'd389,
      12'd414,
      12'd439,
      12'd464,
      12'd489,
      12'd514,
      12'd539,
      12'd564,
      12'd828,
      12'd853,
      12'd878,
      12'd903,
      12'd928,
      12'd953,
      12'd978,
      12'd1003,
      12'd1267,
      12'd1292,
      12'd1317,
      12'd1342,
      12'd1367,
      12'd1392,
      12'd1417,
      12'd1442,
      12'd1706,
      12'd1731,
      12'd1756,
      12'd1781,
      12'd1806,
      12'd1831,
      12'd1856,
      12'd1881,
      12'd2145,
      12'd2170,
      12'd2195,
      12'd2220,
      12'd2245,
      12'd2270,
      12'd2295 : shift_out_en = 1'b1;
      default  : shift_out_en = 1'b0;
    endcase

  always_comb
    case (count) inside
      [12'd0   : 12'd376],
      [12'd389 : 12'd400],
      [12'd414 : 12'd425],
      [12'd439 : 12'd450],
      [12'd464 : 12'd475],
      [12'd489 : 12'd500],
      [12'd514 : 12'd525],
      [12'd539 : 12'd550],
      [12'd564 : 12'd814],
      [12'd828 : 12'd839],
      [12'd853 : 12'd864],
      [12'd878 : 12'd889],
      [12'd903 : 12'd914],
      [12'd928 : 12'd939],
      [12'd953 : 12'd964],
      [12'd978 : 12'd989],
      [12'd1003 : 12'd1253],
      [12'd1267 : 12'd1278],
      [12'd1292 : 12'd1303],
      [12'd1317 : 12'd1328],
      [12'd1342 : 12'd1353],
      [12'd1367 : 12'd1378],
      [12'd1392 : 12'd1403],
      [12'd1417 : 12'd1428],
      [12'd1442 : 12'd1692],
      [12'd1706 : 12'd1717],
      [12'd1731 : 12'd1742],
      [12'd1756 : 12'd1767],
      [12'd1781 : 12'd1792],
      [12'd1806 : 12'd1817],
      [12'd1831 : 12'd1842],
      [12'd1856 : 12'd1867],
      [12'd1881 : 12'd2131],
      [12'd2145 : 12'd2156],
      [12'd2170 : 12'd2181],
      [12'd2195 : 12'd2206],
      [12'd2220 : 12'd2231],
      [12'd2245 : 12'd2256],
      [12'd2270 : 12'd2281],
      [12'd2295 : 12'd2306],
      [12'd2320 : 12'hFFF] : sclk = 1'b0;

      default : sclk = 1'b1;
    endcase

endmodule : SPI_Joystick_FSM
