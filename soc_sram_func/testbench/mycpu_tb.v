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
`timescale 1ns / 1ps

`define WORK_SPACE "../../../../../../../" // use your work_space 
`define TRACE_REF_FILE_PRFIX {`WORK_SPACE,"riscv-test64/"}
`define TRACE_REF_FILE(TEST_NAME) {`TRACE_REF_FILE_PRFIX,TEST_NAME,"-riscv64-nemu.lans"}
`define SOURCE_FILE(TEST_NAME) {`TRACE_REF_FILE_PRFIX,TEST_NAME,"-riscv64-nemu.data"}
`define CONFREG_NUM_REG      soc_lite.confreg.num_data
`define CONFREG_OPEN_TRACE   1'b1
`define CONFREG_NUM_MONITOR  1'b0
`define CONFREG_UART_DISPLAY soc_lite.confreg.write_uart_valid
`define CONFREG_UART_DATA    soc_lite.confreg.write_uart_data

module tb_top( );
reg resetn;
reg clk;

//goio
wire [15:0] led;
wire [15:0] switch;
wire        h_sync_o;
wire        v_sync_o;
wire [ 3:0] vga_red_o;
wire [ 3:0] vga_green_o;
wire [ 3:0] vga_blue_o;

always #10 clk=~clk;
soc_lite_top #(.SIMULATION(1'b1)) soc_lite
(
        .resetn     (resetn     ), 
        .clk        (clk        ),
        .led        (led        ),
        .switches   (switch     ),
        .h_sync_o   (h_sync_o   ),
        .v_sync_o   (v_sync_o   ),
        .vga_red_o  (vga_red_o  ),
        .vga_green_o(vga_green_o),
        .vga_blue_o (vga_blue_o )
);   

//soc lite signals
//"soc_clk" means clk in cpu
//"wb" means write-back stage in pipeline
//"rf" means regfiles in cpu
//"w" in "wen/wnum/wdata" means writing
wire soc_clk;
wire [63:0] debug_wb_pc;
wire [7 :0] debug_wb_rf_wen;
wire [4 :0] debug_wb_rf_wnum;
wire [63:0] debug_wb_rf_wdata;
assign soc_clk           = soc_lite.cpu_clk;
assign debug_wb_pc       = soc_lite.debug_wb_pc;
assign debug_wb_rf_wen   = soc_lite.debug_wb_rf_wen;
assign debug_wb_rf_wnum  = soc_lite.debug_wb_rf_wnum;
assign debug_wb_rf_wdata = soc_lite.debug_wb_rf_wdata;

//wdata[i*8+7 : i*8] is valid, only wehile wen[i] is valid
wire [63:0] debug_wb_rf_wdata_v;
assign debug_wb_rf_wdata_v[63:56] = debug_wb_rf_wdata[63:56] & {8{debug_wb_rf_wen[7]}};
assign debug_wb_rf_wdata_v[55:48] = debug_wb_rf_wdata[55:48] & {8{debug_wb_rf_wen[6]}};
assign debug_wb_rf_wdata_v[47:40] = debug_wb_rf_wdata[47:40] & {8{debug_wb_rf_wen[5]}};
assign debug_wb_rf_wdata_v[39:32] = debug_wb_rf_wdata[39:32] & {8{debug_wb_rf_wen[4]}};
assign debug_wb_rf_wdata_v[31:24] = debug_wb_rf_wdata[31:24] & {8{debug_wb_rf_wen[3]}};
assign debug_wb_rf_wdata_v[23:16] = debug_wb_rf_wdata[23:16] & {8{debug_wb_rf_wen[2]}};
assign debug_wb_rf_wdata_v[15: 8] = debug_wb_rf_wdata[15: 8] & {8{debug_wb_rf_wen[1]}};
assign debug_wb_rf_wdata_v[7 : 0] = debug_wb_rf_wdata[7 : 0] & {8{debug_wb_rf_wen[0]}};

//get reference result in falling edge
reg        trace_cmp_flag;
reg        debug_end;

reg [31:0] ref_wb_pc;
reg [4 :0] ref_wb_rf_wnum;
reg [63:0] ref_wb_rf_wdata_v;
reg [63:0] debug_rf [31:0];
reg [31:0] line;
reg [31:0] ref_line;
reg trash;

// open the trace file;
integer trace_ref;

always @(posedge soc_clk)
begin 
    #1;
    if (!resetn) begin
        line <= 32'b0;
    end
    if(|debug_wb_rf_wen && debug_wb_rf_wnum!=5'd0 && debug_rf[debug_wb_rf_wnum]!==debug_wb_rf_wdata_v && `CONFREG_OPEN_TRACE)
    begin
        trace_cmp_flag=1'b0;
        while (!trace_cmp_flag && !($feof(trace_ref)))
        begin
            $fscanf(trace_ref, "%h %h $%d %h", trace_cmp_flag,
                    ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata_v);
            line <= line + 1'b1;
        end
    end
end

