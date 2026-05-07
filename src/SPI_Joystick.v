`default_nettype none
module SPI_Joystick (
	clock,
	reset,
	mosi,
	slave_select_n,
	sclk,
	miso,
	joy_x,
	joy_y,
	btn_j,
	btn_t,
	new_values,
	ledr,
	ledg,
	ledb
);
	input wire clock;
	input wire reset;
	output wire mosi;
	output wire slave_select_n;
	output wire sclk;
	input wire miso;
	output wire [9:0] joy_x;
	output wire [9:0] joy_y;
	output wire btn_j;
	output wire btn_t;
	output wire new_values;
	input wire [7:0] ledr;
	input wire [7:0] ledg;
	input wire [7:0] ledb;
	wire cmd_select;
	wire msg_load;
	wire shift_out_en;
	wire shift_in_en;
	wire capture_incoming;
	wire [39:0] cmd_set_led_rgb;
	wire [39:0] out_msg;
	wire [39:0] shifting_in;
	reg [39:0] in_msg;
	assign cmd_set_led_rgb = {8'b10000100, ledr, ledg, ledb, 8'h00};
	Mux2to1 #(40) msg_mux(
		.I0(40'h0000000000),
		.I1(cmd_set_led_rgb),
		.S(cmd_select),
		.Y(out_msg)
	);
	assign cmd_select = 1'b1;
	ShiftRegister_PISO #(
		.WIDTH(40),
		.LEFT(1)
	) sr_out(
		.D(out_msg),
		.en(shift_out_en),
		.load(msg_load),
		.clock(clock),
		.serial_out(mosi)
	);
	ShiftRegister_SIPO #(
		.WIDTH(40),
		.LEFT(1)
	) sr_in(
		.serial_in(miso),
		.en(shift_in_en),
		.clock(clock),
		.Q(shifting_in)
	);
	always @(posedge clock or posedge reset)
		if (reset)
			in_msg <= 1'sb0;
		else if (capture_incoming)
			in_msg <= shifting_in;
	assign joy_x = {in_msg[25:24], in_msg[39:32]};
	assign joy_y = {in_msg[9:8], in_msg[23:16]};
	assign btn_j = in_msg[0];
	assign btn_t = in_msg[1];
	SPI_Joystick_FSM fsm(
		.clock(clock),
		.reset(reset),
		.capture_incoming(capture_incoming),
		.shift_in_en(shift_in_en),
		.shift_out_en(shift_out_en),
		.msg_load(msg_load),
		.slave_select_n(slave_select_n),
		.sclk(sclk),
		.new_values(new_values)
	);
endmodule
module SPI_Joystick_FSM (
	clock,
	reset,
	msg_load,
	capture_incoming,
	slave_select_n,
	shift_in_en,
	shift_out_en,
	sclk,
	new_values
);
	input wire clock;
	input wire reset;
	output wire msg_load;
	output wire capture_incoming;
	output wire slave_select_n;
	output reg shift_in_en;
	output reg shift_out_en;
	output reg sclk;
	output wire new_values;
	reg [11:0] count;
	always @(posedge clock or posedge reset)
		if (reset)
			count <= 1'sb0;
		else if (count == 12'd3375)
			count <= 12'd375;
		else
			count <= count + 12'd1;
	assign msg_load = (count == 12'd375 ? 1'b1 : 1'b0);
	assign capture_incoming = (count == 12'd2320 ? 1'b1 : 1'b0);
	assign slave_select_n = ((count >= 12'd376) && (count < 12'd2946) ? 1'b0 : 1'b1);
	assign new_values = (count == 12'd2946 ? 1'b1 : 1'b0);
	always @(*)
		case (count)
			12'd376, 12'd401, 12'd426, 12'd451, 12'd476, 12'd501, 12'd526, 12'd551, 12'd815, 12'd840, 12'd865, 12'd890, 12'd915, 12'd940, 12'd965, 12'd990, 12'd1254, 12'd1279, 12'd1304, 12'd1329, 12'd1354, 12'd1379, 12'd1404, 12'd1429, 12'd1693, 12'd1718, 12'd1743, 12'd1768, 12'd1793, 12'd1818, 12'd1843, 12'd1868, 12'd2132, 12'd2157, 12'd2182, 12'd2207, 12'd2232, 12'd2257, 12'd2282, 12'd2307: shift_in_en = 1'b1;
			default: shift_in_en = 1'b0;
		endcase
	always @(*)
		case (count)
			12'd389, 12'd414, 12'd439, 12'd464, 12'd489, 12'd514, 12'd539, 12'd564, 12'd828, 12'd853, 12'd878, 12'd903, 12'd928, 12'd953, 12'd978, 12'd1003, 12'd1267, 12'd1292, 12'd1317, 12'd1342, 12'd1367, 12'd1392, 12'd1417, 12'd1442, 12'd1706, 12'd1731, 12'd1756, 12'd1781, 12'd1806, 12'd1831, 12'd1856, 12'd1881, 12'd2145, 12'd2170, 12'd2195, 12'd2220, 12'd2245, 12'd2270, 12'd2295: shift_out_en = 1'b1;
			default: shift_out_en = 1'b0;
		endcase
	always @(*)
		if (|{(12'd0 <= count) && (12'd376 >= count), (12'd389 <= count) && (12'd400 >= count), (12'd414 <= count) && (12'd425 >= count), (12'd439 <= count) && (12'd450 >= count), (12'd464 <= count) && (12'd475 >= count), (12'd489 <= count) && (12'd500 >= count), (12'd514 <= count) && (12'd525 >= count), (12'd539 <= count) && (12'd550 >= count), (12'd564 <= count) && (12'd814 >= count), (12'd828 <= count) && (12'd839 >= count), (12'd853 <= count) && (12'd864 >= count), (12'd878 <= count) && (12'd889 >= count), (12'd903 <= count) && (12'd914 >= count), (12'd928 <= count) && (12'd939 >= count), (12'd953 <= count) && (12'd964 >= count), (12'd978 <= count) && (12'd989 >= count), (12'd1003 <= count) && (12'd1253 >= count), (12'd1267 <= count) && (12'd1278 >= count), (12'd1292 <= count) && (12'd1303 >= count), (12'd1317 <= count) && (12'd1328 >= count), (12'd1342 <= count) && (12'd1353 >= count), (12'd1367 <= count) && (12'd1378 >= count), (12'd1392 <= count) && (12'd1403 >= count), (12'd1417 <= count) && (12'd1428 >= count), (12'd1442 <= count) && (12'd1692 >= count), (12'd1706 <= count) && (12'd1717 >= count), (12'd1731 <= count) && (12'd1742 >= count), (12'd1756 <= count) && (12'd1767 >= count), (12'd1781 <= count) && (12'd1792 >= count), (12'd1806 <= count) && (12'd1817 >= count), (12'd1831 <= count) && (12'd1842 >= count), (12'd1856 <= count) && (12'd1867 >= count), (12'd1881 <= count) && (12'd2131 >= count), (12'd2145 <= count) && (12'd2156 >= count), (12'd2170 <= count) && (12'd2181 >= count), (12'd2195 <= count) && (12'd2206 >= count), (12'd2220 <= count) && (12'd2231 >= count), (12'd2245 <= count) && (12'd2256 >= count), (12'd2270 <= count) && (12'd2281 >= count), (12'd2295 <= count) && (12'd2306 >= count), (12'd2320 <= count) && (12'hfff >= count)})
			sclk = 1'b0;
		else
			sclk = 1'b1;
endmodule
