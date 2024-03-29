/* -------------------------------------------------------------------------------
 * Project        : AXI-lite SPI IP Core
 * File           : axi_spi_ctrl.v
 * Description    : AXI4-Lite SPI Full Controller
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

module axi_spi_ctrl
# (
    parameter SPI_RATIO_GRADE = 2,
    parameter DATA_WIDTH      = 8,
    parameter REG_WIDTH       = 32,
    parameter FIFO_DEPTH      = 64,
    parameter FIFO_ADDR       = 6,
    parameter SR_RX_EMPTY_BIT = 0,
    parameter SR_RX_FULL_BIT  = 1,
    parameter SR_TX_EMPTY_BIT = 2,
    parameter SR_TX_FULL_BIT  = 3,
    parameter SR_MODF_BIT     = 4,
    parameter SR_SMOD_SEL_BIT = 5
  )
(/*AUTOARG*/
   // Outputs
   status_o, tx_ack_o, tx_occupancy_o, rx_data_o, rx_resp_o,
   rx_occupancy_o, spi_clk_o, spi_cs_n_o, spi_mosi_o,
   // Inputs
   clk_i, arst_n_i, soft_rst_i, slave_select_i, control_lsb_i,
   control_rx_fifo_reset_i, control_tx_fifo_reset_i, control_cpha_i,
   control_cpol_i, control_master_i, control_spi_enable_i,
   spi_ratio_i, tx_req_i, tx_data_i, rx_req_i, rx_ack_i, spi_miso_i
   );

  /* flow ctrl */
  input   wire                        clk_i;
  input   wire                        arst_n_i;
  input   wire                        soft_rst_i;

  /* ctrl */
  input   wire                        slave_select_i;
  input   wire                        control_lsb_i;
  input   wire                        control_rx_fifo_reset_i;
  input   wire                        control_tx_fifo_reset_i;
  input   wire                        control_cpha_i;       //..temporary not used
  input   wire                        control_cpol_i;       //..temporary not used
  input   wire                        control_master_i;     //..temporary ignored (used only for status)
  input   wire                        control_spi_enable_i; //..temporary ignored
  input   wire  [SPI_RATIO_GRADE-1:0] spi_ratio_i;

  /* status */
  output  reg   [REG_WIDTH-1:0]       status_o;

  /* tx fifo */
  input   wire                        tx_req_i;
  input   wire  [DATA_WIDTH-1:0]      tx_data_i;
  output  wire                        tx_ack_o;
  output  wire  [REG_WIDTH-1:0]       tx_occupancy_o;

  /* rx fifo */
  input   wire                        rx_req_i;
  output  wire  [DATA_WIDTH-1:0]      rx_data_o;
  output  wire                        rx_resp_o;
  input   wire                        rx_ack_i;
  output  wire  [REG_WIDTH-1:0]       rx_occupancy_o;

  /* spi */
  output  wire                        spi_clk_o;
  output  wire                        spi_cs_n_o;
  output  wire                        spi_mosi_o;
  input   wire                        spi_miso_i;

  /* local parameters */
  localparam  READ  = 1'b1;
  localparam  WRITE = 1'b0;

  /* status bits */
  localparam  RX_EMPTY_BIT  = 0;
  localparam  RX_FULL_BIT   = 1;
  localparam  TX_EMPTY_BIT  = 2;
  localparam  TX_FULL_BIT   = 3;
  localparam  MODF_BIT      = 4;
  localparam  SMOD_SEL_BIT  = 5;

  /* regs and wires */
  wire  [DATA_WIDTH-1:0]  tx_data;
  reg                     tx_req, tx_req_d;
  wire                    tx_resp;
  reg                     tx_ack, tx_ack_d;
  reg   [DATA_WIDTH-1:0]  rx_data, rx_data_d;
  reg                     rx_req, rx_req_d;
  wire                    rx_ack;
  reg   [DATA_WIDTH-1:0]  spi_send_data, spi_send_data_d;
  wire  [DATA_WIDTH-1:0]  spi_recv_data;
  reg                     spi_exchange, spi_exchange_d;
  wire                    spi_busy;
  wire                    spi_ready;
  reg                     tx_ready, tx_ready_d;
  wire                    rx_valid;
  wire                    rx_full;
  wire                    rx_empty;
  wire                    tx_valid;
  wire                    tx_full;
  wire                    tx_empty;

  /* control state machine parameters */
  reg [4:0] fsm_spi_ctrl, fsm_spi_ctrl_d;
    localparam  StateInit     = 5'b00000; //..initial state
    localparam  StateIdle     = 5'b00011; //..checks if there is data to be sent in tx fifo
    localparam  StatePullData = 5'b00101; //..pull data from tx fifo
    localparam  StateExchange = 5'b01001; //..exchange a byte
    localparam  StatePushData = 5'b10001; //..push data into rx fifo

  /* control state machine: comb */
  always @ (*) begin
    spi_send_data_d = spi_send_data;
    spi_exchange_d  = spi_exchange;
    tx_ready_d      = tx_ready;
    tx_req_d        = tx_req;
    tx_ack_d        = tx_ack;
    rx_req_d        = rx_req;
    rx_data_d       = rx_data;
    fsm_spi_ctrl_d  = fsm_spi_ctrl;
    if(soft_rst_i) begin
      spi_send_data_d = 0;
      spi_exchange_d  = 0;
      tx_ready_d      = 0;
      tx_req_d        = 0;
      tx_ack_d        = 0;
      rx_req_d        = 0;
      rx_data_d       = 0;
      fsm_spi_ctrl_d  = StateInit;
    end
    else begin
      case(fsm_spi_ctrl)
        StateInit: begin
          spi_send_data_d = 0;
          spi_exchange_d  = 0;
          tx_ready_d      = 0;
          tx_req_d        = 0;
          tx_ack_d        = 0;
          rx_req_d        = 0;
          rx_data_d       = 0;
          fsm_spi_ctrl_d  = StateIdle;
        end
        StateIdle: begin
          if(tx_valid & ~tx_ack) begin //..check if there is available data to be sent in tx fifo
            tx_req_d        = 1'b1;
            fsm_spi_ctrl_d  = StatePullData;
          end
          tx_ack_d  = 1'b0;
        end
        StatePullData: begin
          if(tx_ready & ~spi_busy) begin //..wait until tx data is ready and spi_ctrl is free
            spi_exchange_d  = 1'b1;
            fsm_spi_ctrl_d  = StateExchange;
          end
          if(tx_resp) begin //..got data from tx fifo
            spi_send_data_d = tx_data;
            tx_ready_d      = 1'b1;
            tx_req_d        = 1'b0;
          end
        end
        StateExchange: begin
          if(spi_ready) begin //..finished exchanging data
            rx_data_d       = spi_recv_data;
            rx_req_d        = 1'b1;
            fsm_spi_ctrl_d  = StatePushData;
          end
          if(spi_busy) begin
            tx_ready_d      = 1'b0;
            spi_exchange_d  = 1'b0;
          end
        end
        StatePushData: begin
          if(rx_ack) begin
            rx_req_d        = 1'b0;
            tx_ack_d        = 1'b1; //..finished exchange process
            fsm_spi_ctrl_d  = StateIdle;
          end
        end
        default: begin
          spi_send_data_d = 0;
          spi_exchange_d  = 0;
          tx_ready_d      = 0;
          tx_req_d        = 0;
          tx_ack_d        = 0;
          rx_req_d        = 0;
          rx_data_d       = 0;
          fsm_spi_ctrl_d  = StateInit;
        end
      endcase
    end
  end

  /* control state machine: seq */
  always @ (posedge clk_i, negedge arst_n_i) begin
    if(~arst_n_i) begin
      spi_send_data <= 0;
      spi_exchange  <= 0;
      tx_ready      <= 0;
      tx_req        <= 0;
      tx_ack        <= 0;
      rx_req        <= 0;
      rx_data       <= 0;
      fsm_spi_ctrl  <= StateInit;
    end
    else begin
      spi_send_data <= spi_send_data_d;
      spi_exchange  <= spi_exchange_d;
      tx_ready      <= tx_ready_d;
      tx_req        <= tx_req_d;
      tx_ack        <= tx_ack_d;
      rx_req        <= rx_req_d;
      rx_data       <= rx_data_d;
      fsm_spi_ctrl  <= fsm_spi_ctrl_d;
    end
  end

  /* status */
  always @ (posedge clk_i, negedge arst_n_i) begin
    if(~arst_n_i)
      status_o  <= 0;
    else begin
      if(soft_rst_i)
        status_o  <= 0;
      else begin
        status_o[SR_RX_EMPTY_BIT] <= rx_empty;
        status_o[SR_RX_FULL_BIT]  <= rx_full;
        status_o[SR_TX_EMPTY_BIT] <= tx_empty;
        status_o[SR_TX_FULL_BIT]  <= tx_full;
        status_o[SR_SMOD_SEL_BIT] <= control_master_i;
      end
    end
  end

  /* tx fifo */
  spi_fifo
    # (
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .FIFO_ADDR  (FIFO_ADDR),
        .REG_WIDTH  (REG_WIDTH)
      )
    spi_fifo_tx (
      /* ctrl */
      .clk_i              (clk_i),
      .arst_n_i           (arst_n_i),
      .soft_rst_i         (soft_rst_i | control_tx_fifo_reset_i),
      .allow_overwrite_i  (1'b0),

      /* status */
      .fifo_occupancy_o   (tx_occupancy_o),
      .fifo_valid_o       (tx_valid),
      .fifo_full_o        (tx_full),
      .fifo_empty_o       (tx_empty),

      /* port a (WRITE port - receive from bus) */
      .req_a_i            (tx_req_i),
      .data_a_i           (tx_data_i),
      .ack_a_o            (tx_ack_o),

      /* port b (READ port - send to spi slave) */
      .req_b_i            (tx_req),
      .data_b_o           (tx_data),
      .resp_b_o           (tx_resp),
      .ack_b_i            (tx_ack)
    );

  /* rx fifo */
  spi_fifo
    # (
        .DATA_WIDTH (DATA_WIDTH),
        .FIFO_DEPTH (FIFO_DEPTH),
        .FIFO_ADDR  (FIFO_ADDR),
        .REG_WIDTH  (REG_WIDTH)
      )
    spi_fifo_rx (
      /* ctrl */
      .clk_i              (clk_i),
      .arst_n_i           (arst_n_i),
      .soft_rst_i         (soft_rst_i | control_rx_fifo_reset_i),
      .allow_overwrite_i  (1'b1),

      /* status */
      .fifo_occupancy_o   (rx_occupancy_o),
      .fifo_valid_o       (rx_valid),
      .fifo_full_o        (rx_full),
      .fifo_empty_o       (rx_empty),

      /* port a (WRITE port - receive from spi slave) */
      .req_a_i            (rx_req),
      .data_a_i           (rx_data),
      .ack_a_o            (rx_ack),

      /* port b (READ port - send to bus) */
      .req_b_i            (rx_req_i),
      .data_b_o           (rx_data_o),
      .resp_b_o           (rx_resp_o),
      .ack_b_i            (rx_ack_i)
    );


  /* spi ctrl */
  spi_ctrl
    # (
        .SPI_RATIO_GRADE (SPI_RATIO_GRADE)  //..spi clock ratio grade
      )
    spi_ctrl  (
      /* ctrl */
      .clk_i              (clk_i),
      .arst_n_i           (arst_n_i),
      .spi_select_i       (slave_select_i),
      .spi_msb_lsb_sel_i  (control_lsb_i),
      .spi_exchange_i     (spi_exchange),
      .spi_busy_o         (spi_busy),
      .spi_ready_o        (spi_ready),
      .spi_ratio_i        (spi_ratio_i),

      /* data */
      .spi_send_data_i    (spi_send_data),
      .spi_recv_data_o    (spi_recv_data),

      /* spi */
      .spi_clk_o          (spi_clk_o),
      .spi_cs_n_o         (spi_cs_n_o),
      .spi_mosi_o         (spi_mosi_o),
      .spi_miso_i         (spi_miso_i)
    );

endmodule

`default_nettype wire
