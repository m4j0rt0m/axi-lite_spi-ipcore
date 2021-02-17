/* -------------------------------------------------------------------------------
 * Project        : AXI-lite SPI IP Core
 * File           : spi_fifo.v
 * Description    : SPI FIFO controlled by push/pull
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

module spi_fifo
# (
    parameter DATA_WIDTH  = 16,
    parameter FIFO_DEPTH  = 16,
    parameter FIFO_ADDR   = 4,
    parameter REG_WIDTH   = 16
  )
(/*AUTOARG*/
   // Outputs
   fifo_occupancy_o, fifo_valid_o, fifo_full_o, fifo_empty_o, ack_a_o,
   data_b_o, resp_b_o,
   // Inputs
   clk_i, arst_n_i, soft_rst_i, allow_overwrite_i, req_a_i, data_a_i,
   req_b_i, ack_b_i
   );

  /* local parameters */
  localparam  READ    = 1'b1;
  localparam  WRITE   = 1'b0;
  localparam  REQ_A   = 2'b01;
  localparam  REQ_B   = 2'b10;
  localparam  REQ_AB  = 2'b11;
  localparam  PORT_A  = 1'b0;
  localparam  PORT_B  = 1'b1;

  /* flow control */
  input                     clk_i;                //..clock
  input                     arst_n_i;             //..active low asynchronous reset
  input                     soft_rst_i;           //..active high soft reset
  input                     allow_overwrite_i;    //..allow overwrite enable

  /* status */
  output  [REG_WIDTH-1:0]   fifo_occupancy_o;     //..occupancy register
  output                    fifo_valid_o;
  output                    fifo_full_o;
  output                    fifo_empty_o;

   /* write port */
  input                     req_a_i;              //..write request
  input   [DATA_WIDTH-1:0]  data_a_i;             //..write data
  output                    ack_a_o ;             //..acknowledge write request

   /* read port */
  input                     req_b_i;              //..read request
  output  [DATA_WIDTH-1:0]  data_b_o ;            //..read data
  output                    resp_b_o ;            //..read response
  input                     ack_b_i;              //..acknowledge read request

  /* fifo structure and variables */
  reg                     ack_a, ack_a_d;             //..acknowledge write request
  reg   [DATA_WIDTH-1:0]  data_b, data_b_d;           //..read data
  reg                     resp_b, resp_b_d;           //..read response
  reg   [DATA_WIDTH-1:0]  fifo [FIFO_DEPTH-1:0];      //..fifo
  reg   [FIFO_ADDR-1:0]   fifo_head_pointer;          //..fifo.head (read)
  reg   [FIFO_ADDR-1:0]   fifo_tail_pointer;          //..fifo.tail (write)
  reg   [FIFO_ADDR:0]     occupancy;                  //..fifo.occupancy
  reg                     allow_write, allow_write_d; //..fifo.allow write
  wire                    fifo_valid;                 //..fifo.valid slot
  wire                    fifo_free;                  //..fifo.free slot
  wire                    fifo_full;                  //..fifo.full
  wire                    fifo_empty;                 //..fifo.empty
  wire                    fifo_push;                  //..fifo.valid_push operation
  wire                    fifo_pull;                  //..fifo.valid_pull operation

  /* state machine */
  reg [2:0] fsm_fifo_wr, fsm_fifo_wr_d;
    localparam  StateInitWr = 3'b000;
    localparam  StateIdleWr = 3'b011;
    localparam  StateReqWr  = 3'b101;

  reg [2:0] fsm_fifo_rd, fsm_fifo_rd_d;
    localparam  StateInitRd = 3'b000;
    localparam  StateIdleRd = 3'b011;
    localparam  StateReqRd  = 3'b101;

  //..fifo write operation (note: initial values are not determined, nor required)
  always @ (posedge clk_i) begin
    if(req_a_i & allow_write & (~fifo_full | allow_overwrite_i))
      fifo[fifo_tail_pointer] <= data_a_i;
  end

  /* write request fsm: comb */
  //..controls write acknowledge signal
  //..controls allow overwritting
  always @ (*) begin
    allow_write_d = allow_write;
    ack_a_d       = ack_a;
    fsm_fifo_wr_d = fsm_fifo_wr;
    if(soft_rst_i) begin
      allow_write_d = 1'b0;
      ack_a_d       = 1'b0;
      fsm_fifo_wr_d = StateInitWr;
    end
    else begin
      case(fsm_fifo_wr)
        StateInitWr: begin
          allow_write_d = 1'b1;
          ack_a_d       = 1'b0;
          fsm_fifo_wr_d = StateIdleWr;
        end
        StateIdleWr: begin
          if(req_a_i) begin //..request from port a (write)
            if(~fifo_full | allow_overwrite_i) begin //..there's an empty fifo slot or overwritting is allowed
              allow_write_d = 1'b0;
              ack_a_d       = 1'b1;
              fsm_fifo_wr_d = StateReqWr;
            end
          end
        end
        StateReqWr: begin
          allow_write_d = 1'b1;
          ack_a_d       = 1'b0;
          fsm_fifo_wr_d = StateIdleWr;
        end
        default: begin
          allow_write_d = 1'b0;
          ack_a_d       = 1'b0;
          fsm_fifo_wr_d = StateInitWr;
        end
      endcase
    end
  end

  /* write request fsm: seq */
  //..controls write acknowledge signal
  //..controls allow overwritting
  always @ (posedge clk_i, negedge arst_n_i) begin
    if(~arst_n_i) begin
      allow_write <= 1'b0;
      ack_a       <= 1'b0;
      fsm_fifo_wr <= StateInitWr;
    end
    else begin
      allow_write <= allow_write_d;
      ack_a       <= ack_a_d;
      fsm_fifo_wr <= fsm_fifo_wr_d;
    end
  end

  /* read request fsm: comb */
  //..controls read response signal
  //..controls fifo read operation
  always @ (*) begin
    resp_b_d      = resp_b;
    data_b_d      = data_b;
    fsm_fifo_rd_d = fsm_fifo_rd;
    if(soft_rst_i) begin
      resp_b_d      = 1'b0;
      data_b_d      = {DATA_WIDTH{1'b0}};
      fsm_fifo_rd_d = StateInitRd;
    end
    else begin
      case(fsm_fifo_rd)
        StateInitRd: begin
          resp_b_d      = 1'b0;
          data_b_d      = {DATA_WIDTH{1'b0}};
          fsm_fifo_rd_d = StateIdleRd;
        end
        StateIdleRd: begin //..wait for request
          if(req_b_i) begin //..read request issued
            data_b_d      = fifo[fifo_head_pointer];
            resp_b_d      = 1'b1;
            fsm_fifo_rd_d = StateReqRd;
          end
        end
        StateReqRd: begin //..wait for acknowledge
          if(ack_b_i) begin
            resp_b_d      = 1'b0;
            fsm_fifo_rd_d = StateIdleRd;
          end
        end
        default: begin
          resp_b_d      = 1'b0;
          data_b_d      = {DATA_WIDTH{1'b0}};
          fsm_fifo_rd_d = StateInitRd;
        end
      endcase
    end
  end

  /* read request fsm: seq */
  //..controls read response signal
  //..controls fifo read operation
  always @ (posedge clk_i, negedge arst_n_i) begin
    if(~arst_n_i) begin
      resp_b      <= 1'b0;
      data_b      <= {DATA_WIDTH{1'b0}};
      fsm_fifo_rd <= StateInitRd;
    end
    else begin
      resp_b      <= resp_b_d;
      data_b      <= data_b_d;
      fsm_fifo_rd <= fsm_fifo_rd_d;
    end
  end

  assign fifo_pull = ack_b_i;
  assign fifo_push = ack_a_o;

  /* occupancy and pointers control */
  always @ (posedge clk_i, negedge arst_n_i) begin
    if(~arst_n_i) begin
      fifo_head_pointer <=  0;
      fifo_tail_pointer <=  0;
      occupancy         <=  0;
    end
    else begin
      if(soft_rst_i) begin
        fifo_head_pointer <=  0;
        fifo_tail_pointer <=  0;
        occupancy         <=  0;
      end
      else begin
        case({fifo_pull,fifo_push}) //..finished transactions
          REQ_A: begin //..write
            if(fifo_free) begin //..not full
              fifo_tail_pointer <=  fifo_tail_pointer + 1;
              occupancy         <=  occupancy + 1;
            end
            else if(allow_overwrite_i) begin //..full but overwritting allowed
              fifo_tail_pointer <=  fifo_tail_pointer + 1;
              fifo_head_pointer <=  fifo_head_pointer + 1;
            end
          end
          REQ_B: begin //..read
            if(fifo_valid) begin //..not empty
              fifo_head_pointer <=  fifo_head_pointer + 1;
              occupancy         <=  occupancy - 1;
            end
          end
          default:  occupancy <=  occupancy;
        endcase
      end
    end
  end

  /* valid reg logic */
  spi_valid_logic
    # (
        .DEPTH  (FIFO_DEPTH)
      )
    spi_valid_logic_i0  (
        .clk_i      (clk_i),
        .arst_n_i   (arst_n_i),
        .soft_rst_i (soft_rst_i),

        .push_i     (fifo_push),
        .pull_i     (fifo_pull),

        .valid_o    (fifo_valid),
        .full_o     (fifo_full),
        .empty_o    (fifo_empty)
      );

  /* assignmenst */
  assign fifo_valid_o     = fifo_valid;
  assign fifo_full_o      = fifo_full;
  assign fifo_empty_o     = fifo_empty;
  assign fifo_free        = ~fifo_full;
  assign fifo_occupancy_o[REG_WIDTH-1:(FIFO_ADDR+1)]  = 0;
  assign fifo_occupancy_o[FIFO_ADDR:0]                = occupancy;

  /* output assignments */
  assign ack_a_o  = ack_a;
  assign data_b_o = data_b;
  assign resp_b_o = resp_b;

 endmodule
