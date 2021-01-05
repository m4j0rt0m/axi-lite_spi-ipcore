/*
 * Author:        Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:          axi_spi_top.v
 * Description:   AXI4-Lite SPI Slave Module
 * Organizations: BSC; CIC-IPN
 */
module axi_spi_top
(/*AUTOARG*/
   // Outputs
   axi_arready_o, axi_rid_o, axi_rdata_o, axi_rresp_o, axi_rvalid_o,
   axi_awready_o, axi_wready_o, axi_bid_o, axi_bresp_o, axi_bvalid_o,
   spi_clk_o, spi_cs_n_o, spi_mosi_o,
   // Inputs
   axi_aclk_i, axi_aresetn_i, axi_arid_i, axi_araddr_i, axi_arvalid_i,
   axi_rready_i, axi_awid_i, axi_awaddr_i, axi_awvalid_i, axi_wdata_i,
   axi_wstrb_i, axi_wvalid_i, axi_bready_i, spi_miso_i
   );

  /* includes */
  `include "axi_spi_defines.vh"
  `include "my_defines.vh"
  `include "axi_spi.vh"

  /* local parameters */
  localparam  BYTE            = `_BYTE_;
  localparam  AXI_DATA_WIDTH  = `_AXI_SPI_DATA_WIDTH_;
  localparam  AXI_ADDR_WIDTH  = `_AXI_SPI_ADDR_WIDTH_;
  localparam  AXI_ID_WIDTH    = `_AXI_SPI_ID_WIDTH_;
  localparam  AXI_RESP_WIDTH  = `_AXI_SPI_RESP_WIDTH_;
  localparam  AXI_FIFO_DEPTH  = `_AXI_SPI_FIFO_DEPTH_;
  localparam  AXI_FIFO_ADDR   = `_myLOG2_(AXI_FIFO_DEPTH-1);
  localparam  AXI_BYTE_NUM    = AXI_DATA_WIDTH/BYTE;
  localparam  AXI_LSB_WIDTH   = `_myLOG2_(AXI_BYTE_NUM-1);
  localparam  DEADLOCK_LIMIT  = 15;
  localparam  DEADLOCK_WIDTH  = `_myLOG2_(DEADLOCK_LIMIT-1);

  /* axi-spi parameters */
  localparam  DATA_WIDTH_SPI        = `_DATA_WIDTH_SPI_;
  localparam  SPI_RATIO_GRADE       = `_SPI_RATIO_GRADE_;
  localparam  SPI_GIER              = `_SPI_GIER_;              //..axi spi register map
  localparam  SPI_ISR               = `_SPI_ISR_;
  localparam  SPI_IER               = `_SPI_IER_;
  localparam  SPI_SRR               = `_SPI_SRR_;
  localparam  SPI_CR                = `_SPI_CR_;
  localparam  SPI_SR                = `_SPI_SR_;
  localparam  SPI_DTR               = `_SPI_DTR_;
  localparam  SPI_DRR               = `_SPI_DRR_;
  localparam  SPI_SSR               = `_SPI_SSR_;
  localparam  SPI_TFOR              = `_SPI_TFOR_;
  localparam  SPI_RFOR              = `_SPI_RFOR_;
  localparam  SPI_RCLK              = `_SPI_RCLK_;              // -> (custom mapped register)
  localparam  SPI_CR_INIT           = `_SPI_CR_INIT_;           //..axi spi parameters (reset values)
  localparam  SPI_SR_INIT           = `_SPI_SR_INIT_;
  localparam  SPI_SSR_INIT          = `_SPI_SSR_INIT_;
  localparam  SPI_TFOR_INIT         = `_SPI_TFOR_INIT_;
  localparam  SPI_RFOR_INIT         = `_SPI_RFOR_INIT_;
  localparam  SPI_GIER_INIT         = `_SPI_GIER_INIT_;
  localparam  SPI_ISR_INIT          = `_SPI_ISR_INIT_;
  localparam  SPI_IER_INIT          = `_SPI_IER_INIT_;
  localparam  SPI_RCLK_INIT         = `_SPI_RCLK_INIT_;         // -> (custom mapped register init)
  localparam  SPI_SRR_VALUE         = `_SPI_SRR_VALUE_;         //..axi spi soft reset register value
  localparam  CR_LSB_FIRST_BIT      = `_CR_LSB_FIRST_BIT_;      //..axi spi control bits
  localparam  CR_RX_FIFO_RESET_BIT  = `_CR_RX_FIFO_RESET_BIT_;
  localparam  CR_TX_FIFO_RESET_BIT  = `_CR_TX_FIFO_RESET_BIT_;
  localparam  CR_CPHA_BIT           = `_CR_CPHA_BIT_;
  localparam  CR_CPOL_BIT           = `_CR_CPOL_BIT_;
  localparam  CR_MASTER_BIT         = `_CR_MASTER_BIT_;
  localparam  CR_SPI_ENABLE_BIT     = `_CR_SPI_ENABLE_BIT_;
  localparam  SR_RX_EMPTY_BIT       = `_SR_RX_EMPTY_BIT_;       //..axi spi status bits
  localparam  SR_RX_FULL_BIT        = `_SR_RX_FULL_BIT_;
  localparam  SR_TX_EMPTY_BIT       = `_SR_TX_EMPTY_BIT_;
  localparam  SR_TX_FULL_BIT        = `_SR_TX_FULL_BIT_;
  localparam  SR_MODF_BIT           = `_SR_MODF_BIT_;
  localparam  SR_SMOD_SEL_BIT       = `_SR_SMOD_SEL_BIT_;

  /* axi4-lite interface ports */
  input                             axi_aclk_i;
  input                             axi_aresetn_i;

  input       [AXI_ID_WIDTH-1:0]    axi_arid_i;
  input       [AXI_ADDR_WIDTH-1:0]  axi_araddr_i;
  input                             axi_arvalid_i;
  output reg                        axi_arready_o;

  output reg  [AXI_ID_WIDTH-1:0]    axi_rid_o;
  output reg  [AXI_DATA_WIDTH-1:0]  axi_rdata_o;
  output reg  [AXI_RESP_WIDTH-1:0]  axi_rresp_o;
  output reg                        axi_rvalid_o;
  input                             axi_rready_i;

  input       [AXI_ID_WIDTH-1:0]    axi_awid_i;
  input       [AXI_ADDR_WIDTH-1:0]  axi_awaddr_i;
  input                             axi_awvalid_i;
  output reg                        axi_awready_o;

  input       [AXI_DATA_WIDTH-1:0]  axi_wdata_i;
  input       [AXI_BYTE_NUM-1:0]    axi_wstrb_i;
  input                             axi_wvalid_i;
  output reg                        axi_wready_o;

  output reg  [AXI_ID_WIDTH-1:0]    axi_bid_o;
  output reg  [AXI_RESP_WIDTH-1:0]  axi_bresp_o;
  output reg                        axi_bvalid_o;
  input                             axi_bready_i;

  /* spi interface ports */
  output                            spi_clk_o;
  output                            spi_cs_n_o;
  output                            spi_mosi_o;
  input                             spi_miso_i;

  /* regs and wires declarations */
  reg                         soft_reset;
  wire                        slv_reg_rden  = axi_arvalid_i;
  wire                        slv_reg_nrden = ~axi_arvalid_i & ~axi_rvalid_o;
  wire                        slv_reg_wren  = axi_awvalid_i & axi_wvalid_i;
  wire                        slv_reg_nwren = ~axi_wvalid_i & ~axi_awvalid_i & ~axi_bvalid_o;
  reg   [DEADLOCK_WIDTH:0]    wr_deadlock_cnt;  //..write deadlock counter
  reg   [DEADLOCK_WIDTH:0]    rd_deadlock_cnt;  //..read deadlock counter
  reg                         wr_deadlock;      //..write deadlock counter enable
  reg                         rd_deadlock;      //..read deadlock counter enable
  reg                         wr_timeout;       //..write deadlock timeout
  reg                         rd_timeout;       //..read deadlock timeout
  wire  [AXI_DATA_WIDTH-1:0]  write_data;       //..write data after byte enable

  /* integers and genvars */
  genvar I;

  /* axi4-spi regs (SRR isn't available for r/w, a "0x0a" write operation triggers a soft ip-reset though) */
  reg   [AXI_DATA_WIDTH-1:0]  spi_control_reg;              //..SPI_CR
  wire  [AXI_DATA_WIDTH-1:0]  spi_status_reg;               //..SPI_SR
  reg   [DATA_WIDTH_SPI-1:0]  spi_tx_fifo_data;             //..SPI_DTR.data
  reg                         spi_tx_fifo_req;              //..SPI_DTR.request write
  wire                        spi_tx_fifo_ack;              //..SPI_DTR.acknowledge
  wire  [DATA_WIDTH_SPI-1:0]  spi_rx_fifo_data;             //..SPI_DRR.data
  reg                         spi_rx_fifo_req;              //..SPI_DRR.request read
  wire                        spi_rx_fifo_resp;             //..SPI_DRR.request response
  reg                         spi_rx_fifo_ack;              //..SPI_DRR.request acknowledge
  reg   [AXI_DATA_WIDTH-1:0]  spi_slave_select_reg;         //..SPI_SSR
  wire  [AXI_DATA_WIDTH-1:0]  spi_tx_fifo_occupancy_reg;    //..SPI_TFOR
  wire  [AXI_DATA_WIDTH-1:0]  spi_rx_fifo_occupancy_reg;    //..SPI_RFOR
  reg   [AXI_DATA_WIDTH-1:0]  spi_global_interrupt_en_reg;  //..SPI_GIER..(not implemented)
  reg   [AXI_DATA_WIDTH-1:0]  spi_interrupt_status_reg;     //..SPI_ISR..(not implemented)
  reg   [AXI_DATA_WIDTH-1:0]  spi_interrupt_enable_reg;     //..SPI_IER..(not implemented)
  reg   [SPI_RATIO_GRADE-1:0] spi_ratio_reg;                //..SPI_RCLK..(custom -> clk-spi_clk ratio)
                                                            //    0:  1/2
                                                            //    1:  1/4
                                                            //    2:  1/8
                                                            //    3:  1/16 ...
                                                            //    until SPI_RATIO_GRADE

  /* write data */
  generate
    for(I=0; I<AXI_BYTE_NUM; I=I+1) begin:  write_data_byte_en
      assign write_data[(I*8)+:8]  = (axi_wstrb_i[I]) ? axi_wdata_i[(I*8)+:8] : {BYTE{1'b0}};
    end
  endgenerate

  /* axi slave interface write fsm parameters */
  reg [4:0] fsm_axi_wr;
    localparam  StateInitWr     = 5'b00000;
    localparam  StateResetWr    = 5'b00011;
    localparam  StateIdleWr     = 5'b00101;
    localparam  StateControlWr  = 5'b01001;
    localparam  StateResponseWr = 5'b10001;

  /* axi slave interface read fsm parameters */
  reg [2:0] fsm_axi_rd;
    localparam  StateInitRd     = 3'b000;
    localparam  StateIdleRd     = 3'b011;
    localparam  StateResponseRd = 3'b101;

  /* axi slave write interface fsm */
  always @ (posedge axi_aclk_i, negedge axi_aresetn_i)  begin
    if(~axi_aresetn_i)  begin
      spi_control_reg             <=  SPI_CR_INIT;
      spi_slave_select_reg        <=  SPI_SSR_INIT;
      spi_global_interrupt_en_reg <=  SPI_GIER_INIT;
      spi_interrupt_status_reg    <=  SPI_ISR_INIT;
      spi_interrupt_enable_reg    <=  SPI_IER_INIT;
      spi_ratio_reg               <=  SPI_RCLK_INIT;
      soft_reset                  <=  1'b1;
      axi_awready_o               <=  1'b0;
      axi_wready_o                <=  1'b0;
      axi_bresp_o                 <=  {AXI_RESP_WIDTH{1'b0}};
      axi_bvalid_o                <=  1'b0;
      axi_bid_o                   <=  {AXI_ID_WIDTH{1'b0}};
      wr_deadlock                 <=  1'b0;
      spi_tx_fifo_data            <=  {DATA_WIDTH_SPI{1'b0}};
      spi_tx_fifo_req             <=  0;
      fsm_axi_wr                  <=  StateInitWr;
    end
    else  begin
      case(fsm_axi_wr)
        StateInitWr:  begin      //..reset axi regs
          spi_control_reg             <=  SPI_CR_INIT;
          spi_slave_select_reg        <=  SPI_SSR_INIT;
          spi_global_interrupt_en_reg <=  SPI_GIER_INIT;
          spi_interrupt_status_reg    <=  SPI_ISR_INIT;
          spi_interrupt_enable_reg    <=  SPI_IER_INIT;
          spi_ratio_reg               <=  SPI_RCLK_INIT;
          soft_reset                  <=  1'b1;
          axi_awready_o               <=  1'b0;
          axi_wready_o                <=  1'b0;
          axi_bresp_o                 <=  {AXI_RESP_WIDTH{1'b0}};
          axi_bvalid_o                <=  1'b0;
          axi_bid_o                   <=  {AXI_ID_WIDTH{1'b0}};
          wr_deadlock                 <=  1'b0;
          spi_tx_fifo_data            <=  {DATA_WIDTH_SPI{1'b0}};
          spi_tx_fifo_req             <=  0;
          fsm_axi_wr                  <=  StateResetWr;
        end
        StateResetWr: begin
          spi_control_reg             <=  SPI_CR_INIT;
          spi_slave_select_reg        <=  SPI_SSR_INIT;
          spi_global_interrupt_en_reg <=  SPI_GIER_INIT;
          spi_interrupt_status_reg    <=  SPI_ISR_INIT;
          spi_interrupt_enable_reg    <=  SPI_IER_INIT;
          spi_ratio_reg               <=  SPI_RCLK_INIT;
          soft_reset                  <=  1'b0;
          axi_awready_o               <=  1'b0;
          axi_wready_o                <=  1'b0;
          axi_bresp_o                 <=  {AXI_RESP_WIDTH{1'b0}};
          axi_bvalid_o                <=  1'b0;
          axi_bid_o                   <=  {AXI_ID_WIDTH{1'b0}};
          wr_deadlock                 <=  1'b0;
          spi_tx_fifo_data            <=  {DATA_WIDTH_SPI{1'b0}};
          spi_tx_fifo_req             <=  0;
          fsm_axi_wr                  <=  StateIdleWr;
        end
        StateIdleWr:  begin
          if(slv_reg_wren)  begin  //..write operation
            /* update data */
            case(axi_awaddr_i[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH])
              SPI_GIER[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: spi_global_interrupt_en_reg <=  write_data;
              SPI_ISR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  spi_interrupt_status_reg    <=  spi_interrupt_status_reg ^ write_data;
              SPI_IER[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  spi_interrupt_enable_reg    <=  write_data;
              SPI_CR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:   spi_control_reg             <=  write_data;
              SPI_DTR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin
                spi_tx_fifo_data  <=  write_data[DATA_WIDTH_SPI-1:0];
                if(spi_tx_fifo_ack)
                  spi_tx_fifo_req <=  0;
                else
                  spi_tx_fifo_req <=  1;
              end
              SPI_SSR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  spi_slave_select_reg        <=  write_data;
              SPI_RCLK[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: spi_ratio_reg               <=  write_data[SPI_RATIO_GRADE-1:0];
              default:  begin
                spi_global_interrupt_en_reg <=  spi_global_interrupt_en_reg;
                spi_interrupt_status_reg    <=  spi_interrupt_status_reg;
                spi_interrupt_enable_reg    <=  spi_interrupt_enable_reg;
                spi_control_reg             <=  spi_control_reg;
                spi_tx_fifo_data            <=  spi_tx_fifo_data;
                spi_tx_fifo_req             <=  spi_tx_fifo_req;
                spi_slave_select_reg        <=  spi_slave_select_reg;
                spi_ratio_reg               <=  spi_ratio_reg;
              end
            endcase
            /* change state */
            case(axi_awaddr_i[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH])
              SPI_DTR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin //..add an entry into the TX fifo if there is a free slot
                if(spi_tx_fifo_ack) begin
                  axi_awready_o <=  1'b1;                   //..write address transaction acknowledge
                  axi_wready_o  <=  1'b1;                   //..write data transaction acknowledge
                  axi_bresp_o   <=  {AXI_RESP_WIDTH{1'b0}}; //..write response "OKAY"
                  axi_bvalid_o  <=  1'b1;                   //..write response valid
                  axi_bid_o     <=  axi_awid_i;             //..write transaction id
                  fsm_axi_wr    <=  StateResponseWr;
                end
              end
              SPI_SRR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin //..check for "0x0000000a", then reset axi spi reg values
                if(write_data==SPI_SRR_VALUE)
                  soft_reset    <=  1'b1;                 //..soft reset asserted
                axi_awready_o <=  1'b1;                   //..write address transaction acknowledge
                axi_wready_o  <=  1'b1;                   //..write data transaction acknowledge
                axi_bresp_o   <=  {AXI_RESP_WIDTH{1'b0}}; //..write response "OKAY"
                axi_bvalid_o  <=  1'b1;                   //..write response valid
                axi_bid_o     <=  axi_awid_i;             //..write transaction id
                fsm_axi_wr    <=  StateResponseWr;
              end
              SPI_CR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:   begin //..update control (just clear fifo reset bits)
                fsm_axi_wr  <=  StateControlWr;
              end
              default:  begin //..assert "request_finished" signal
                axi_awready_o <=  1'b1;                   //..write address transaction acknowledge
                axi_wready_o  <=  1'b1;                   //..write data transaction acknowledge
                axi_bresp_o   <=  {AXI_RESP_WIDTH{1'b0}}; //..write response "OKAY"
                axi_bvalid_o  <=  1'b1;                   //..write response valid
                axi_bid_o     <=  axi_awid_i;             //..write transaction id
                fsm_axi_wr    <=  StateResponseWr;
              end
            endcase
          end
          wr_deadlock <=  1'b0;
        end
        StateControlWr: begin
          spi_control_reg[CR_TX_FIFO_RESET_BIT] <=  1'b0;
          spi_control_reg[CR_RX_FIFO_RESET_BIT] <=  1'b0;
          axi_awready_o                         <=  1'b1;                   //..write address transaction acknowledge
          axi_wready_o                          <=  1'b1;                   //..write data transaction acknowledge
          axi_bresp_o                           <=  {AXI_RESP_WIDTH{1'b0}}; //..write response "OKAY"
          axi_bvalid_o                          <=  1'b1;                   //..write response valid
          axi_bid_o                             <=  axi_awid_i;             //..write transaction id
          wr_deadlock                           <=  1'b0;
          fsm_axi_wr                            <=  StateResponseWr;
        end
        StateResponseWr:  begin
          if(slv_reg_nwren) begin //..wait for the write transaction to finish
            if(soft_reset)
              fsm_axi_wr  <=  StateResetWr;
            else
              fsm_axi_wr  <=  StateIdleWr;
            axi_bid_o   <=  {AXI_ID_WIDTH{1'b0}};
          end
          else if(wr_timeout)
            fsm_axi_wr  <=  StateInitWr;
          /* clear ready and valid bits for every channel */
          // if(~axi_wvalid_i)
          axi_wready_o  <=  1'b0;
          // if(~axi_awvalid_i)
          axi_awready_o <=  1'b0;
          // if(axi_bready_i)
          axi_bvalid_o  <=  1'b0;
          /* deadlock-free */
          wr_deadlock   <=  1'b1;
        end
        default:  begin
          soft_reset  <=  1'b1;
          fsm_axi_wr  <=  StateInitWr;
        end
      endcase
    end
  end

  /* axi slave read interface fsm */
  always @ (posedge axi_aclk_i, negedge axi_aresetn_i)  begin
    if(~axi_aresetn_i)  begin
      axi_arready_o   <=  1'b0;
      axi_rdata_o     <=  {AXI_DATA_WIDTH{1'b0}};
      axi_rresp_o     <=  2'b00;
      axi_rvalid_o    <=  1'b0;
      axi_rid_o       <=  {AXI_ID_WIDTH{1'b0}};
      spi_rx_fifo_ack <=  1'b0;
      rd_deadlock     <=  1'b0;
      spi_rx_fifo_req <=  1'b0;
      fsm_axi_rd      <=  StateInitRd;
    end
    else  begin
      case(fsm_axi_rd)
        StateInitRd:  begin //..reset axi regs
          axi_arready_o   <=  1'b0;
          axi_rdata_o     <=  {AXI_DATA_WIDTH{1'b0}};
          axi_rresp_o     <=  2'b00;
          axi_rvalid_o    <=  1'b0;
          axi_rid_o       <=  {AXI_ID_WIDTH{1'b0}};
          spi_rx_fifo_ack <=  1'b0;
          rd_deadlock     <=  1'b0;
          spi_rx_fifo_req <=  1'b0;
          fsm_axi_rd      <=  StateIdleRd;
        end
        StateIdleRd:  begin
          if(slv_reg_rden)  begin //..read operation
            /* read data */
            case(axi_araddr_i[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH])
              SPI_GIER[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: axi_rdata_o <=  spi_global_interrupt_en_reg;
              SPI_ISR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  axi_rdata_o <=  spi_interrupt_status_reg;
              SPI_IER[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  axi_rdata_o <=  spi_interrupt_enable_reg;
              SPI_CR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:   axi_rdata_o <=  spi_control_reg;
              SPI_SR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:   axi_rdata_o <=  spi_status_reg;
              SPI_DTR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  axi_rdata_o <=  {{`_DIFF_SIZE_(AXI_DATA_WIDTH, DATA_WIDTH_SPI){1'b0}}, spi_tx_fifo_data};
              SPI_DRR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin
                axi_rdata_o <=  {{`_DIFF_SIZE_(AXI_DATA_WIDTH, DATA_WIDTH_SPI){1'b0}}, spi_rx_fifo_data};
                if(spi_rx_fifo_resp)
                  spi_rx_fifo_req <=  0;
                else
                  spi_rx_fifo_req <=  1;
              end
              SPI_SSR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  axi_rdata_o <=  spi_slave_select_reg;
              SPI_TFOR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: axi_rdata_o <=  spi_tx_fifo_occupancy_reg;
              SPI_RFOR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: axi_rdata_o <=  spi_rx_fifo_occupancy_reg;
              default:                                  axi_rdata_o <=  32'h61626364;
            endcase
            /* change state */
            case(axi_araddr_i[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH])
              SPI_DRR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin
                if(spi_rx_fifo_resp)  begin
                  axi_arready_o   <=  1'b1;
                  axi_rresp_o     <=  2'b00;
                  axi_rvalid_o    <=  1'b1;
                  axi_rid_o       <=  axi_arid_i;
                  spi_rx_fifo_ack <=  1'b1;
                  fsm_axi_rd      <=  StateResponseRd;
                end
              end
              default:  begin
                axi_arready_o <=  1'b1;
                axi_rresp_o   <=  2'b00;
                axi_rvalid_o  <=  1'b1;
                axi_rid_o     <=  axi_arid_i;
                fsm_axi_rd    <=  StateResponseRd;
              end
            endcase
          end
          rd_deadlock <=  1'b0;
        end
        StateResponseRd:  begin
          if(slv_reg_nrden) begin
            axi_rid_o   <=  axi_arid_i;
            fsm_axi_rd  <=  StateIdleRd;
          end
          else if(rd_timeout)
            fsm_axi_rd  <=  StateInitRd;
          /* clear ready and valid bits for every channel */
          // if(~axi_arvalid_i)
          axi_arready_o   <=  1'b0;
          // if(axi_rready_i)
          axi_rvalid_o    <=  1'b0;
          spi_rx_fifo_ack <=  1'b0;
          /* deadlock-free */
          rd_deadlock     <=  1'b1;
        end
        default:  fsm_axi_rd  <=  StateInitRd;
      endcase
    end
  end

  /* deadlock counters */
  always @ (posedge axi_aclk_i, negedge axi_aresetn_i)  begin
    /* write deadlock counter */
    if(~axi_aresetn_i)  begin
      wr_deadlock_cnt <=  0;
      wr_timeout      <=  1'b0;
    end
    else  begin
      if(wr_deadlock) begin
        wr_deadlock_cnt <=  wr_deadlock_cnt + {{DEADLOCK_WIDTH{1'b0}},1'b1};
        if(wr_deadlock_cnt==DEADLOCK_LIMIT)
          wr_timeout    <=  1'b1;
      end
      else  begin
        wr_deadlock_cnt <=  0;
        wr_timeout      <=  1'b0;
      end
    end

    /* read deadlock counter */
    if(~axi_aresetn_i)  begin
      rd_deadlock_cnt <=  0;
      rd_timeout      <=  1'b0;
    end
    else  begin
      if(rd_deadlock) begin
        rd_deadlock_cnt <=  rd_deadlock_cnt + {{DEADLOCK_WIDTH{1'b0}},1'b1};
        if(rd_deadlock_cnt==DEADLOCK_LIMIT)
          rd_timeout    <=  1'b1;
      end
      else  begin
        rd_deadlock_cnt <=  0;
        rd_timeout      <=  1'b0;
      end
    end
  end

  /* axi spi ctrl */
  axi_spi_ctrl
    #  (
        .SPI_RATIO_GRADE  (SPI_RATIO_GRADE),
        .DATA_WIDTH       (DATA_WIDTH_SPI),
        .REG_WIDTH        (AXI_DATA_WIDTH),
        .FIFO_DEPTH       (AXI_FIFO_DEPTH),
        .FIFO_ADDR        (AXI_FIFO_ADDR),
        .SR_RX_EMPTY_BIT  (SR_RX_EMPTY_BIT),
        .SR_RX_FULL_BIT   (SR_RX_FULL_BIT),
        .SR_TX_EMPTY_BIT  (SR_TX_EMPTY_BIT),
        .SR_TX_FULL_BIT   (SR_TX_FULL_BIT),
        .SR_MODF_BIT      (SR_MODF_BIT),
        .SR_SMOD_SEL_BIT  (SR_SMOD_SEL_BIT)
      )
    axi_spi_ctrl_i0 (
      /* flow ctrl */
      .clk_i                    (axi_aclk_i),
      .arst_n_i                 (axi_aresetn_i),
      .soft_rst_i               (soft_reset),

      /* ctrl regs */
      .slave_select_i           (spi_slave_select_reg[0]),
      .control_lsb_i            (spi_control_reg[CR_LSB_FIRST_BIT]),
      .control_rx_fifo_reset_i  (spi_control_reg[CR_RX_FIFO_RESET_BIT]),
      .control_tx_fifo_reset_i  (spi_control_reg[CR_TX_FIFO_RESET_BIT]),
      .control_cpha_i           (spi_control_reg[CR_CPHA_BIT]),
      .control_cpol_i           (spi_control_reg[CR_CPOL_BIT]),
      .control_master_i         (spi_control_reg[CR_MASTER_BIT]),
      .control_spi_enable_i     (spi_control_reg[CR_SPI_ENABLE_BIT]),
      .status_o                 (spi_status_reg),
      .spi_ratio_i              (spi_ratio_reg[SPI_RATIO_GRADE-1:0]),

      /* tx fifo */
      .tx_req_i                 (spi_tx_fifo_req),
      .tx_data_i                (spi_tx_fifo_data),
      .tx_ack_o                 (spi_tx_fifo_ack),
      .tx_occupancy_o           (spi_tx_fifo_occupancy_reg),

      /* rx fifo */
      .rx_req_i                 (spi_rx_fifo_req),
      .rx_data_o                (spi_rx_fifo_data),
      .rx_resp_o                (spi_rx_fifo_resp),
      .rx_ack_i                 (spi_rx_fifo_ack),
      .rx_occupancy_o           (spi_rx_fifo_occupancy_reg),

      /* spi */
      .spi_clk_o                (spi_clk_o),
      .spi_cs_n_o               (spi_cs_n_o),
      .spi_mosi_o               (spi_mosi_o),
      .spi_miso_i               (spi_miso_i)
    );

endmodule
