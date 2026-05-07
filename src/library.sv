`default_nettype none
/*
 * Multiple testbenches and initial blocks exist.
 * use vlogan -sverilog -nc library.sv library_tests.sv
 *     vcs -sverilog -nc MODULE_NAME
 *     ./simv
 */

// A comparator checks if two inputs are equal, bit-for-bit.
module Comparator
  #(parameter WIDTH=4)
   (output logic             AeqB,
    input  logic [WIDTH-1:0] A, B);

  MagComp #(WIDTH) mc(.A,
                      .B,
                      .AeqB,
                      .AltB(),
                      .AgtB()
                     );

endmodule: Comparator

module MagComp
  #(parameter   WIDTH = 8)
  (output logic             AltB, AeqB, AgtB,
   input  logic [WIDTH-1:0] A, B);

  always_comb
    if ($isunknown(A) || $isunknown(B))
      {AeqB, AltB, AgtB} = 3'bxxx;
    else begin
      AeqB = (A == B);
      AltB = (A <  B);
      AgtB = (A >  B);
    end

endmodule: MagComp

module Adder
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] A, B,
   input  logic             cin,
   output logic [WIDTH-1:0] sum,
   output logic             cout);

  always_comb
    if ($isunknown(A) || $isunknown(B) || $isunknown(cin))
      {cout, sum} = 'x;
    else
      {cout, sum} = {1'b0, A} + {1'b0, B} + {{{WIDTH}{1'b0}}, cin};

endmodule : Adder

module Subtracter
  #(parameter WIDTH=8)
  (input  logic [WIDTH:0] A, B,
   input  logic           bin,
   output logic [WIDTH:0] diff,
   output logic           bout);

   assign {bout, diff} = A - B - bin;

endmodule : Subtracter

module Multiplexer
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0]         I,
   input  logic [$clog2(WIDTH)-1:0] S,
   output logic                     Y);

   always_comb
     if ($isunknown(S))
       Y = 'x;
     else
       Y = I[S];

endmodule : Multiplexer

module Mux2to1
  #(parameter WIDTH = 8)
  (input  logic [WIDTH-1:0] I0, I1,
   input  logic             S,
   output logic [WIDTH-1:0] Y);

  assign Y = (S) ? I1 : I0;

endmodule : Mux2to1

module Decoder
  #(parameter WIDTH=8)
  (input  logic [$clog2(WIDTH)-1:0] I,
   input  logic                     en,
   output logic [WIDTH-1:0]         D);

  always_comb begin
    D = '0;
    if (en)
      D = 1'b1 << I;
  end

endmodule : Decoder

module DFlipFlop
  (input  logic D,
   input  logic preset_L, reset_L, clock,
   output logic Q);

  always_ff @(posedge clock, negedge preset_L, negedge reset_L)
    if ((~preset_L) && (~reset_L))
      Q <= 1'bx;
    else if (~preset_L)
      Q <= 1'b1;
    else if (~reset_L)
      Q <= 1'b0;
    else
      Q <= D;

endmodule : DFlipFlop

module Register
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, clear, clock,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock)
    if (en)
      Q <= D;
    else if (clear)
      Q <= '0;

endmodule : Register

module Counter
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, clear, load, clock, up,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock)
    if (clear)
      Q <= {WIDTH {1'b0}};
    else if (load)
      Q <= D;
    else if (en)
      if (up)
        Q <= Q + 1'b1;
      else
        Q <= Q - 1'b1;

endmodule : Counter

module ShiftRegister
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, left, load, clock,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock)
    if (load)
      Q <= D;
    else if (en)
      if (left)
        Q <= {Q[WIDTH-2:0], 1'b0};
      else
        Q <= {1'b0, Q[WIDTH-1:1]};

endmodule : ShiftRegister

module ShiftRegister_PISO
  #(parameter WIDTH=8,
              LEFT=0) // Shifts to right by default.  Set to 1 to shift left.
  (input  logic [WIDTH-1:0] D,
   input  logic             en, load, clock,
   output logic             serial_out);

  logic [WIDTH-1:0] Q;
  assign serial_out = (LEFT) ? Q[WIDTH-1] : Q[0];

  always_ff @(posedge clock)
    if (load)
      Q <= D;
    else if (en)
      if (LEFT)
        Q <= {Q[WIDTH-2:0], 1'b0};
      else
        Q <= {1'b0, Q[WIDTH-1:1]};

endmodule : ShiftRegister_PISO

module ShiftRegister_SIPO
  #(parameter WIDTH=8,
              LEFT=0) // Shifts to right by default.  Set to 1 to shift left.
  (input  logic             serial_in,
   input  logic             en, clock,
   output logic [WIDTH-1:0] Q);

  always_ff @(posedge clock)
    if (en) begin
      if (LEFT)
        Q <= {Q[WIDTH-2:0], serial_in};
      else
        Q <= {serial_in, Q[WIDTH-1:1]};
    end

endmodule : ShiftRegister_SIPO

module BarrelShiftRegister
  #(parameter WIDTH=8)
  (input  logic [WIDTH-1:0] D,
   input  logic             en, load, clock,
   input  logic [      1:0] by,
   output logic [WIDTH-1:0] Q);

  logic [WIDTH-1:0] shifted;
  always_comb
    case (by)
      default: shifted = Q;
      2'b01: shifted = {Q[WIDTH-2:0], 1'b0};
      2'b10: shifted = {Q[WIDTH-3:0], 2'b0};
      2'b11: shifted = {Q[WIDTH-4:0], 3'b0};
    endcase

  always_ff @(posedge clock)
    if (load)
        Q <= D;
    else if (en)
        Q <= shifted;

endmodule : BarrelShiftRegister

module CountDownToZero
  #(parameter WIDTH=8)
  (input  logic             clock, load,
   input  logic [WIDTH-1:0] D,
   output logic             done);

  logic [WIDTH-1:0] count;

  Counter #(WIDTH) c(.en(1'b1),
                     .clear(1'b0),
                     .load,
                     .up(1'b0),
                     .D,
                     .Q(count),
                     .clock
                    );

  assign done = (count == {WIDTH {1'b0}});

endmodule : CountDownToZero

module OneShot
 #(parameter WIDTH=8)
  (input  logic go, clock, reset,
   output logic shot);

  logic [WIDTH-1:0] D;
  logic load, done;

  assign D = {WIDTH {1'b1}};

  CountDownToZero #(WIDTH) ctdz(.clock,
                                .load,
                                .D,
                                .done
                               );

  enum {INIT, SHOT} state, nextState;

  always_ff @(posedge clock, posedge reset)
    if (reset)
      state <= INIT;
    else
      state <= nextState;

  always_comb
    case (state)
      INIT: nextState = (go) ? SHOT : INIT;
      SHOT: nextState = (done) ? INIT : SHOT;
    endcase

  assign shot = (state == SHOT);
  assign load = (state == INIT) & go;

endmodule : OneShot

module Debouncer
  (input  logic bouncy,
   input  logic CLOCK_50,
   input  logic reset,
   output logic debounced);

  logic go, alarm;

  CountDownToZero #(16) ctdz(.clock(CLOCK_50),
                             .load(go),
                             .D(16'hFFFF),
                             .done(alarm)
                            );

  enum {ZERO, GO_TO_ONE, ONE, GO_TO_ZERO} state, nextState;

  always_ff @(posedge CLOCK_50, posedge reset)
    if (reset)
      state <= ZERO;
    else
      state <= nextState;

  always_comb
    case (state)
      ZERO:       nextState = (bouncy) ? GO_TO_ONE : ZERO;
      GO_TO_ONE:  nextState = (alarm) ? ONE : GO_TO_ONE;
      ONE:        nextState = (bouncy) ? ONE : GO_TO_ZERO;
      GO_TO_ZERO: nextState = (alarm) ? ZERO : GO_TO_ZERO;
    endcase

  always_comb begin
    go = 1'b0;
    case (state)
      ZERO: begin
              debounced = 1'b0;
              go = bouncy;
            end
      GO_TO_ONE: debounced = 1'b1;
      ONE: begin
             debounced = 1'b1;
             go = ~bouncy;
           end
      GO_TO_ZERO: debounced = 1'b0;
      default : {go, debounced} = 2'b00;
    endcase
  end

endmodule : Debouncer

module Synchronizer
  (input  logic clock, asynchronous,
   output logic synchronous);

  logic between;

  DFlipFlop dff1(.D(asynchronous),
                 .Q(between),
                 .preset_L(1'b1),
                 .reset_L(1'b1),
                 .clock
                );

  DFlipFlop dff2(.D(between),
                 .Q(synchronous),
                 .preset_L(1'b1),
                 .reset_L(1'b1),
                 .clock
                );

endmodule : Synchronizer

module Blink8LEDs // LEDs blink to show something is going on
  (input  logic       fastclock,  // 25-50MHz would be good
   output logic [7:0] led);

   logic [26:0] led_count;
   assign led[7:0] = led_count[26:19];

   Counter #(27) ledcounter(.D('0),
                            .Q(led_count),
                            .en(1'b1),
                            .clear(1'b0),
                            .load(1'b0),
                            .up(1'b1),
                            .clock(fastclock)
                           );
endmodule : Blink8LEDs