//compare result in rsing edge 
reg debug_wb_err;
always @(posedge soc_clk)
begin
    #2;
    if(!resetn)
    begin
        debug_wb_err <= 1'b0;
        debug_rf[0] <= 0;
        debug_rf[1] <= 0;
        debug_rf[2] <= 0;
        debug_rf[3] <= 0;
        debug_rf[4] <= 0;
        debug_rf[5] <= 0;
        debug_rf[6] <= 0;
        debug_rf[7] <= 0;
        debug_rf[8] <= 0;
        debug_rf[9] <= 0;
        debug_rf[10] <= 0;
        debug_rf[11] <= 0;
        debug_rf[12] <= 0;
        debug_rf[13] <= 0;
        debug_rf[14] <= 0;
        debug_rf[15] <= 0;
        debug_rf[16] <= 0;
        debug_rf[17] <= 0;
        debug_rf[18] <= 0;
        debug_rf[19] <= 0;
        debug_rf[20] <= 0;
        debug_rf[21] <= 0;
        debug_rf[22] <= 0;
        debug_rf[23] <= 0;
        debug_rf[24] <= 0;
        debug_rf[25] <= 0;
        debug_rf[26] <= 0;
        debug_rf[27] <= 0;
        debug_rf[28] <= 0;
        debug_rf[29] <= 0;
        debug_rf[30] <= 0;
        debug_rf[31] <= 0;
    end
    else if(|debug_wb_rf_wen && debug_wb_rf_wnum!=5'd0 && debug_rf[debug_wb_rf_wnum]!==debug_wb_rf_wdata_v && `CONFREG_OPEN_TRACE)
    begin
        if (  (debug_wb_pc!==ref_wb_pc) || (debug_wb_rf_wnum!==ref_wb_rf_wnum)
            ||(debug_wb_rf_wdata_v!==ref_wb_rf_wdata_v) )
        begin
            $display("--------------------------------------------------------------");
            $display("[%t] Error!!!",$time);
            $display("    reference: PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h",
                      ref_wb_pc, ref_wb_rf_wnum, ref_wb_rf_wdata_v);
            $display("    mycpu    : PC = 0x%8h, wb_rf_wnum = 0x%2h, wb_rf_wdata = 0x%8h",
                      debug_wb_pc, debug_wb_rf_wnum, debug_wb_rf_wdata_v);
            $display("--------------------------------------------------------------");
            debug_wb_err <= 1'b1;
            #40;
            $finish;
        end
        else begin
            debug_rf[debug_wb_rf_wnum] <= debug_wb_rf_wdata_v;
        end
    end
end

//monitor test
initial
begin
    $timeformat(-9,0," ns",10);
    while(!resetn) #5;
    $display("==============================================================");
    $display("Test begin!");

    #10000;
    while(`CONFREG_NUM_MONITOR)
    begin
        #10000;
        $display ("        [%t] Test is running, debug_wb_pc = 0x%8h",$time, debug_wb_pc);
    end
end

//模拟串口打印
wire uart_display;
wire [7:0] uart_data;
assign uart_display = `CONFREG_UART_DISPLAY;
assign uart_data    = `CONFREG_UART_DATA;

always @(posedge soc_clk)
begin
    if(uart_display)
    begin
        if(uart_data==8'hff)
        begin
            ;//$finish;
        end
        else
        begin
            $write("%c",uart_data);
        end
    end
end

task unit_test;
input [64*8-1:0] test_name;
begin
    trash = 1'b1;
    trace_ref = $fopen(`TRACE_REF_FILE(test_name), "r");
    $fscanf(trace_ref, "%d", ref_line);
    $readmemh(`SOURCE_FILE(test_name),soc_lite.u_ram.mem);
    $display("        [%t] START TEST : \t%0s",$time, test_name);

    clk = 1'b0;
    resetn = 1'b0;
    #2000;
    resetn = 1'b1;

    // #5000
    while(ref_line!==line) begin
        #10
        trash = ~trash;
    end
    // $display("%d,%d",ref_line,line);
    if (ref_line==line) begin
        $display("        [%t] TEST PASS  : \t%0s",$time, test_name);
        // $finish;
    end
end
endtask

task unit_test_all;
begin
    unit_test("add");
    unit_test("addi");
    unit_test("addiw");
    unit_test("addw");
    unit_test("and");
    unit_test("andi");
    unit_test("auipc");
    unit_test("beq");
    unit_test("bge");
    unit_test("bgeu");
    unit_test("blt");
    unit_test("bltu");
    unit_test("bne");
    unit_test("jal");
    unit_test("jalr");
    unit_test("lb");
    unit_test("lbu");
    unit_test("ld");
    unit_test("lh");
    unit_test("lhu");
    unit_test("lui");
    unit_test("lw");
    unit_test("lwu");
    unit_test("or");
    unit_test("ori");
    unit_test("sb");
    unit_test("sd");
    unit_test("sh");
    unit_test("sll");
    unit_test("slli");
    unit_test("slliw");
    unit_test("sllw");
    unit_test("slt");
    unit_test("slti");
    unit_test("sltiu");
    unit_test("sltu");
    unit_test("sra");
    unit_test("srai");
    unit_test("sraiw");
    unit_test("sraw");
    unit_test("srl");
    unit_test("srli");
    unit_test("srliw");
    unit_test("srlw");
    unit_test("sub");
    unit_test("subw");
    unit_test("sw");
    unit_test("xor");
    unit_test("xori");

end
endtask

initial begin
    unit_test_all;
    $display("==============================================================");
    $display("Test end!");
    $display("----PASS!!!");
    $finish;
end
endmodule
