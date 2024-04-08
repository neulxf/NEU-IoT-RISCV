/*------------------------------------------------------------------------------
--------------------------------------------------------------------------------
Copyright (c) 2016, Loongson Technology Corporation Limited.

All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this 
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, 
this list of conditions and the following disclaimer in the documentation and/or
other materials provided with the distribution.

3. Neither the name of Loongson Technology Corporation Limited nor the names of 
its contributors may be used to endorse or promote products derived from this 
software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
DISCLAIMED. IN NO EVENT SHALL LOONGSON TECHNOLOGY CORPORATION LIMITED BE LIABLE
TO ANY PARTY FOR DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE 
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT 
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
--------------------------------------------------------------------------------
------------------------------------------------------------------------------*/

//*************************************************************************
//   > File Name   : soc_top.v
//   > Description : SoC, included cpu, 1 x 3 bridge,
//                   inst ram, confreg, data ram, vga
// 
//           ---------------------------------------
//           |                 cpu                 |
//           ---------------------------------------
//         inst|                           | data
//             |                           | 
//             |                 ---------------------
//             |                 |    1 x 3 bridge   |
//             |                 ---------------------
//             |             --------|     |     |---------           
//             |             |             |              |
//      -------------   -----------   -----------    -----------
//      | inst ram  |   | data ram|   | confreg |    | confreg |
//      -------------   -----------   -----------    -----------
//
//   > Author      : LOONGSON
//   > Date        : 2024-04-02
//*************************************************************************

//for simulation:
//1. if define SIMU_USE_PLL = 1, will use clk_pll to generate cpu_clk/timer_clk,
//   and simulation will be very slow.
//2. usually, please define SIMU_USE_PLL=0 to speed up simulation by assign
//   cpu_clk/timer_clk = clk.
//   at this time, cpu_clk/timer_clk frequency are both 100MHz, same as clk.
`define SIMU_USE_PLL 0 //set 0 to speed up simulation

module soc_lite_top #(parameter SIMULATION=1'b0)
(
    input         resetn, 
    input         clk,

    //------gpio-------
    output [15:0] led,
    input  [15:0] switches, 
    output        h_sync_o,
    output        v_sync_o,
    output [ 3:0] vga_red_o,
    output [ 3:0] vga_green_o,
    output [ 3:0] vga_blue_o
);
//debug signals
wire [63:0] debug_wb_pc;
wire [7 :0] debug_wb_rf_wen;
wire [4 :0] debug_wb_rf_wnum;
wire [63:0] debug_wb_rf_wdata;

//clk and resetn
wire cpu_clk;
wire timer_clk;
reg cpu_resetn;
always @(posedge cpu_clk)
begin
    cpu_resetn <= resetn;
end
generate if(SIMULATION && `SIMU_USE_PLL==0)
begin: speedup_simulation
    assign cpu_clk   = clk;
    assign timer_clk = clk;
end
else
begin: pll
    clk_pll clk_pll
    (
        .clk_in1 (clk),
        .cpu_clk (cpu_clk),
        .timer_clk (timer_clk)
    );
end
endgenerate
//cpu inst sram
wire        cpu_inst_en;
wire [ 7:0] cpu_inst_wen;
wire [63:0] cpu_inst_addr;
wire [63:0] cpu_inst_wdata;
wire [63:0] cpu_inst_rdata;
//cpu data sram
wire        cpu_data_en;
wire [ 7:0] cpu_data_wen;
wire [63:0] cpu_data_addr;
wire [63:0] cpu_data_wdata;
wire [63:0] cpu_data_rdata;

//data sram
wire        data_sram_en;
wire [ 7:0] data_sram_wen;
wire [63:0] data_sram_addr;
wire [63:0] data_sram_wdata;
wire [63:0] data_sram_rdata;
// vga
wire        vga_en;
wire [7 :0] vga_wen;
wire [63:0] vga_addr;
wire [63:0] vga_wdata;
wire [63:0] vga_rdata;
//conf
wire        conf_en;
wire [ 7:0] conf_wen;
wire [63:0] conf_addr;
wire [63:0] conf_wdata;
wire [63:0] conf_rdata;

