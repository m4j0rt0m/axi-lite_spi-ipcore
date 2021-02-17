/* -------------------------------------------------------------------------------
 * Project        : AXI-lite SPI IP Core
 * File           : spi_exch_byte.v
 * Description    : SPI mosi/miso data exchange control
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

module spi_exch_byte
# (
    parameter BYTE  = 8
  )
(/*AUTOARG*/
   // Outputs
   sclk_en_o, busy_o, ready_o, data_o, mosi_o,
   // Inputs
   clk_i, arst_n_i, sclk_i, msb_lsb_sel_i, exchange_i, data_i, miso_i
   );

  /* clks */
  input               clk_i;
  input               arst_n_i;
  input               sclk_i;

  /* ctrl */
  input               msb_lsb_sel_i;
  input               exchange_i;
  output              sclk_en_o ;
  output              busy_o ;
  output              ready_o ;

  /* data */
  input   [BYTE-1:0]  data_i;
  output  [BYTE-1:0]  data_o ;

  /* mosi/miso */
  input               miso_i;
  output              mosi_o ;

  /* integers and genvars */
  genvar I;

  /* local parameters */
  localparam  POS_EDGE  = 1'b0;
  localparam  NEG_EDGE  = 1'b1;
  localparam  DISABLED  = 1'b0;
  localparam  ENABLED   = 1'b1;
  localparam  IDLE      = 1'b0;
  localparam  BUSY      = 1'b1;
  localparam  HIGH      = 1'b1;
  localparam  LOW       = 1'b0;
  localparam  MSB       = 1'b0;
  localparam  LSB       = 1'b1;

  /* state machine parameters */
  reg [2:0] fsm_exch_byte, fsm_exch_byte_d;
    localparam  StateInit     = 3'b000;
    localparam  StateIdle     = 3'b011;
    localparam  StateExchange = 3'b101;

  /* regs and wires */
  reg               sclk_en, sclk_en_d;
  reg               busy, busy_d;
  reg               ready, ready_d;
  reg   [BYTE-1:0]  data, data_d;
  reg               mosi, mosi_d;
  reg   [BYTE-1:0]  buffer_r, buffer_r_d;
  reg   [BYTE-1:0]  buffer_w, buffer_w_d;
  reg   [BYTE-1:0]  bitcount, bitcount_d;
  reg               check_sdclk_edge, check_sdclk_edge_d;
  wire  [BYTE-1:0]  data_s; //..data to be send
  wire  [BYTE-1:0]  data_r; //..data received
  wire  [BYTE-1:0]  data_s_i;
  wire  [BYTE-1:0]  buffer_r_n;

  /* state machine: comb */
  always @ (*)  begin
    sclk_en_d           = sclk_en;
    busy_d              = busy;
    bitcount_d          = bitcount;
    buffer_r_d          = buffer_r;
    buffer_w_d          = buffer_w;
    ready_d             = ready;
    check_sdclk_edge_d  = check_sdclk_edge;
    data_d              = data;
    mosi_d              = mosi;
    fsm_exch_byte_d     = fsm_exch_byte;
    case(fsm_exch_byte)
      StateInit:  begin
        sclk_en_d           = DISABLED;
        busy_d              = IDLE;
        bitcount_d          = 0;
        buffer_r_d          = 0;
        buffer_w_d          = 0;
        ready_d             = LOW;
        data_d              = 0;
        check_sdclk_edge_d  = POS_EDGE;
        mosi_d              = HIGH;
        fsm_exch_byte_d     = StateIdle;
      end
      StateIdle:  begin
        if(exchange_i)  begin
          sclk_en_d           = ENABLED;
          busy_d              = BUSY;
          bitcount_d          = 0;
          check_sdclk_edge_d  = POS_EDGE;
          buffer_w_d          = data_s;
          mosi_d              = data_s[0];
          fsm_exch_byte_d     = StateExchange;
        end
        ready_d = LOW;
      end
      StateExchange:  begin
        case(check_sdclk_edge)
          POS_EDGE: begin
            if(sclk_i)  begin
              buffer_r_d[BYTE-1]    = miso_i;
              buffer_r_d[BYTE-2:0]  = buffer_r[BYTE-1:1];
              check_sdclk_edge_d    = NEG_EDGE;
            end
          end
          NEG_EDGE: begin
            if(~sclk_i) begin
              bitcount_d          = bitcount + 1;
              check_sdclk_edge_d  = POS_EDGE;
              if(&bitcount[2:0])  begin
                sclk_en_d       = DISABLED;
                busy_d          = IDLE;
                data_d          = data_r;
                mosi_d          = HIGH;
                ready_d         = HIGH;
                fsm_exch_byte_d = StateIdle;
              end
              else  begin
                mosi_d          = buffer_w[1];
                buffer_w_d[6:1] = buffer_w[7:2];
              end
            end
          end
        endcase
      end
      default: begin
        sclk_en_d           = DISABLED;
        busy_d              = IDLE;
        bitcount_d          = 0;
        buffer_r_d          = 0;
        buffer_w_d          = 0;
        ready_d             = LOW;
        check_sdclk_edge_d  = POS_EDGE;
        data_d              = 0;
        mosi_d              = HIGH;
        fsm_exch_byte_d     = StateInit;
      end
    endcase
  end

  /* state machine: seq */
  always @ (posedge clk_i, negedge arst_n_i)  begin
    if(~arst_n_i) begin
      sclk_en           <=  DISABLED;
      busy              <=  IDLE;
      bitcount          <=  0;
      buffer_r          <=  0;
      buffer_w          <=  0;
      ready             <=  LOW;
      check_sdclk_edge  <=  POS_EDGE;
      data              <=  0;
      mosi              <=  HIGH;
      fsm_exch_byte     <=  StateInit;
    end
    else  begin
      sclk_en           <=  sclk_en_d;
      busy              <=  busy_d;
      bitcount          <=  bitcount_d;
      buffer_r          <=  buffer_r_d;
      buffer_w          <=  buffer_w_d;
      ready             <=  ready_d;
      check_sdclk_edge  <=  check_sdclk_edge_d;
      data              <=  data_d;
      mosi              <=  mosi_d;
      fsm_exch_byte     <=  fsm_exch_byte_d;
    end
  end

  /* MSB/LSB */
  generate
    for(I=0; I<BYTE; I=I+1) begin:  rev_data_gen
      assign  data_s_i[I]   = data_i[BYTE-I-1];
      assign  buffer_r_n[I] = buffer_r[BYTE-I-1];
    end
  endgenerate
  assign  data_s  = (msb_lsb_sel_i==MSB) ? data_s_i   : data_i;
  assign  data_r  = (msb_lsb_sel_i==MSB) ? buffer_r_n : buffer_r;

  /* output assignments */
  assign sclk_en_o  = sclk_en;
  assign busy_o     = busy;
  assign ready_o    = ready;
  assign data_o     = data;
  assign mosi_o     = mosi;


endmodule
