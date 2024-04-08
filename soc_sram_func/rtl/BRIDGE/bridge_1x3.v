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
//   > File Name   : bridge_1x3.v
//   > Description : bridge between cpu_data and data ram, confreg
//   
//     master:        cpu_data
//                    /   |   \
//     1 x 3         /    |    \  
//     bridge:      /     |     \                    
//                 /      |      \       
//     slave: data_ram   VGA  Confreg
//
//   > Author      : LOONGSON
//   > Date        : 2024-04-02
//*************************************************************************
`define VAG_ADDR_BASE       4'hc // 32'hcxxx_xxxx
`define Confreg_ADDR_BASE   16'hbfaf // 32'hbfaf_xxxx
module bridge_1x3(
    input                           clk,          // clock 
    input                           resetn,       // reset, active low
    // master : cpu data
    input                           cpu_data_en,      // cpu data access enable
    input  [7                   :0] cpu_data_wen,     // cpu data write byte enable
    input  [63                  :0] cpu_data_addr,    // cpu data address
    input  [63                  :0] cpu_data_wdata,   // cpu data write data
    output [63                  :0] cpu_data_rdata,   // cpu data read data
    // slave : data ram 
    output                          data_sram_en,     // access data_sram enable
    output [7                   :0] data_sram_wen,    // write enable 
    output [63                  :0] data_sram_addr,   // address
    output [63                  :0] data_sram_wdata,  // data in
    input  [63                  :0] data_sram_rdata,  // data out
    // slave : VGA 
    output                          vga_en,         // access vga enable 
    output [7                   :0] vga_wen,         // access vga enable 
    output [63                  :0] vga_addr,       // address
    output [63                  :0] vga_wdata,      // write data
    input  [63                  :0] vga_rdata,      // read data
    // slave : confreg 
    output                          conf_en,          // access confreg enable 
    output [7                   :0] conf_wen,         // access confreg enable 
    output [63                  :0] conf_addr,        // address
    output [63                  :0] conf_wdata,       // write data
    input  [63                  :0] conf_rdata        // read data
);
wire sel_sram; // cpu data is from data ram
wire sel_vga;  // cpu data is from vga
wire sel_confreg;    // cpu data is from conf

reg sel_sram_r;  // reg of sel_dram 
reg sel_vga_r; // reg of sel_vga 
reg sel_confreg_r;   // reg of sel_confreg

assign sel_vga       = (cpu_data_addr[31:28] == `VAG_ADDR_BASE);
assign sel_confreg   = (cpu_data_addr[31:16] == `Confreg_ADDR_BASE); 
assign sel_sram      = ~sel_vga & ~sel_confreg;

// data sram
assign data_sram_en     = cpu_data_en  & sel_sram;
assign data_sram_wen    = cpu_data_wen & {8{sel_sram}};
assign data_sram_addr   = cpu_data_addr;
assign data_sram_wdata  = cpu_data_wdata;

// vga
assign vga_en     = cpu_data_en  & sel_vga;
assign vga_wen    = cpu_data_wen & {8{sel_vga}};
assign vga_addr   = cpu_data_addr;
assign vga_wdata  = cpu_data_wdata;

// conf
assign conf_en     = cpu_data_en  & sel_confreg;
assign conf_wen    = cpu_data_wen & {8{sel_confreg}};
assign conf_addr   = cpu_data_addr;
assign conf_wdata  = cpu_data_wdata;

always @ (posedge clk)
begin
    if (!resetn)
    begin
        sel_sram_r  <= 1'b0;
        sel_vga_r <= 1'b0;
        sel_confreg_r   <= 1'b0;
    end
    else
    begin
        sel_sram_r  <= sel_sram;
        sel_vga_r <= sel_vga;
        sel_confreg_r   <= sel_confreg;
    end
end

assign cpu_data_rdata   = {64{sel_sram_r}}    & data_sram_rdata
                        | {64{sel_vga_r}}     & vga_rdata
                        | {64{sel_confreg_r}} & conf_rdata;

endmodule

