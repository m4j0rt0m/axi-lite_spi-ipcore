/*
 * Author:				Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:					axi_spi_ctrl.v
 * Description:		AXI4-Lite SPI Full Controller
 * Organizations:	BSC; CIC-IPN
 */
module axi_spi_ctrl
#	(
		parameter	FREQ_CLK				=	50000000,
		parameter	FREQ_SPI				=	2500000,
		parameter	DATA_WIDTH			=	8,
		parameter	REG_WIDTH				=	32,
		parameter	FIFO_DEPTH			=	64,
		parameter	FIFO_ADDR				=	6,
		parameter	SR_RX_EMPTY_BIT	=	0,
		parameter	SR_RX_FULL_BIT	=	1,
		parameter	SR_TX_EMPTY_BIT	=	2,
		parameter	SR_TX_FULL_BIT	=	3,
		parameter	SR_MODF_BIT			=	4,
		parameter SR_SMOD_SEL_BIT	=	5
	)
(/*AUTOARG*/
   // Outputs
   ostatus, otx_ack, otx_occupancy, orx_data, orx_resp, orx_occupancy,
   spi_clk, spi_cs_n, spi_mosi, db_probes,
   // Inputs
   iclk, irst, islave_select, icontrol_lsb, icontrol_rx_fifo_reset,
   icontrol_tx_fifo_reset, icontrol_cpha, icontrol_cpol,
   icontrol_master, icontrol_spi_enable, itx_req, itx_data, irx_req,
   irx_ack, spi_miso
   );

	/* flow ctrl */
	input												iclk;
	input												irst;

	/* ctrl */
	input												islave_select;
	input												icontrol_lsb;
	input												icontrol_rx_fifo_reset;
	input												icontrol_tx_fifo_reset;
	input 											icontrol_cpha;						//..temporary not used
	input												icontrol_cpol;						//..temporary not used
	input												icontrol_master;					//..temporary ignored (used only for status)
	input												icontrol_spi_enable;			//..temporary ignored

	/* status */
	output reg	[REG_WIDTH-1:0]	ostatus = 0;

	/* tx fifo */
	input												itx_req;
	input			[DATA_WIDTH-1:0]	itx_data;
	output 											otx_ack;
	output 		[REG_WIDTH-1:0]		otx_occupancy;

	/* rx fifo */
	input												irx_req;
	output 		[DATA_WIDTH-1:0]	orx_data;
	output 											orx_resp;
	input 											irx_ack;
	output 		[REG_WIDTH-1:0]		orx_occupancy;

	/* spi */
	output											spi_clk;
	output											spi_cs_n;
	output											spi_mosi;
	input												spi_miso;

	/* db */
	output 		[9:0]							db_probes;

	/* local parameters */
	localparam	READ					=	1'b1;
	localparam	WRITE					=	1'b0;

	/* status bits */
	localparam	RX_EMPTY_BIT	=	0;
	localparam	RX_FULL_BIT		=	1;
	localparam	TX_EMPTY_BIT	=	2;
	localparam	TX_FULL_BIT		=	3;
	localparam	MODF_BIT			=	4;
	localparam	SMOD_SEL_BIT	=	5;

	/* regs and wires */
	wire	[DATA_WIDTH-1:0]	tx_data;
	reg											tx_req = 0;
	wire										tx_resp;
	reg 										tx_ack = 0;
	reg 	[DATA_WIDTH-1:0]	rx_data = 0;
	reg											rx_req = 0;
	wire										rx_ack;
	reg 	[DATA_WIDTH-1:0]	spi_send_data = 0;
	wire	[DATA_WIDTH-1:0]	spi_recv_data;
	reg											spi_exchange = 0;
	wire										spi_busy;
	wire										spi_ready;
	reg											tx_ready = 0;
	wire 										rx_valid;
	wire 										rx_full;
	wire 										rx_empty;
	wire 										tx_valid;
	wire 										tx_full;
	wire 										tx_empty;

	/* control state machine parameters */
	reg	[4:0]	fsm_spi_ctrl;
		localparam	StateInit			=	5'b00000;	//..initial state
		localparam	StateIdle			=	5'b00011;	//..checks if there is data to be sent in tx fifo
		localparam	StatePullData	=	5'b00101;	//..pull data from tx fifo
		localparam	StateExchange	=	5'b01001;	//..exchange a byte
		localparam	StatePushData	=	5'b10001;	//..push data into rx fifo
			initial fsm_spi_ctrl = StateInit;

	/* control state machine */
	always @ (posedge iclk)	begin
		case(fsm_spi_ctrl)
			StateInit:			begin
				spi_send_data	<=	0;
				spi_exchange	<=	0;
				tx_ready			<=	0;
				tx_req				<=	0;
				tx_ack 				<=	0;
				rx_req				<=	0;
				rx_data				<=	0;
				fsm_spi_ctrl	<=	StateIdle;
			end
			StateIdle:			begin
				if(irst)
					fsm_spi_ctrl	<=	StateInit;
				else if(tx_valid & ~tx_ack)	begin			//..check if there is available data to be sent in tx fifo
					tx_req				<=	1'b1;
					fsm_spi_ctrl	<=	StatePullData;
				end
				tx_ack 				<=	1'b0;
			end
			StatePullData:	begin
				if(irst)
					fsm_spi_ctrl	<=	StateInit;
				else if(tx_ready & ~spi_busy)	begin		//..wait until tx data is ready and spi_ctrl is free
					spi_exchange	<=	1'b1;
					fsm_spi_ctrl	<=	StateExchange;
				end
				if(tx_resp)	begin			//..got data from tx fifo
					spi_send_data	<=	tx_data;
					tx_ready			<=	1'b1;
					tx_req				<=	1'b0;
				end
			end
			StateExchange:	begin
				if(irst)
					fsm_spi_ctrl	<=	StateInit;
				else if(spi_ready)	begin		//..finished exchanging data
					rx_data				<=	spi_recv_data;
					rx_req				<=	1'b1;
					fsm_spi_ctrl	<=	StatePushData;
				end
				if(spi_busy)	begin
					tx_ready			<=	1'b0;
					spi_exchange	<=	1'b0;
				end
			end
			StatePushData:	begin
				if(irst)
					fsm_spi_ctrl	<=	StateInit;
				else if(rx_ack)	begin
					rx_req				<=	1'b0;
					tx_ack 				<=	1'b1;	//..finished exchange process
					fsm_spi_ctrl	<=	StateIdle;
				end
			end
			default: fsm_spi_ctrl <= fsm_spi_ctrl;
		endcase
	end

	/* status */
	always @ (posedge iclk)	begin
		if(irst)
			ostatus	<=	0;
		else	begin
			ostatus[SR_RX_EMPTY_BIT]	<=	rx_empty;
			ostatus[SR_RX_FULL_BIT]		<=	rx_full;
			ostatus[SR_TX_EMPTY_BIT]	<=	tx_empty;
			ostatus[SR_TX_FULL_BIT]		<=	tx_full;
			ostatus[SR_SMOD_SEL_BIT]	<=	icontrol_master;
		end
	end

	/* tx fifo */
	spi_fifo
		#	(
				.DATA_WIDTH	(DATA_WIDTH),
				.FIFO_DEPTH	(FIFO_DEPTH),
				.FIFO_ADDR	(FIFO_ADDR),
				.REG_WIDTH	(REG_WIDTH)
			)
		spi_fifo_tx	(
			/* ctrl */
			.iclk							(iclk),
			.irst							(irst | icontrol_tx_fifo_reset),
			.iallow_overwrite	(1'b0),

			/* status */
			.ofifo_occupancy	(otx_occupancy),
			.ofifo_valid 			(tx_valid),
			.ofifo_full 			(tx_full),
			.ofifo_empty 			(tx_empty),

			/* port a (WRITE port - receive from bus) */
			.ireq_a						(itx_req),
			.idata_a					(itx_data),
			.oack_a						(otx_ack),

			/* port b (READ port - send to spi slave) */
			.ireq_b						(tx_req),
			.odata_b					(tx_data),
			.oresp_b 					(tx_resp),
			.iack_b						(tx_ack)
		);

	/* rx fifo */
	spi_fifo
		#	(
				.DATA_WIDTH	(DATA_WIDTH),
				.FIFO_DEPTH	(FIFO_DEPTH),
				.FIFO_ADDR	(FIFO_ADDR),
				.REG_WIDTH	(REG_WIDTH)
			)
		spi_fifo_rx	(
			/* ctrl */
			.iclk							(iclk),
			.irst							(irst | icontrol_rx_fifo_reset),
			.iallow_overwrite	(1'b1),

			/* status */
			.ofifo_occupancy	(orx_occupancy),
			.ofifo_valid 			(rx_valid),
			.ofifo_full				(rx_full),
			.ofifo_empty			(rx_empty),

			/* port a (WRITE port - receive from spi slave) */
			.ireq_a						(rx_req),
			.idata_a					(rx_data),
			.oack_a						(rx_ack),

			/* port b (READ port - send to bus) */
			.ireq_b						(irx_req),
			.odata_b					(orx_data),
			.oresp_b					(orx_resp),
			.iack_b						(irx_ack)
		);


	/* spi ctrl */
	spi_ctrl
		#	(
				.FREQ_CLK (FREQ_CLK),	//..main clock freq
				.FREQ_SPI	(FREQ_SPI)	//..spi clock freq
			)
		spi_ctrl	(
			/* ctrl */
			.iclk							(iclk),
			.spi_select				(islave_select),
			.spi_msb_lsb_sel	(icontrol_lsb),
			.spi_exchange			(spi_exchange),
			.spi_busy					(spi_busy),
			.spi_ready				(spi_ready),

			/* data */
			.spi_send_data		(spi_send_data),
			.spi_recv_data		(spi_recv_data),

			/* spi */
			.spi_clk					(spi_clk),
			.spi_cs_n					(spi_cs_n),
			.spi_mosi					(spi_mosi),
			.spi_miso					(spi_miso)
		);

		/* db */
		//..fifo tx
		assign db_probes[0] = itx_req;
		assign db_probes[1] = otx_ack;
		assign db_probes[2] = tx_req;
		assign db_probes[3] = tx_resp;
		assign db_probes[4] = tx_ack;
		//..fifo rx
		assign db_probes[5] = rx_req;
		assign db_probes[6] = rx_ack;
		assign db_probes[7] = irx_req;
		assign db_probes[8] = orx_resp;
		assign db_probes[9] = irx_ack;

endmodule