//cpu
mycpu_top cpu(
    .clk              (cpu_clk   ),
    .rst_n            (cpu_resetn),  //low active

    .inst_sram_en     (cpu_inst_en   ),
    .inst_sram_we     (cpu_inst_wen  ),
    .inst_sram_addr   (cpu_inst_addr ),
    .inst_sram_wdata  (cpu_inst_wdata),
    .inst_sram_rdata  (cpu_inst_rdata),
    
    .data_sram_en     (cpu_data_en   ),
    .data_sram_we     (cpu_data_wen  ),
    .data_sram_addr   (cpu_data_addr ),
    .data_sram_wdata  (cpu_data_wdata),
    .data_sram_rdata  (cpu_data_rdata),

    //debug
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_we   (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);


dual_port_ram_64  u_ram(
    .clka  (cpu_clk             ),
    .ena   (cpu_inst_en         ),
    .wea   (cpu_inst_wen        ),
    .addra (cpu_inst_addr[17:3] ),
    .dina  (cpu_inst_wdata      ),
    .douta (cpu_inst_rdata      ),
    .clkb  (cpu_clk             ),
    .enb   (data_sram_en        ),
    .web   (data_sram_wen       ),
    .addrb (data_sram_addr[17:3]),
    .dinb  (data_sram_wdata     ),
    .doutb (data_sram_rdata     )
);

bridge_1x3 u_bridge_1x3(
    .clk             (cpu_clk         ),
    .resetn          (cpu_resetn      ),

    .cpu_data_en     (cpu_data_en     ),
    .cpu_data_wen    (cpu_data_wen    ),
    .cpu_data_addr   (cpu_data_addr   ),
    .cpu_data_wdata  (cpu_data_wdata  ),
    .cpu_data_rdata  (cpu_data_rdata  ),

    .data_sram_en    (data_sram_en    ),
    .data_sram_wen   (data_sram_wen   ),
    .data_sram_addr  (data_sram_addr  ),
    .data_sram_wdata (data_sram_wdata ),
    .data_sram_rdata (data_sram_rdata ),
    .vga_en          (vga_en          ),
    .vga_wen         (vga_wen         ),
    .vga_addr        (vga_addr        ),
    .vga_wdata       (vga_wdata       ),
    .vga_rdata       (vga_rdata       ),
    .conf_en         (conf_en         ),
    .conf_wen        (conf_wen        ),
    .conf_addr       (conf_addr       ),
    .conf_wdata      (conf_wdata      ),
    .conf_rdata      (conf_rdata      ) 
);

//confreg
confreg #(.SIMULATION(SIMULATION)) confreg
(
    .clk         (cpu_clk          ), // i, 1
    .timer_clk   (timer_clk        ), // i, 1
    .resetn      (cpu_resetn       ), // i, 1
    .conf_en     (conf_en          ), // i, 1
    .conf_wen    (conf_wen[3:0]    ), // i, 4
    .conf_addr   (conf_addr[31:0]  ), // i, 32
    .conf_wdata  (conf_wdata[31:0] ), // i, 32
    .conf_rdata  (conf_rdata[31:0] ), // o, 32
    .led         (led              ), // o, 16
    .led_rg0     (                 ), // o, 2
    .led_rg1     (                 ), // o, 2
    .num_csn     (                 ), // o, 8
    .num_a_g     (                 ), // o, 7
    .switch      (switches         ), // i, 8
    .btn_key_col (                 ), // o, 4
    .btn_key_row (                 ), // i, 4
    .btn_step    (                 )  // i, 2
);

vga_ctrl vga_ctrl
(
    .cpu_clk     (cpu_clk          ),
    .rst_i       (~cpu_resetn      ),
    .vga_en      (vga_en           ),
    .vga_wen     (vga_wen          ),
    .vga_addr    (vga_addr[17:3]   ),
    .vga_wdata   (vga_wdata        ),
    .vga_rdata   (vga_rdata        ),
    .h_sync_o    (h_sync_o         ),
    .v_sync_o    (v_sync_o         ),
    .vga_red_o   (vga_red_o        ),
    .vga_green_o (vga_green_o      ),
    .vga_blue_o  (vga_blue_o       )
);

endmodule

