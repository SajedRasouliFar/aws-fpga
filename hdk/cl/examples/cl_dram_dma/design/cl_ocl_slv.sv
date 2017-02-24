module cl_ocl_slv (
   
   input clk,
   input sync_rst_n,

   input sh_cl_flr_assert_q,

   input [31:0] sh_ocl_awaddr,
   input sh_ocl_awvalid,
   output logic ocl_sh_awready,

   input [31:0] sh_ocl_wdata,
   input [3:0] sh_ocl_wstrb,
   input sh_ocl_wvalid,
   output logic ocl_sh_wready,

   output logic [1:0] ocl_sh_bresp,
   output logic ocl_sh_bvalid,
   input sh_ocl_bready,

   input [31:0] sh_ocl_araddr,
   input sh_ocl_arvalid,
   output logic ocl_sh_arready,

   output logic [31:0] ocl_sh_rdata,
   output logic [1:0] ocl_sh_rresp,
   output logic ocl_sh_rvalid,
   input sh_ocl_rready,

   cfg_bus_t pcim_tst_cfg_bus,
   cfg_bus_t ddr0_tst_cfg_bus,
   cfg_bus_t ddr1_tst_cfg_bus,
   cfg_bus_t ddr2_tst_cfg_bus,
   cfg_bus_t ddr3_tst_cfg_bus,
   cfg_bus_t int_tst_cfg_bus

);


