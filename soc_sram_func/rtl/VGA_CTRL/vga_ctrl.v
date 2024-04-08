`timescale 1ns / 1ps
module vga_ctrl
#(parameter SIMULATION=1'b0)
(       
    input             cpu_clk,          
    input             rst_i,          
    input             vga_en,
    input      [ 7:0] vga_wen,
    input      [14:0] vga_addr,
    input      [63:0] vga_wdata,
    output     [63:0] vga_rdata,
    output            h_sync_o,
    output            v_sync_o,
    output     [ 3:0] vga_red_o,
    output     [ 3:0] vga_green_o,
    output     [ 3:0] vga_blue_o
);

// Internal net connections
wire vga_clk;           // 108 MHz clock
wire active_q;          // '1' when horizontal and vertical counters are in display
wire [10:0] h_count_q;  // Horizontal pixel counter
wire [10:0] v_count_q;  // Vertical pixel counter
wire locked;

mmcm_vga vga_Clk(
// Clock out ports
.clk_out1(vga_clk),
.reset(rst_i),
.locked(locked),
.clk_in1(cpu_clk)
);

// VGA sync pulse generator and screen horizontal and vertical pixel counters
sync_gen vga_Sync(
    .rst_i(~locked),
    .pixel_clk_i(vga_clk),
    .h_sync_o(h_sync_o),
    .v_sync_o(v_sync_o),
    .h_count_o(h_count_q),
    .v_count_o(v_count_q),
    .active_o(active_q)
);

reg enb;
reg [7:0]web;
reg [63:0] dinb;

reg[14:0] addrb;
wire[63:0] doutb;

// 108Mhz
vga_dual_port_ram_64 img_ram (
  .clka   (cpu_clk     ),    // input wire clka
  .ena    (vga_en      ),      // input wire ena
  .wea    (vga_wen     ),      // input wire [7 : 0] wea
  .addra  (vga_addr    ),  // input wire [14 : 0] addra
  .dina   (vga_wdata   ),    // input wire [63 : 0] dina
  .douta  (vga_rdata   ),  // output wire [63 : 0] douta
  .clkb   (vga_clk     ),    // input wire clkb
  .enb    (enb         ),      // input wire enb
  .web    (web         ),      // input wire [7 : 0] web
  .addrb  (addrb       ),  // input wire [14 : 0] addrb
  .dinb   (dinb        ),    // input wire [63 : 0] dinb
  .doutb  (doutb       )  // output wire [63 : 0] doutb
);
`define img_width 11'd512
`define y_start 11'd20
reg[7:0]  current_data;
reg[3:0] current_data_index;//current data index
wire start;
assign start = (h_count_q<=11'd384+`img_width&&h_count_q>11'd384&&v_count_q<=`img_width+`y_start&&v_count_q>`y_start)?1'd1:1'd0;  

always @(posedge vga_clk)

    if(!locked) begin
            current_data<=8'b0;
            current_data_index<=4'b0;
            addrb<=15'b0;
            enb<=1'b0;
            web<=8'b0;
            dinb<=64'b0;
        end
     else if(v_count_q>`img_width+`y_start)begin
        addrb<=15'b0;
     end
    else
        begin
             if(v_count_q<=`img_width+`y_start) begin//the line need to be displayed
                if(enb==1'b1)
                  enb<=1'b0;
                if(h_count_q==11'd383)begin
                    enb<=1'b1;
                end
                if(start==1'b1) begin
                    current_data <= doutb[current_data_index*8+:8];
                    current_data_index <= current_data_index + 4'b1;
                  if(current_data_index==4'd6) begin  // fetch next data
                    enb<=1'b1;
                    addrb <= addrb + 15'b1;
                  end
                  if(current_data_index==4'd7)begin
                    current_data_index<=4'b0;
                  end
              end
             
            end
        end

// Display white screen
assign vga_blue_o  = (start==1'b1) ? {current_data[1:0],2'b0}:4'h0;
assign vga_green_o = (start==1'b1) ? {current_data[4:2],1'b0}:4'h0;
assign vga_red_o   = (start==1'b1) ? {current_data[7:5],1'b0}:4'h0;

/////////////////// ///////////////////////////////////////////////////////////////

endmodule
