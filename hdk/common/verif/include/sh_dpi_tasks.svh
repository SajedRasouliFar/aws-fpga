// Amazon FGPA Hardware Development Kit
// 
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// 
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
// 
//    http://aws.amazon.com/asl/
// 
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.

`ifndef SV_SH_DPI_TASKS
`define SV_SH_DPI_TASKS

import tb_type_defines_pkg::*;

   import "DPI-C" context task test_main(output int unsigned exit_code);
   import "DPI-C" context task int_handler(input int unsigned int_num);
   import "DPI-C" context function void  host_memory_putc(input longint unsigned addr, byte data);         // even though a int is used, only the lower 8b are used
   import "DPI-C" context function byte  host_memory_getc(input longint unsigned addr);

   export "DPI-C" task sv_printf;
   export "DPI-C" task sv_map_host_memory;
   export "DPI-C" task cl_peek;
   export "DPI-C" task cl_poke;
   export "DPI-C" task sv_int_ack;
   export "DPI-C" task sv_pause;

   static int h2c_desc_index = 0;
   static int c2h_desc_index = 0;
   
   task sv_printf(input string msg);
      $display("%S", msg);
   endtask

   task sv_map_host_memory(input longint unsigned addr);
      tb.card.fpga.sh.map_host_memory(addr);
   endtask

   task cl_peek(input longint unsigned addr, output int unsigned data);
      tb.card.fpga.sh.peek(addr, data);
   endtask
   
   task cl_poke(input longint unsigned addr, int unsigned data);
      tb.card.fpga.sh.poke(addr, data);
   endtask

   task sv_int_ack(input int unsigned int_num);
      tb.card.fpga.sh.set_ack_bit(int_num);
   endtask
   
   task sv_pause(input int x);
      repeat (x) #1us;
   endtask

   function void hm_put_byte(input longint unsigned addr, byte d);
      if (tb.use_c_host_memory)
         host_memory_putc(addr, d);
      else begin
         int unsigned t;

         if (tb.sv_host_memory.exists({addr[63:2], 2'b00})) begin
            t = tb.sv_host_memory[{addr[63:2], 2'b00}];
         end
         else
            t = 32'hffff_ffff;
         
         t = t & ~(32'h0000_00ff  << (addr[1:0] * 8) );
         t = t | ({24'h000000, d} << (addr[1:0] * 8) );
         tb.sv_host_memory[{addr[63:2], 2'b00}] = t;
      end
   endfunction

   function byte hm_get_byte(input longint unsigned addr);
      byte d;

      if (tb.use_c_host_memory)
         d = host_memory_getc(addr);
      else begin
         int unsigned t;
         if (tb.sv_host_memory.exists({addr[63:2], 2'b00})) begin
            t = tb.sv_host_memory[{addr[63:2], 2'b00}];
            t = t >> (addr[1:0] * 8);
            d = t[7:0];
         end
         else
            d = 'hff;
      end
      return d;
   endfunction

`define SLOT_MACRO_TASK(ARG) \
begin \
   case (slot_id) \
   0: tb.card.fpga.sh.ARG; \
`ifdef SLOT_1 \
   1: tb.`SLOT_1.fpga.sh.ARG; \
`endif \
`ifdef SLOT_2 \
   2: tb.`SLOT_2.fpga.sh.ARG; \
`endif \
`ifdef SLOT_3 \
   3: tb.`SLOT_3.fpga.sh.ARG; \
`endif \
`ifdef SLOT_4 \
   4: tb.`SLOT_4.fpga.sh.ARG; \
`endif \
`ifdef SLOT_5 \
   5: tb.`SLOT_5.fpga.sh.ARG; \
`endif \
`ifdef SLOT_6 \
   6: tb.`SLOT_6.fpga.sh.ARG; \
`endif \
`ifdef SLOT_7 \
   7: tb.`SLOT_7.fpga.sh.ARG; \
`endif \
   default: begin \
      $display("Error: Invalid Slot ID specified."); \
      $finish; \
   end \
   endcase \
end

`define SLOT_MACRO_FUNC(ARG) \
begin \
   case (slot_id) \
   0: return tb.card.fpga.sh.ARG; \
`ifdef SLOT_1 \
   1: return tb.`SLOT_1.fpga.sh.ARG; \
`endif \
`ifdef SLOT_2 \
   2: return tb.`SLOT_2.fpga.sh.ARG; \
`endif \
`ifdef SLOT_3 \
   3: return tb.`SLOT_3.fpga.sh.ARG; \
`endif \
`ifdef SLOT_4 \
   4: return tb.`SLOT_4.fpga.sh.ARG; \
`endif \
`ifdef SLOT_5 \
   5: return tb.`SLOT_5.fpga.sh.ARG; \
`endif \
`ifdef SLOT_6 \
   6: return tb.`SLOT_6.fpga.sh.ARG; \
`endif \
`ifdef SLOT_7 \
   7: return tb.`SLOT_7.fpga.sh.ARG; \
`endif \
   default: begin \
      $display("Error: Invalid Slot ID specified."); \
      $finish; \
   end \
   endcase \
end

   function void que_buffer_to_cl(input int slot_id = 0, int chan, logic [63:0] src_addr, logic [63:0] cl_addr, logic [27:0] len);
      `SLOT_MACRO_TASK(dma_buffer_to_cl(.chan(chan), .src_addr(src_addr), .cl_addr(cl_addr), .len(len)))
   endfunction

   function void que_cl_to_buffer(input int slot_id = 0, int chan, logic [63:0] dst_addr, logic [63:0] cl_addr, logic [27:0] len);
      `SLOT_MACRO_TASK(dma_cl_to_buffer(.chan(chan), .dst_addr(dst_addr), .cl_addr(cl_addr), .len(len)))
   endfunction

   function void start_que_to_cl(input int slot_id = 0, int chan);
      `SLOT_MACRO_TASK(start_dma_to_cl(chan))
   endfunction

   function void start_que_to_buffer(input int slot_id = 0, int chan);
      `SLOT_MACRO_TASK(start_dma_to_buffer(chan))
   endfunction

   task power_up(input int slot_id = 0, 
                       ClockProfile::CLK_PROFILE clk_profile_a = ClockProfile::PROFILE_0,
                       ClockProfile::CLK_PROFILE clk_profile_b = ClockProfile::PROFILE_0,
                       ClockProfile::CLK_PROFILE clk_profile_c = ClockProfile::PROFILE_0);
   `SLOT_MACRO_TASK(power_up(.clk_profile_a(clk_profile_a),.clk_profile_b(clk_profile_b),.clk_profile_c(clk_profile_c)))
   endtask

   task power_down(input int slot_id = 0);
   `SLOT_MACRO_TASK(power_down())
   endtask

   //=================================================
   //
   // set_virtual_dip_switch
   //
   //   Description: writes virtual dip switches
   //   Outputs: None
   //
   //=================================================
   function void set_virtual_dip_switch(input int slot_id = 0, int dip);
      `SLOT_MACRO_TASK(set_virtual_dip_switch(dip))
   endfunction

   //=================================================
   //
   // get_virtual_dip_switch
   //
   //   Description: reads virtual dip switch status
   //   Outputs: dip_status
   //
   //=================================================
   function logic [15:0] get_virtual_dip_switch(input int slot_id = 0);
      `SLOT_MACRO_FUNC(get_virtual_dip_switch())
   endfunction

   //=================================================
   //
   // get_virtual_led
   //
   //   Description: reads virtual led status
   //   Outputs: led status
   //
   //=================================================
   function logic[15:0] get_virtual_led(input int slot_id = 0);
      `SLOT_MACRO_FUNC(get_virtual_led())
   endfunction

   //=================================================
   //
   // Kernel_reset
   //
   //   Description: sets kernel_reset
   //   Outputs: None
   //
   //=================================================
   function void kernel_reset(input int slot_id = 0, logic d = 1);
      `SLOT_MACRO_TASK(kernel_reset(d))
   endfunction

   //=================================================
   //
   // poke
   //
   //   Description: used to write a single beat of data at addr into one of the four CL AXI ports specified by intf.
   //        Intf
   //         0 = PCIS
   //         1 = SDA
   //         2 = OCL
   //         3 = BAR1
   //
   //        id - AXI bus ID
   //
   //        Size
   //         0 = 1 byte, 1 = 2 bytes, 2 = 4 bytes (32 bits), 3 = 8 bytes (64 bits)
   //
   //   Outputs: None
   //
   //=================================================
   task poke(input int slot_id = 0,
             logic [63:0] addr, 
             logic [63:0] data, 
             logic [5:0] id = 6'h0, 
             DataSize::DATA_SIZE size = DataSize::UINT32, 
             AxiPort::AXI_PORT intf = AxiPort::PORT_PCIS); 
       `SLOT_MACRO_TASK(poke(.addr(addr), .data(data), .id(id), .size(size), .intf(intf)))
   endtask

   //=================================================
   //
   // peek
   //
   //   Description: used to read a single beat of data at addr from one of the four CL AXI ports specified by intf.
   //        Intf
   //         0 = PCIS
   //         1 = SDA
   //         2 = OCL
   //         3 = BAR1
   //
   //        id - AXI bus ID
   //
   //        Size
   //         0 = 1 byte, 1 = 2 bytes, 2 = 4 bytes (32 bits), 3 = 8 bytes (64 bits)
   //
   //   Outputs: Read Data Value
   //
   //=================================================
   task peek(input int slot_id = 0,
             logic [63:0] addr, 
             output logic [63:0] data, 
             input logic [5:0] id = 6'h0, 
             DataSize::DATA_SIZE size = DataSize::UINT32, 
             AxiPort::AXI_PORT intf = AxiPort::PORT_PCIS); 
       `SLOT_MACRO_TASK(peek(.addr(addr), .data(data), .id(id), .size(size), .intf(intf)))
   endtask

   //=================================================
   //
   // set_ack_bit
   //
   //   Description: used to acknowledge an interrupt and clear pending bit
   //   Outputs: None
   //
   //=================================================
   function void set_ack_bit(input int slot_id = 0,
                             int int_num);
      `SLOT_MACRO_TASK(set_ack_bit(.int_num(int_num)))
   endfunction

   //=================================================
   //
   // issue_flr
   //
   //   Description: issue a FLR command
   //   Outputs: None
   //
   //=================================================
   task issue_flr(input int slot_id = 0);
       `SLOT_MACRO_TASK(issue_flr())
   endtask

   //=================================================
   //
   // nsec_delay
   //
   //   Description: sets a delay in nsec
   //   Outputs: None
   //
   //=================================================
   task nsec_delay(int dly = 10000);
      tb.card.fpga.sh.nsec_delay(dly);
   endtask


   function bit is_dma_to_cl_done(input int slot_id = 0, input int chan);
      `SLOT_MACRO_FUNC(is_dma_to_cl_done(chan))   
   endfunction // is_dma_to_cl_done

   function bit is_dma_to_buffer_done(input int slot_id = 0, input int chan);
      `SLOT_MACRO_FUNC(is_dma_to_buffer_done(chan))
   endfunction // is_dma_to_buffer_done

   task poke_stat(input int slot_id = 0,
                  input logic [7:0] addr, logic [1:0] ddr_idx, logic[31:0] data);
      `SLOT_MACRO_TASK(poke_stat(.addr(addr), .ddr_idx(ddr_idx), .data(data)))
   endtask
`endif
