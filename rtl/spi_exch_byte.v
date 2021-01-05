/*
 * Author:        Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:          spi_exch_byte.v
 * Description:   SPI mosi/miso data exchange control
 * Organizations: BSC; CIC-IPN
 */
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
  input                   clk_i;
  input                   arst_n_i;
  input                   sclk_i;

  /* ctrl */
  input                   msb_lsb_sel_i;
  input                   exchange_i;
  output  reg             sclk_en_o ;
  output  reg             busy_o ;
  output  reg             ready_o ;

  /* data */
  input       [BYTE-1:0]  data_i;
  output  reg [BYTE-1:0]  data_o ;

  /* mosi/miso */
  input                   miso_i;
  output  reg             mosi_o ;

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
  reg [2:0] fsm_exch_byte;
    localparam  StateInit     = 3'b000;
    localparam  StateIdle     = 3'b011;
    localparam  StateExchange = 3'b101;

  /* regs and wires */
  reg   [BYTE-1:0]  buffer_r;
  reg   [BYTE-1:0]  buffer_w;
  reg   [BYTE-1:0]  bitcount;
  reg               check_sdclk_edge ;
  wire  [BYTE-1:0]  data_s; //..data to be send
  wire  [BYTE-1:0]  data_r; //..data received
  wire  [BYTE-1:0]  data_s_i;
  wire  [BYTE-1:0]  buffer_r_n;

  /* state machine */
  always @ (posedge clk_i, negedge arst_n_i)  begin
    if(~arst_n_i) begin
      sclk_en_o         <=  DISABLED;
      busy_o            <=  IDLE;
      bitcount          <=  0;
      buffer_r          <=  0;
      buffer_w          <=  0;
      ready_o           <=  LOW;
      check_sdclk_edge  <=  POS_EDGE;
      data_o            <=  0;
      mosi_o            <=  HIGH;
      fsm_exch_byte     <=  StateInit;
    end
    else  begin
      case(fsm_exch_byte)
        StateInit:  begin
          sclk_en_o         <=  DISABLED;
          busy_o            <=  IDLE;
          bitcount          <=  0;
          buffer_r          <=  0;
          buffer_w          <=  0;
          ready_o           <=  LOW;
          data_o            <=  0;
          check_sdclk_edge  <=  POS_EDGE;
          mosi_o            <=  HIGH;
          fsm_exch_byte     <=  StateIdle;
        end
        StateIdle:  begin
          if(exchange_i)  begin
            sclk_en_o         <=  ENABLED;
            busy_o            <=  BUSY;
            bitcount          <=  0;
            check_sdclk_edge  <=  POS_EDGE;
            buffer_w          <=  data_s;
            mosi_o            <=  data_s[0];
            fsm_exch_byte     <=  StateExchange;
          end
          ready_o <=  LOW;
        end
        StateExchange:  begin
          case(check_sdclk_edge)
            POS_EDGE: begin
              if(sclk_i)  begin
                buffer_r[BYTE-1]    <=  miso_i;
                buffer_r[BYTE-2:0]  <=  buffer_r[BYTE-1:1];
                check_sdclk_edge    <=  NEG_EDGE;
              end
            end
            NEG_EDGE: begin
              if(~sclk_i) begin
                bitcount          <=  bitcount + 1;
                check_sdclk_edge  <=  POS_EDGE;
                if(&bitcount[2:0])  begin
                  sclk_en_o     <=  DISABLED;
                  busy_o        <=  IDLE;
                  data_o        <=  data_r;
                  mosi_o        <=  HIGH;
                  ready_o       <=  HIGH;
                  fsm_exch_byte <=  StateIdle;
                end
                else  begin
                  mosi_o        <=  buffer_w[1];
                  buffer_w[6:1] <=  buffer_w[7:2];
                end
              end
            end
          endcase
        end
        default:  fsm_exch_byte <=  StateInit;
      endcase
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

endmodule
