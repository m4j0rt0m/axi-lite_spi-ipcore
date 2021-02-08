/* -------------------------------------------------------------------------------
 * Project        : AXI-lite SPI IP Core
 * File           : axi_spi_top.v
 * Description    : AXI4-Lite SPI Slave Module
 * Organization   : BSC; CIC-IPN
 * Author(s)      : Abraham J. Ruiz R. (aruiz) (https://github.com/m4j0rt0m)
 * Email(s)       : abraham.ruiz@bsc.es; abraham.j.ruiz.r@gmail.com
 * References     :
 * -------------------------------------------------------------------------------
 * Revision History
 *  Revision   | Author      | Description
 *  1.0        | aruiz       | First version
 *  2.0        | aruiz       | Added asynchronous reset and soft reset
 *  2.1        | aruiz       | Code refactoring and added Ratio Clock Gen
 *  3.0        | aruiz       | Sync'd a main fixed clock and a variable faster
 *             |             | clock for the axi write/read transactions
 * -----------------------------------------------------------------------------*/

`default_nettype none

module axi_spi_top
(/*AUTOARG*/
   // Outputs
   axi_arready_o, axi_rid_o, axi_rdata_o, axi_rresp_o, axi_rvalid_o,
   axi_awready_o, axi_wready_o, axi_bid_o, axi_bresp_o, axi_bvalid_o,
   spi_clk_o, spi_cs_n_o, spi_mosi_o,
   // Inputs
   fixed_clk_i, axi_aclk_i, axi_aresetn_i, axi_arid_i, axi_araddr_i,
   axi_arvalid_i, axi_rready_i, axi_awid_i, axi_awaddr_i,
   axi_awvalid_i, axi_wdata_i, axi_wstrb_i, axi_wvalid_i,
   axi_bready_i, spi_miso_i
   );

  /* includes */
  `include "axi_spi_defines.vh"
  `include "axi_spi.vh"

  /* local parameters */
  localparam  BYTE            = 8;
  localparam  AXI_DATA_WIDTH  = `_AXI_SPI_DATA_WIDTH_;
  localparam  AXI_ADDR_WIDTH  = `_AXI_SPI_ADDR_WIDTH_;
  localparam  AXI_ID_WIDTH    = `_AXI_SPI_ID_WIDTH_;
  localparam  AXI_RESP_WIDTH  = `_AXI_SPI_RESP_WIDTH_;
  localparam  AXI_FIFO_DEPTH  = `_AXI_SPI_FIFO_DEPTH_;
  localparam  AXI_FIFO_ADDR   = $clog2(AXI_FIFO_DEPTH);
  localparam  AXI_BYTE_NUM    = AXI_DATA_WIDTH/BYTE;
  localparam  AXI_LSB_WIDTH   = $clog2(AXI_BYTE_NUM);
  localparam  DEADLOCK_LIMIT  = 15;
  localparam  DEADLOCK_WIDTH  = $clog2(DEADLOCK_LIMIT);

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
  input   wire                        fixed_clk_i;
  input   wire                        axi_aclk_i;
  input   wire                        axi_aresetn_i;

  input   wire  [AXI_ID_WIDTH-1:0]    axi_arid_i;
  input   wire  [AXI_ADDR_WIDTH-1:0]  axi_araddr_i;
  input   wire                        axi_arvalid_i;
  output  wire                        axi_arready_o;

  output  wire  [AXI_ID_WIDTH-1:0]    axi_rid_o;
  output  wire  [AXI_DATA_WIDTH-1:0]  axi_rdata_o;
  output  wire  [AXI_RESP_WIDTH-1:0]  axi_rresp_o;
  output  wire                        axi_rvalid_o;
  input   wire                        axi_rready_i;

  input   wire  [AXI_ID_WIDTH-1:0]    axi_awid_i;
  input   wire  [AXI_ADDR_WIDTH-1:0]  axi_awaddr_i;
  input   wire                        axi_awvalid_i;
  output  wire                        axi_awready_o;

  input   wire  [AXI_DATA_WIDTH-1:0]  axi_wdata_i;
  input   wire  [AXI_BYTE_NUM-1:0]    axi_wstrb_i;
  input   wire                        axi_wvalid_i;
  output  wire                        axi_wready_o;

  output  wire  [AXI_ID_WIDTH-1:0]    axi_bid_o;
  output  wire  [AXI_RESP_WIDTH-1:0]  axi_bresp_o;
  output  wire                        axi_bvalid_o;
  input   wire                        axi_bready_i;

  /* spi interface ports */
  output  wire                        spi_clk_o;
  output  wire                        spi_cs_n_o;
  output  wire                        spi_mosi_o;
  input   wire                        spi_miso_i;

  /* integers and genvars */
  genvar I;

  /* regs and wires declarations */
  reg                         soft_reset;       //..spi control soft reset (by software or deadlock)
  wire                        axi_wren;         //..axi-transaction write enable
  wire                        axi_nwren;        //..axi-transaction write disable
  wire                        axi_rden;         //..axi-transaction read enable
  wire                        axi_nrden;        //..axi-transaction read disable
  wire                        axi_wrresp;       //..axi-transaction write valid response
  wire                        axi_nwrresp;      //..axi-transaction write finished response
  wire                        axi_rdresp;       //..axi-transaction read valid response
  wire                        axi_nrdresp;      //..axi-transaction read finished response
  reg                         axi_sync_wren;    //..write axi-transaction synchronizer between clock domains
  reg                         axi_sync_rden;    //..read axi-transaction synchronizer between clock domains
  reg   [DEADLOCK_WIDTH:0]    wr_deadlock_cnt;  //..write deadlock counter
  reg   [DEADLOCK_WIDTH:0]    rd_deadlock_cnt;  //..read deadlock counter
  reg                         wr_deadlock;      //..write deadlock counter enable
  reg                         rd_deadlock;      //..read deadlock counter enable
  reg                         wr_timeout;       //..write deadlock timeout
  reg                         rd_timeout;       //..read deadlock timeout
  wire  [AXI_DATA_WIDTH-1:0]  write_data;       //..write data after byte enable

  /* axi interface registers declarations */
  reg                         axi_awready;  //..aw  channel - ready
  reg                         axi_wready;   //..w   channel - ready
  reg   [AXI_ID_WIDTH-1:0]    axi_bid;      //..b   channel - id
  reg   [AXI_RESP_WIDTH-1:0]  axi_bresp;    //..b   channel - resp
  reg                         axi_bvalid;   //..b   channel - valid
  reg                         axi_arready;  //..ar  channel - ready
  reg   [AXI_ID_WIDTH-1:0]    axi_rid;      //..r   channel - id
  reg   [AXI_DATA_WIDTH-1:0]  axi_rdata;    //..r   channel - data
  reg   [AXI_RESP_WIDTH-1:0]  axi_rresp;    //..r   channel - resp
  reg                         axi_rvalid;   //..r   channel - valid

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

  /* axi-transaction start-end enable assignments */
  assign axi_wren     = axi_awvalid_i & axi_wvalid_i;
  assign axi_nwren    = ~(axi_awvalid_i | axi_wvalid_i | axi_bvalid_o);
  assign axi_rden     = axi_arvalid_i;
  assign axi_nrden    = ~(axi_arvalid_i | axi_rvalid_o);

  /* axi-transaction start-end response assignments */
  assign axi_wrresp   = axi_awready & axi_wready;
  assign axi_nwrresp  = ~(axi_awready | axi_wready | axi_bvalid);
  assign axi_rdresp   = axi_arready;
  assign axi_nrdresp  = ~(axi_arready | axi_rvalid);

  /* axi-transaction synchronizer - write */
  always @ (posedge axi_aclk_i, negedge axi_aresetn_i) begin
    if(~axi_aresetn_i)
      axi_sync_wren <= 1'b0;
    else begin
      if(wr_timeout)
        axi_sync_wren <= 1'b0;
      else begin
        case(axi_sync_wren)
          1'b0: axi_sync_wren <= (axi_nwren & axi_wrresp) ? 1'b1 : 1'b0;
          1'b1: axi_sync_wren <= (axi_nwrresp) ? 1'b0 : 1'b1;
        endcase
      end
    end
  end

  /* axi-transaction synchronizer - read */
  always @ (posedge axi_aclk_i, negedge axi_aresetn_i) begin
    if(~axi_aresetn_i)
      axi_sync_rden <= 1'b0;
    else begin
      if(rd_timeout)
        axi_sync_rden <= 1'b0;
      else begin
        case(axi_sync_rden)
          1'b0: axi_sync_rden <= (axi_nrden & axi_rdresp) ? 1'b1 : 1'b0;
          1'b1: axi_sync_rden <= (axi_nrdresp) ? 1'b0 : 1'b1;
        endcase
      end
    end
  end

  /* axi responses assignments */
  assign axi_awready_o  = (axi_wren & ~axi_sync_wren) ? axi_awready : 1'b0;
  assign axi_wready_o   = (axi_wren & ~axi_sync_wren) ? axi_wready  : 1'b0;
  assign axi_bid_o      = /*(axi_wren & ~axi_sync_wren) ?*/ axi_bid /*    : {AXI_ID_WIDTH{1'b0}}*/;
  assign axi_bresp_o    = (axi_wren & ~axi_sync_wren) ? axi_bresp   : {AXI_RESP_WIDTH{1'b0}};
  assign axi_bvalid_o   = (axi_wren & ~axi_sync_wren) ? axi_bvalid  : 1'b0;
  assign axi_arready_o  = (axi_rden & ~axi_sync_rden) ? axi_arready : 1'b0;
  assign axi_rid_o      = /*(axi_rden & ~axi_sync_rden) ?*/ axi_rid /*    : {AXI_ID_WIDTH{1'b0}}*/;
  assign axi_rdata_o    = /*(axi_rden & ~axi_sync_rden) ?*/ axi_rdata /*  : {AXI_DATA_WIDTH{1'b0}}*/;
  assign axi_rresp_o    = (axi_rden & ~axi_sync_rden) ? axi_rresp   : {AXI_RESP_WIDTH{1'b0}};
  assign axi_rvalid_o   = (axi_rden & ~axi_sync_rden) ? axi_rvalid  : 1'b0;

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

  /* axi slave fsm - write interface */
  always @ (posedge fixed_clk_i, negedge axi_aresetn_i)  begin
    if(~axi_aresetn_i)  begin
      axi_awready                 <= 1'b0;
      axi_wready                  <= 1'b0;
      axi_bresp                   <= {AXI_RESP_WIDTH{1'b0}};
      axi_bvalid                  <= 1'b0;
      axi_bid                     <= {AXI_ID_WIDTH{1'b0}};
      spi_control_reg             <= SPI_CR_INIT;
      spi_slave_select_reg        <= SPI_SSR_INIT;
      spi_global_interrupt_en_reg <= SPI_GIER_INIT;
      spi_interrupt_status_reg    <= SPI_ISR_INIT;
      spi_interrupt_enable_reg    <= SPI_IER_INIT;
      spi_ratio_reg               <= SPI_RCLK_INIT;
      soft_reset                  <= 1'b1;
      wr_deadlock                 <= 1'b0;
      spi_tx_fifo_data            <= {DATA_WIDTH_SPI{1'b0}};
      spi_tx_fifo_req             <= 0;
      fsm_axi_wr                  <= StateInitWr;
    end
    else  begin
      case(fsm_axi_wr)
        StateInitWr:  begin      //..reset axi regs
          axi_awready                 <= 1'b0;
          axi_wready                  <= 1'b0;
          axi_bresp                   <= {AXI_RESP_WIDTH{1'b0}};
          axi_bvalid                  <= 1'b0;
          axi_bid                     <= {AXI_ID_WIDTH{1'b0}};
          spi_control_reg             <= SPI_CR_INIT;
          spi_slave_select_reg        <= SPI_SSR_INIT;
          spi_global_interrupt_en_reg <= SPI_GIER_INIT;
          spi_interrupt_status_reg    <= SPI_ISR_INIT;
          spi_interrupt_enable_reg    <= SPI_IER_INIT;
          spi_ratio_reg               <= SPI_RCLK_INIT;
          soft_reset                  <= 1'b1;
          wr_deadlock                 <= 1'b0;
          spi_tx_fifo_data            <= {DATA_WIDTH_SPI{1'b0}};
          spi_tx_fifo_req             <= 0;
          fsm_axi_wr                  <= StateResetWr;
        end
        StateResetWr: begin
          axi_awready                 <= 1'b0;
          axi_wready                  <= 1'b0;
          axi_bresp                   <= {AXI_RESP_WIDTH{1'b0}};
          axi_bvalid                  <= 1'b0;
          axi_bid                     <= {AXI_ID_WIDTH{1'b0}};
          spi_control_reg             <= SPI_CR_INIT;
          spi_slave_select_reg        <= SPI_SSR_INIT;
          spi_global_interrupt_en_reg <= SPI_GIER_INIT;
          spi_interrupt_status_reg    <= SPI_ISR_INIT;
          spi_interrupt_enable_reg    <= SPI_IER_INIT;
          spi_ratio_reg               <= SPI_RCLK_INIT;
          soft_reset                  <= 1'b0;
          wr_deadlock                 <= 1'b0;
          spi_tx_fifo_data            <= {DATA_WIDTH_SPI{1'b0}};
          spi_tx_fifo_req             <= 0;
          fsm_axi_wr                  <= StateIdleWr;
        end
        StateIdleWr:  begin
          if(axi_wren)  begin  //..write operation
            /* update data */
            case(axi_awaddr_i[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH])
              SPI_GIER[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: spi_global_interrupt_en_reg <= write_data;
              SPI_ISR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  spi_interrupt_status_reg    <= spi_interrupt_status_reg ^ write_data;
              SPI_IER[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  spi_interrupt_enable_reg    <= write_data;
              SPI_CR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:   spi_control_reg             <= write_data;
              SPI_DTR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin
                spi_tx_fifo_data  <= write_data[DATA_WIDTH_SPI-1:0];
                if(spi_tx_fifo_ack)
                  spi_tx_fifo_req <= 0;
                else
                  spi_tx_fifo_req <= 1;
              end
              SPI_SSR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  spi_slave_select_reg        <= write_data;
              SPI_RCLK[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: spi_ratio_reg               <= write_data[SPI_RATIO_GRADE-1:0];
              default:  begin
                spi_global_interrupt_en_reg <= spi_global_interrupt_en_reg;
                spi_interrupt_status_reg    <= spi_interrupt_status_reg;
                spi_interrupt_enable_reg    <= spi_interrupt_enable_reg;
                spi_control_reg             <= spi_control_reg;
                spi_tx_fifo_data            <= spi_tx_fifo_data;
                spi_tx_fifo_req             <= spi_tx_fifo_req;
                spi_slave_select_reg        <= spi_slave_select_reg;
                spi_ratio_reg               <= spi_ratio_reg;
              end
            endcase
            /* change state */
            case(axi_awaddr_i[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH])
              SPI_DTR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin //..add an entry into the TX fifo if there is a free slot
                if(spi_tx_fifo_ack) begin
                  axi_awready <= 1'b1;                   //..write address transaction acknowledge
                  axi_wready  <= 1'b1;                   //..write data transaction acknowledge
                  axi_bresp   <= {AXI_RESP_WIDTH{1'b0}}; //..write response "OKAY"
                  axi_bvalid  <= 1'b1;                   //..write response valid
                  axi_bid     <= axi_awid_i;             //..write transaction id
                  fsm_axi_wr  <= StateResponseWr;
                end
              end
              SPI_SRR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin //..check for "0x0000000a", then reset axi spi reg values
                if(write_data==SPI_SRR_VALUE)
                  soft_reset    <= 1'b1;                 //..soft reset asserted
                axi_awready <= 1'b1;                   //..write address transaction acknowledge
                axi_wready  <= 1'b1;                   //..write data transaction acknowledge
                axi_bresp   <= {AXI_RESP_WIDTH{1'b0}}; //..write response "OKAY"
                axi_bvalid  <= 1'b1;                   //..write response valid
                axi_bid     <= axi_awid_i;             //..write transaction id
                fsm_axi_wr  <= StateResponseWr;
              end
              SPI_CR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:   begin //..update control (just clear fifo reset bits)
                fsm_axi_wr  <= StateControlWr;
              end
              default:  begin //..assert "request_finished" signal
                axi_awready <= 1'b1;                   //..write address transaction acknowledge
                axi_wready  <= 1'b1;                   //..write data transaction acknowledge
                axi_bresp   <= {AXI_RESP_WIDTH{1'b0}}; //..write response "OKAY"
                axi_bvalid  <= 1'b1;                   //..write response valid
                axi_bid     <= axi_awid_i;             //..write transaction id
                fsm_axi_wr  <= StateResponseWr;
              end
            endcase
          end
          wr_deadlock <= 1'b0;
        end
        StateControlWr: begin
          spi_control_reg[CR_TX_FIFO_RESET_BIT] <= 1'b0;
          spi_control_reg[CR_RX_FIFO_RESET_BIT] <= 1'b0;
          axi_awready                           <= 1'b1;                   //..write address transaction acknowledge
          axi_wready                            <= 1'b1;                   //..write data transaction acknowledge
          axi_bresp                             <= {AXI_RESP_WIDTH{1'b0}}; //..write response "OKAY"
          axi_bvalid                            <= 1'b1;                   //..write response valid
          axi_bid                               <= axi_awid_i;             //..write transaction id
          wr_deadlock                           <= 1'b0;
          fsm_axi_wr                            <= StateResponseWr;
        end
        StateResponseWr:  begin
          if(axi_nwren) begin //..wait for the write transaction to finish
            if(soft_reset)
              fsm_axi_wr  <= StateResetWr;
            else
              fsm_axi_wr  <= StateIdleWr;
            axi_bid <= {AXI_ID_WIDTH{1'b0}};
          end
          else if(wr_timeout)
            fsm_axi_wr  <= StateInitWr;
          /* clear ready and valid bits for every channel */
          // if(~axi_wvalid_i)
          axi_wready  <= 1'b0;
          // if(~axi_awvalid_i)
          axi_awready <= 1'b0;
          // if(axi_bready_i)
          axi_bvalid  <= 1'b0;
          axi_bresp   <= {AXI_RESP_WIDTH{1'b0}};
          /* deadlock-free */
          wr_deadlock <= 1'b1;
        end
        default:  begin
          soft_reset  <= 1'b1;
          fsm_axi_wr  <= StateInitWr;
        end
      endcase
    end
  end

  /* axi slave fsm - read interface */
  always @ (posedge fixed_clk_i, negedge axi_aresetn_i)  begin
    if(~axi_aresetn_i)  begin
      axi_arready     <= 1'b0;
      axi_rdata       <= {AXI_DATA_WIDTH{1'b0}};
      axi_rresp       <= 2'b00;
      axi_rvalid      <= 1'b0;
      axi_rid         <= {AXI_ID_WIDTH{1'b0}};
      spi_rx_fifo_ack <= 1'b0;
      rd_deadlock     <= 1'b0;
      spi_rx_fifo_req <= 1'b0;
      fsm_axi_rd      <= StateInitRd;
    end
    else  begin
      case(fsm_axi_rd)
        StateInitRd:  begin //..reset axi regs
          axi_arready     <= 1'b0;
          axi_rdata       <= {AXI_DATA_WIDTH{1'b0}};
          axi_rresp       <= 2'b00;
          axi_rvalid      <= 1'b0;
          axi_rid         <= {AXI_ID_WIDTH{1'b0}};
          spi_rx_fifo_ack <= 1'b0;
          rd_deadlock     <= 1'b0;
          spi_rx_fifo_req <= 1'b0;
          fsm_axi_rd      <= StateIdleRd;
        end
        StateIdleRd:  begin
          if(axi_rden)  begin //..read operation
            /* read data */
            case(axi_araddr_i[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH])
              SPI_GIER[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: axi_rdata <= spi_global_interrupt_en_reg;
              SPI_ISR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  axi_rdata <= spi_interrupt_status_reg;
              SPI_IER[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  axi_rdata <= spi_interrupt_enable_reg;
              SPI_CR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:   axi_rdata <= spi_control_reg;
              SPI_SR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:   axi_rdata <= spi_status_reg;
              SPI_DTR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  axi_rdata <= {{(AXI_DATA_WIDTH-DATA_WIDTH_SPI){1'b0}}, spi_tx_fifo_data};
              SPI_DRR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin
                axi_rdata <= {{(AXI_DATA_WIDTH-DATA_WIDTH_SPI){1'b0}}, spi_rx_fifo_data};
                if(spi_rx_fifo_resp)
                  spi_rx_fifo_req <= 0;
                else
                  spi_rx_fifo_req <= 1;
              end
              SPI_SSR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  axi_rdata <= spi_slave_select_reg;
              SPI_TFOR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: axi_rdata <= spi_tx_fifo_occupancy_reg;
              SPI_RFOR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]: axi_rdata <= spi_rx_fifo_occupancy_reg;
              default:                                  axi_rdata <= 32'h61626364;
            endcase
            /* change state */
            case(axi_araddr_i[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH])
              SPI_DRR[AXI_ADDR_WIDTH-1:AXI_LSB_WIDTH]:  begin
                if(spi_rx_fifo_resp)  begin
                  axi_arready     <= 1'b1;
                  axi_rresp       <= 2'b00;
                  axi_rvalid      <= 1'b1;
                  axi_rid         <= axi_arid_i;
                  spi_rx_fifo_ack <= 1'b1;
                  fsm_axi_rd      <= StateResponseRd;
                end
              end
              default:  begin
                axi_arready <= 1'b1;
                axi_rresp   <= 2'b00;
                axi_rvalid  <= 1'b1;
                axi_rid     <= axi_arid_i;
                fsm_axi_rd  <= StateResponseRd;
              end
            endcase
          end
          rd_deadlock <= 1'b0;
        end
        StateResponseRd:  begin
          if(axi_nrden) begin
            axi_rid     <= axi_arid_i;
            fsm_axi_rd  <= StateIdleRd;
          end
          else if(rd_timeout)
            fsm_axi_rd  <= StateInitRd;
          /* clear ready and valid bits for every channel */
          // if(~axi_arvalid_i)
          axi_arready     <= 1'b0;
          // if(axi_rready_i)
          axi_rvalid      <= 1'b0;
          axi_rresp       <= 2'b00;
          spi_rx_fifo_ack <= 1'b0;
          /* deadlock-free */
          rd_deadlock     <= 1'b1;
        end
        default: fsm_axi_rd <= StateInitRd;
      endcase
    end
  end

  /* deadlock counters - write */
  always @ (posedge fixed_clk_i, negedge axi_aresetn_i)  begin
    if(~axi_aresetn_i)  begin
      wr_deadlock_cnt <= 0;
      wr_timeout      <= 1'b0;
    end
    else  begin
      if(wr_deadlock) begin
        wr_deadlock_cnt <= wr_deadlock_cnt + {{DEADLOCK_WIDTH{1'b0}},1'b1};
        if(wr_deadlock_cnt==DEADLOCK_LIMIT)
          wr_timeout    <= 1'b1;
      end
      else  begin
        wr_deadlock_cnt <= 0;
        wr_timeout      <= 1'b0;
      end
    end
  end

  /* deadlock counters - read */
  always @ (posedge fixed_clk_i, negedge axi_aresetn_i)  begin
    if(~axi_aresetn_i)  begin
      rd_deadlock_cnt <= 0;
      rd_timeout      <= 1'b0;
    end
    else  begin
      if(rd_deadlock) begin
        rd_deadlock_cnt <= rd_deadlock_cnt + {{DEADLOCK_WIDTH{1'b0}},1'b1};
        if(rd_deadlock_cnt==DEADLOCK_LIMIT)
          rd_timeout    <= 1'b1;
      end
      else  begin
        rd_deadlock_cnt <= 0;
        rd_timeout      <= 1'b0;
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
      .clk_i                    (fixed_clk_i),
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

`default_nettype wire
