/*
 * Author:				Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:					spi_fifo.v
 * Description:		SPI FIFO controlled by push/pull
 * Organizations:	BSC; CIC-IPN
 */
 module spi_fifo
 #	(
 		parameter	DATA_WIDTH	=	16,
 		parameter	FIFO_DEPTH	=	16,
 		parameter FIFO_ADDR		=	4,
 		parameter	REG_WIDTH		=	16
 	)
 (/*AUTOARG*/
   // Outputs
   ofifo_occupancy, ofifo_valid, ofifo_full, ofifo_empty, oack_a,
   odata_b, oresp_b,
   // Inputs
   iclk, irst, iallow_overwrite, ireq_a, idata_a, ireq_b, iack_b
   );

	/* includes */
	`include "my_defines.h"

 	/* local parameters */
 	localparam	READ			=	1'b1;
 	localparam	WRITE			=	1'b0;
 	localparam	REQ_A			=	2'b01;
 	localparam	REQ_B			=	2'b10;
 	localparam	REQ_AB		=	2'b11;
 	localparam	PORT_A		=	1'b0;
 	localparam	PORT_B		=	1'b1;

 	/* flow control */
 	input													iclk;							//..clock
 	input													irst;							//..active high reset
 	input													iallow_overwrite;	//..allow overwrite enable

	/* status */
	output 			[REG_WIDTH-1:0]		ofifo_occupancy;	//..occupancy register
	output 												ofifo_valid;
	output 												ofifo_full;
	output 												ofifo_empty;

 	/* write port */
	input													ireq_a;						//..write request
 	input				[DATA_WIDTH-1:0]	idata_a;					//..write data
 	output reg										oack_a = 0;				//..acknowledge write request

 	/* read port */
	input													ireq_b;						//..read request
 	output reg	[DATA_WIDTH-1:0]	odata_b = 0;			//..read data
 	output reg										oresp_b = 0;			//..read response
 	input 												iack_b;						//..acknowledge read request

 	/* fifo structure and variables */
 	reg	[DATA_WIDTH-1:0]	fifo [FIFO_DEPTH-1:0]	/* synthesis ramstyle = "M9K" */;	//..fifo
 	reg	[FIFO_ADDR-1:0]		fifo_head_pointer = 0;	//..fifo.head (read)
 	reg	[FIFO_ADDR-1:0]		fifo_tail_pointer = 0;	//..fifo.tail (write)
	reg [FIFO_ADDR:0]			occupancy = 0;					//..fifo.occupancy
 	wire									fifo_valid;							//..fifo.valid slot
	wire 									fifo_free;							//..fifo.free slot
	wire 									fifo_full;							//..fifo.full
	wire 									fifo_empty;							//..fifo.empty
	wire 									fifo_push;							//..fifo.valid_push operation
	wire 									fifo_pull;							//..fifo.valid_pull operation

 	/* state machine */
 	reg	[2:0]	fsm_fifo_wr;
 		localparam	StateInitWr	=	3'b000;
 		localparam	StateIdleWr	=	3'b011;
 		localparam	StateReqWr	=	3'b101;
 			initial fsm_fifo_wr = StateInitWr;

	reg [2:0]	fsm_fifo_rd;
		localparam  StateInitRd = 3'b000;
		localparam  StateIdleRd = 3'b011;
		localparam  StateReqRd	= 3'b101;
			initial fsm_fifo_rd = StateInitRd;

 	/* write request fsm */
	//..controls write acknowledge signal
	//..controls fifo write operation
	//..controls allow overwritting
 	always @ (posedge iclk)	begin
 		case(fsm_fifo_wr)
 			StateInitWr:	begin
 				oack_a						<=	1'b0;
 				fsm_fifo_wr				<=	StateIdleWr;
 			end
 			StateIdleWr:	begin
 				if(irst)
 					fsm_fifo_wr	<=	StateInitWr;
 				else if(ireq_a)	begin	//..request from port a (write)
					if(~fifo_full | iallow_overwrite)	begin	//..there's an empty fifo slot or overwritting is allowed
						fifo[fifo_tail_pointer]	<=	idata_a;
						oack_a									<=	1'b1;
						fsm_fifo_wr							<=	StateReqWr;
					end
 				end
 			end
 			StateReqWr:	begin
 				if(irst)
 					fsm_fifo_wr	<=	StateInitWr;
 				else	begin
					oack_a			<=	1'b0;
					fsm_fifo_wr	<=	StateIdleWr;
 				end
 			end
 			default:	fsm_fifo_wr	<=	fsm_fifo_wr;
 		endcase
 	end

	/* read request fsm */
	//..controls read response signal
	//..controls fifo read operation
	always @ (posedge iclk) begin
		case(fsm_fifo_rd)
			StateInitRd:	begin
				oresp_b		<=	1'b0;
				odata_b		<=	{DATA_WIDTH{1'b0}};
				if(~irst)
					fsm_fifo_rd	<=	StateIdleRd;
			end
			StateIdleRd:	begin	//..wait for request
				if(irst)
					fsm_fifo_rd	<=	StateInitRd;
				else begin
					if(ireq_b)	begin	//..read request issued
						odata_b				<=	fifo[fifo_head_pointer];
						oresp_b				<=	1'b1;
						fsm_fifo_rd		<=	StateReqRd;
					end
				end
			end
			StateReqRd:		begin	//..wait for acknowledge
				if(irst)
					fsm_fifo_rd	<=	StateInitRd;
				else begin
					if(iack_b)	begin
						oresp_b				<=	1'b0;
						fsm_fifo_rd		<=	StateIdleRd;
					end
				end
			end
			default:	fsm_fifo_rd	<=	fsm_fifo_rd;
		endcase
	end

	assign	fifo_pull	=	iack_b;
	assign	fifo_push	=	oack_a;

	/* occupancy and pointers control */
	always @ (posedge iclk) begin
		if(irst) begin
			fifo_head_pointer	<=	0;
			fifo_tail_pointer	<=	0;
			occupancy					<=	0;
		end
		else begin
			case({fifo_pull,fifo_push})	//..finished transactions
				REQ_A:	begin										//..write
					if(fifo_free)	begin							//..not full
						fifo_tail_pointer							<=	fifo_tail_pointer + {{`_DIFF_SIZE_(FIFO_ADDR,1){1'b0}},1'b1};
						occupancy											<=	occupancy + {{FIFO_ADDR{1'b0}},1'b1};
					end
					else if(iallow_overwrite) begin	//..full but overwritting allowed
						fifo_tail_pointer							<=	fifo_tail_pointer + {{`_DIFF_SIZE_(FIFO_ADDR,1){1'b0}},1'b1};
						fifo_head_pointer							<=	fifo_head_pointer + {{`_DIFF_SIZE_(FIFO_ADDR,1){1'b0}},1'b1};
					end
				end
				REQ_B:	begin										//..read
					if(fifo_valid)	begin						//..not empty
						fifo_head_pointer							<=	fifo_head_pointer + {{`_DIFF_SIZE_(FIFO_ADDR,1){1'b0}},1'b1};
						occupancy											<=	occupancy - {{FIFO_ADDR{1'b0}},1'b1};
					end
				end
				default:	occupancy		<=	occupancy;
			endcase
		end
	end

	/* valid reg logic */
	spi_valid_logic
		#	(
				.DEPTH	(FIFO_DEPTH)
			)
		spi_valid_logic_i0	(
				.iclk		(iclk),
				.irst		(irst),

				.ipush	(fifo_push),
				.ipull	(fifo_pull),

				.ovalid	(fifo_valid),
				.ofull	(fifo_full),
				.oempty	(fifo_empty)
			);

	/* assignmenst */
	assign ofifo_valid			=	fifo_valid;
	assign ofifo_full				=	fifo_full;
	assign ofifo_empty			=	fifo_empty;
	assign fifo_free				=	~fifo_full;
	assign ofifo_occupancy	=	{{`_DIFF_SIZE_(REG_WIDTH,(FIFO_ADDR+1)){1'b0}},occupancy};

 endmodule