logic sh_ocl_awvalid_q;
logic[31:0] sh_ocl_awaddr_q;
logic ocl_sh_awready_q;
logic sh_ocl_wvalid_q;
logic[31:0] sh_ocl_wdata_q;
logic[3:0] sh_ocl_wstrb_q;
logic ocl_sh_wready_q;
logic ocl_sh_bvalid_q;
logic[1:0] ocl_sh_bresp_q;
logic sh_ocl_bready_q;
logic sh_ocl_arvalid_q;
logic[31:0] sh_ocl_araddr_q;
logic ocl_sh_arready_q;
logic ocl_sh_rvalid_q;
logic[31:0] ocl_sh_rdata_q;
logic[1:0] ocl_sh_rresp_q;
logic sh_ocl_rready_q;


   axi4_flop_fifo #(.IN_FIFO(1), .ADDR_WIDTH(32), .DATA_WIDTH(32), .ID_WIDTH(1), .A_USER_WIDTH(1), .FIFO_DEPTH(3)) AXIL_OCL_REG_SLC (
    .aclk          (clk),
    .aresetn       (sync_rst_n),
    .sync_rst_n    (1'b1),
    .s_axi_awid    (1'b0),
    .s_axi_awaddr  (sh_ocl_awaddr),
    .s_axi_awlen   (8'h00),                                            
    .s_axi_awvalid (sh_ocl_awvalid),
    .s_axi_awuser  (1'b0),
    .s_axi_awready (ocl_sh_awready),
    .s_axi_wdata   (sh_ocl_wdata),
    .s_axi_wstrb   (sh_ocl_wstrb),
    .s_axi_wlast   (1'b0),
    .s_axi_wuser   (1'b0),
    .s_axi_wvalid  (sh_ocl_wvalid),
    .s_axi_wready  (ocl_sh_wready),
    .s_axi_bid     (),
    .s_axi_bresp   (ocl_sh_bresp),
    .s_axi_bvalid  (ocl_sh_bvalid),
    .s_axi_buser   (),
    .s_axi_bready  (sh_ocl_bready),
    .s_axi_arid    (1'h0),
    .s_axi_araddr  (sh_ocl_araddr),
    .s_axi_arlen   (8'h0), 
    .s_axi_arvalid (sh_ocl_arvalid),
    .s_axi_aruser  (1'd0),
    .s_axi_arready (ocl_sh_arready),
    .s_axi_rid     (),
    .s_axi_rdata   (ocl_sh_rdata),
    .s_axi_rresp   (ocl_sh_rresp),
    .s_axi_rlast   (),
    .s_axi_ruser   (),
    .s_axi_rvalid  (ocl_sh_rvalid),
    .s_axi_rready  (sh_ocl_rready), 
    .m_axi_awid    (),
    .m_axi_awaddr  (sh_ocl_awaddr_q), 
    .m_axi_awlen   (),
    .m_axi_awvalid (sh_ocl_awvalid_q),
    .m_axi_awuser  (),
    .m_axi_awready (ocl_sh_awready_q),
    .m_axi_wdata   (sh_ocl_wdata_q),  
    .m_axi_wstrb   (sh_ocl_wstrb_q),
    .m_axi_wvalid  (sh_ocl_wvalid_q), 
    .m_axi_wlast   (),
    .m_axi_wuser   (),
    .m_axi_wready  (ocl_sh_wready_q), 
    .m_axi_bresp   (ocl_sh_bresp_q),  
    .m_axi_bvalid  (ocl_sh_bvalid_q), 
    .m_axi_bid     (),
    .m_axi_buser   (1'b0),
    .m_axi_bready  (sh_ocl_bready_q), 
    .m_axi_arid    (), 
    .m_axi_araddr  (sh_ocl_araddr_q), 
    .m_axi_arlen   (), 
    .m_axi_aruser  (), 
    .m_axi_arvalid (sh_ocl_arvalid_q),
    .m_axi_arready (ocl_sh_arready_q),
    .m_axi_rid     (),  
    .m_axi_rdata   (ocl_sh_rdata_q),  
    .m_axi_rresp   (ocl_sh_rresp_q),  
    .m_axi_rlast   (),  
    .m_axi_ruser   (1'b0),
    .m_axi_rvalid  (ocl_sh_rvalid_q), 
    .m_axi_rready  (sh_ocl_rready_q)
   );


//-------------------------------------------------
// Slave state machine (accesses from PCIe)
//-------------------------------------------------

parameter NUM_TST = (1 + 4 + 4 + 4 + 1 + 2);

typedef enum logic[2:0] {
   SLV_IDLE = 0,
   SLV_WR_ADDR = 1,
   SLV_CYC = 2,
   SLV_RESP = 3
   } slv_state_t;

slv_state_t slv_state, slv_state_nxt;

logic slv_arb_wr;                //Arbitration winner (write/read)
logic slv_cyc_wr;                //Cycle is write
logic[31:0] slv_mx_addr;         //Mux address
logic slv_mx_rsp_ready;          //Mux the response ready

logic slv_wr_req;                //Write request
logic slv_rd_req;                //Read request

logic slv_cyc_done;              //Cycle is done

logic[31:0] slv_rdata;           //Latch rdata

logic[7:0] slv_sel;              //Slave select

logic[31:0] slv_tst_addr[NUM_TST-1:0];
logic[31:0] slv_tst_wdata[NUM_TST-1:0];
logic[NUM_TST-1:0] slv_tst_wr;
logic[NUM_TST-1:0] slv_tst_rd;
logic slv_mx_req_valid;

logic[NUM_TST-1:0] tst_slv_ack;
logic[31:0] tst_slv_rdata [NUM_TST-1:0];

logic slv_did_req;            //Once cycle request, latch that did the request


//Write request valid when both address is valid
assign slv_wr_req = sh_ocl_awvalid_q;
assign slv_rd_req = sh_ocl_arvalid_q;
assign slv_mx_rsp_ready = (slv_cyc_wr)? sh_ocl_bready_q: sh_ocl_rready_q;
assign slv_mx_req_valid = (slv_cyc_wr)?   sh_ocl_wvalid_q: 1'b1;

//Fixed write hi-pri
assign slv_arb_wr = slv_wr_req;

logic [63:0] slv_req_rd_addr;
logic [63:0] slv_req_wr_addr;
logic [5:0]  slv_req_rd_id;
logic [5:0]  slv_req_wr_id;


always_ff @(negedge sync_rst_n or posedge clk)
  if (!sync_rst_n)
  begin
    {slv_req_rd_addr, slv_req_wr_addr} <= 128'd0;
    {slv_req_rd_id, slv_req_wr_id} <= 0;
  end
  else if ((slv_state == SLV_IDLE) && (sh_ocl_arvalid_q || sh_ocl_awvalid_q))
  begin
    {slv_req_rd_addr[31:0], slv_req_wr_addr[31:0]} <= {sh_ocl_araddr_q, sh_ocl_awaddr_q};
    {slv_req_rd_id, slv_req_wr_id} <= 0;
  end
   
//Mux address
assign slv_mx_addr = (slv_cyc_wr)? slv_req_wr_addr : slv_req_rd_addr;
   
//Slave select (256B per slave)
assign slv_sel = slv_mx_addr[15:8];
   
//Latch the winner
always_ff @(negedge sync_rst_n or posedge clk)
   if (!sync_rst_n)
      slv_cyc_wr <= 0;
   else if (slv_state==SLV_IDLE)
      slv_cyc_wr <= slv_arb_wr;

//State machine
always_comb
begin
   slv_state_nxt = slv_state;
   if (sh_cl_flr_assert_q)
      slv_state_nxt = SLV_IDLE;
   else
   begin
   case (slv_state)

      SLV_IDLE:
      begin
         if (slv_wr_req)
            slv_state_nxt = SLV_WR_ADDR;
         else if (slv_rd_req)
            slv_state_nxt = SLV_CYC;
         else
            slv_state_nxt = SLV_IDLE;
      end

      SLV_WR_ADDR:
      begin
         slv_state_nxt = SLV_CYC;
      end

      SLV_CYC:
      begin
         if (slv_cyc_done)
            slv_state_nxt = SLV_RESP;
         else
            slv_state_nxt = SLV_CYC;
      end

      SLV_RESP:
      begin
         if (slv_mx_rsp_ready)
            slv_state_nxt = SLV_IDLE;
         else
            slv_state_nxt = SLV_RESP;
      end

   endcase
   end
end

//State machine flops
always_ff @(negedge sync_rst_n or posedge clk)
   if (!sync_rst_n)
      slv_state <= SLV_IDLE;
   else
      slv_state <= slv_state_nxt;


//Cycle to TST blocks -- Repliacte for timing

always_ff @(negedge sync_rst_n or posedge clk)
   if (!sync_rst_n)
   begin
      slv_tst_addr <= '{default:'0};
      slv_tst_wdata <= '{default:'0};
   end
   else
   begin
      for (int i=0; i<NUM_TST; i++)
      begin
         slv_tst_addr[i] <= slv_mx_addr;
         slv_tst_wdata[i] <= sh_ocl_wdata_q;
      end
   end

//Test are 1 clock pulses (because want to support clock crossing)
always_ff @(negedge sync_rst_n or posedge clk)
   if (!sync_rst_n)
   begin
      slv_did_req <= 0;
   end
   else if (slv_state==SLV_IDLE)
   begin
      slv_did_req <= 0;
   end
   else if (|slv_tst_wr || |slv_tst_rd)
   begin
      slv_did_req <= 1;
   end

//Flop this for timing
always_ff @(negedge sync_rst_n or posedge clk)
   if (!sync_rst_n)
   begin
      slv_tst_wr <= 0;
      slv_tst_rd <= 0;
   end
   else
   begin
      slv_tst_wr <= ((slv_state==SLV_CYC) & slv_mx_req_valid & slv_cyc_wr & !slv_did_req) << slv_sel;
      slv_tst_rd <= ((slv_state==SLV_CYC) & slv_mx_req_valid & !slv_cyc_wr & !slv_did_req) << slv_sel;
   end

assign slv_cyc_done = tst_slv_ack[slv_sel];

//Latch the return data
always_ff @(negedge sync_rst_n or posedge clk)
   if (!sync_rst_n)
      slv_rdata <= 0;
   else if (slv_cyc_done)
      slv_rdata <= tst_slv_rdata[slv_sel];

//Ready back to AXI for request
always_ff @(negedge sync_rst_n or posedge clk)
   if (!sync_rst_n)
   begin
      ocl_sh_awready_q <= 0;
      ocl_sh_wready_q <= 0;
      ocl_sh_arready_q <= 0;
   end
   else
   begin
      ocl_sh_awready_q <= (slv_state_nxt==SLV_WR_ADDR);
      ocl_sh_wready_q <= ((slv_state==SLV_CYC) && (slv_state_nxt!=SLV_CYC)) && slv_cyc_wr;
      ocl_sh_arready_q <= ((slv_state==SLV_CYC) && (slv_state_nxt!=SLV_CYC)) && ~slv_cyc_wr;
   end
   
//Response back to AXI
assign ocl_sh_bid_q = slv_req_wr_id;
assign ocl_sh_bresp_q = 0;
assign ocl_sh_bvalid_q = (slv_state==SLV_RESP) && slv_cyc_wr;
  
assign ocl_sh_rid_q = slv_req_rd_id;
assign ocl_sh_rdata_q = slv_rdata;
assign ocl_sh_rresp_q = 2'b00;
assign ocl_sh_rvalid_q = (slv_state==SLV_RESP) && !slv_cyc_wr;


//assign individual cfg bus
assign pcim_tst_cfg_bus.addr = slv_tst_addr[0];
assign pcim_tst_cfg_bus.wdata = slv_tst_wdata[0];
assign pcim_tst_cfg_bus.wr = slv_tst_wr[0];
assign pcim_tst_cfg_bus.rd = slv_tst_rd[0];
assign tst_slv_ack[0] = pcim_tst_cfg_bus.ack;
assign tst_slv_rdata[0] = pcim_tst_cfg_bus.rdata;

assign ddr0_tst_cfg_bus.addr = slv_tst_addr[1];
assign ddr0_tst_cfg_bus.wdata = slv_tst_wdata[1];
assign ddr0_tst_cfg_bus.wr = slv_tst_wr[1];
assign ddr0_tst_cfg_bus.rd = slv_tst_rd[1];
assign tst_slv_ack[1] = ddr0_tst_cfg_bus.ack;
assign tst_slv_rdata[1] = ddr0_tst_cfg_bus.rdata;

assign ddr1_tst_cfg_bus.addr = slv_tst_addr[2];
assign ddr1_tst_cfg_bus.wdata = slv_tst_wdata[2];
assign ddr1_tst_cfg_bus.wr = slv_tst_wr[2];
assign ddr1_tst_cfg_bus.rd = slv_tst_rd[2];
assign tst_slv_ack[2] = ddr1_tst_cfg_bus.ack;
assign tst_slv_rdata[2] = ddr1_tst_cfg_bus.rdata;

assign ddr2_tst_cfg_bus.addr = slv_tst_addr[3];
assign ddr2_tst_cfg_bus.wdata = slv_tst_wdata[3];
assign ddr2_tst_cfg_bus.wr = slv_tst_wr[3];
assign ddr2_tst_cfg_bus.rd = slv_tst_rd[3];
assign tst_slv_ack[3] = ddr2_tst_cfg_bus.ack;
assign tst_slv_rdata[3] = ddr2_tst_cfg_bus.rdata;

assign ddr3_tst_cfg_bus.addr = slv_tst_addr[4];
assign ddr3_tst_cfg_bus.wdata = slv_tst_wdata[4];
assign ddr3_tst_cfg_bus.wr = slv_tst_wr[4];
assign ddr3_tst_cfg_bus.rd = slv_tst_rd[4];
assign tst_slv_ack[4] = ddr3_tst_cfg_bus.ack;
assign tst_slv_rdata[4] = ddr3_tst_cfg_bus.rdata;


assign int_tst_cfg_bus.addr = slv_tst_addr[13];
assign int_tst_cfg_bus.wdata = slv_tst_wdata[13];
assign int_tst_cfg_bus.wr = slv_tst_wr[13];
assign int_tst_cfg_bus.rd = slv_tst_rd[13];
assign tst_slv_ack[13] = int_tst_cfg_bus.ack;
assign tst_slv_rdata[13] = int_tst_cfg_bus.rdata;


endmodule
