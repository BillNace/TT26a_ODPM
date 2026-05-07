`default_nettype none

module SPI_Joystick_test();

  logic clock, reset, mosi, slave_select_n, sclk, miso;
  logic btn_j, btn_t, new_values;
  logic [9:0] joy_x, joy_y;
  logic [7:0] ledr, ledg, ledb;

  initial begin
    clock = 1'b0;
    reset = 1'b1;
    reset <= 1'b0;
    forever #5 clock = ~clock;
  end

  assign miso = 1'b1;
  assign ledr = 8'hF0;
  assign ledg = 8'h0F;
  assign ledb = 8'h12;

  SPI_Joystick sj(.*);

  initial begin
    $dumpfile("spi_joystick.vcd");
    $dumpvars();
  end

  initial begin
    for (int i = 0; i < 50_000; i++)
      @(posedge clock);
    $finish(2);
  end

endmodule : SPI_Joystick_test;

