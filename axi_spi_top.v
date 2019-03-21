/*
 * Author:				Abraham J. Ruiz R. (https://github.com/m4j0rt0m)
 * File:					axi_spi_top.v
 * Description:		AXI4-Lite SPI Slave Module
 * Organizations:	BSC; CIC-IPN
 */
module axi_spi_top
(/*AUTOARG*/
   // Outputs
   axi_arready, axi_rid, axi_rdata, axi_rresp, axi_rvalid, axi_awready,
   axi_wready, axi_bid, axi_bresp, axi_bvalid, spi_clk, spi_cs_n, spi_mosi,
	 db_probes_top, db_probes_spi,
   // Inputs
   axi_aclk, axi_aresetn, axi_arid, axi_araddr, axi_arvalid, axi_rready,
   axi_awid, axi_awaddr, axi_awvalid, axi_wdata, axi_wstrb, axi_wvalid,
   axi_bready, spi_miso
   );

	/* includes */
	`include "axi_defines.h"
	`include "axi_spi_defines.h"
	`include "main_parameters.h"
	`include "my_defines.h"
	`include "axi_spi.h"

	/* local parameters */
	localparam  FREQ_CLK						= `_FREQ_CLK_;
	localparam  BYTE 								= `_BYTE_;
	localparam  AXI_SPI_DATA_WIDTH	= `_AXI_SPI_DATA_WIDTH_;
	localparam  AXI_SPI_ADDR_WIDTH	= `_AXI_SPI_ADDR_WIDTH_;
	localparam  AXI_SPI_FIFO_DEPTH	= `_AXI_SPI_FIFO_DEPTH_;
	localparam	AXI_SPI_FIFO_ADDR		=	`_myLOG2_(AXI_SPI_FIFO_DEPTH-1);
	localparam  AXI_SPI_BYTE_NUM 		= AXI_SPI_DATA_WIDTH/BYTE;
	localparam  AXI_SPI_LSB_WIDTH		= `_myLOG2_(AXI_SPI_BYTE_NUM-1);
	localparam  AXI_RESP_WIDTH 			= `_AXI_RESP_WIDTH_;
	localparam  AXI_ID_WIDTH 				= `_AXI_ID_WIDTH_;
	localparam  DEADLOCK_LIMIT			= 15;

	/* axi4-lite interface ports */
	input 																axi_aclk;
	input 																axi_aresetn;

	input 			[AXI_ID_WIDTH-1:0]				axi_arid;
	input 			[AXI_SPI_ADDR_WIDTH-1:0] 	axi_araddr;
	input 																axi_arvalid;
	output reg														axi_arready = 0;

	output reg 	[AXI_ID_WIDTH-1:0]				axi_rid = 0;
	output reg 	[AXI_SPI_DATA_WIDTH-1:0]	axi_rdata = 0;
	output reg 	[AXI_RESP_WIDTH-1:0] 			axi_rresp = 0;
	output reg														axi_rvalid = 0;
	input 																axi_rready;

	input 			[AXI_ID_WIDTH-1:0]				axi_awid;
	input 			[AXI_SPI_ADDR_WIDTH-1:0]	axi_awaddr;
	input 																axi_awvalid;
	output reg 														axi_awready = 0;

	input 			[AXI_SPI_DATA_WIDTH-1:0]	axi_wdata;
	input 			[AXI_SPI_BYTE_NUM-1:0]		axi_wstrb;
	input 																axi_wvalid;
	output reg 														axi_wready = 0;

	output reg 	[AXI_ID_WIDTH-1:0]				axi_bid = 0;
	output reg 	[AXI_RESP_WIDTH-1:0] 			axi_bresp = 0;
	output reg 														axi_bvalid = 0;
	input 																axi_bready;

	/* spi interface ports */
	output 																spi_clk;
	output 																spi_cs_n;
	output 																spi_mosi;
	input 																spi_miso;

	/* db */
	output 	[7:0]													db_probes_top;
	output	[9:0]													db_probes_spi;

	/* regs and wires declarations */
	reg 																	soft_reset			=	0;
	wire 																	slv_reg_rden		=	axi_arvalid;
	wire 																	slv_reg_nrden		=	~axi_arvalid & ~axi_rvalid;
	wire 																	slv_reg_wren		=	axi_awvalid & axi_wvalid;
	wire 																	slv_reg_nwren		=	~axi_wvalid & ~axi_awvalid & ~axi_bvalid;
	reg 	[`_myLOG2_(DEADLOCK_LIMIT-1):0]	wr_deadlock_cnt	=	0;	//..write deadlock counter
	reg 	[`_myLOG2_(DEADLOCK_LIMIT-1):0]	rd_deadlock_cnt	=	0;	//..read deadlock counter
	reg 																	wr_deadlock			=	0;	//..write deadlock counter enable
	reg 																	rd_deadlock			=	0;	//..read deadlock counter enable
	reg 																	wr_timeout			=	0;	//..write deadlock timeout
	reg 																	rd_timeout			=	0;	//..read deadlock timeout
	wire 	[AXI_SPI_DATA_WIDTH-1:0]				write_data;						//..write data after byte enable

	/* integers and genvars */
	genvar I;

	/* axi4-spi regs (SRR isn't available for r/w, a "0x0a" write operation triggers a soft ip-reset though) */
	reg		[AXI_SPI_DATA_WIDTH-1:0] 	spi_control_reg = 0;							//..SPI_CR
	wire	[AXI_SPI_DATA_WIDTH-1:0]	spi_status_reg;										//..SPI_SR
	reg		[DATA_WIDTH_SPI-1:0]			spi_tx_fifo_data = 0;							//..SPI_DTR.data
	reg															spi_tx_fifo_req = 0;							//..SPI_DTR.request write
	wire														spi_tx_fifo_ack;									//..SPI_DTR.acknowledge
	wire	[DATA_WIDTH_SPI-1:0]			spi_rx_fifo_data;									//..SPI_DRR.data
	reg															spi_rx_fifo_req = 0;							//..SPI_DRR.request read
	wire 														spi_rx_fifo_resp;									//..SPI_DRR.request response
	reg															spi_rx_fifo_ack = 0;							//..SPI_DRR.request acknowledge
	reg		[AXI_SPI_DATA_WIDTH-1:0]	spi_slave_select_reg = 0;					//..SPI_SSR
	wire	[AXI_SPI_DATA_WIDTH-1:0]	spi_tx_fifo_occupancy_reg;				//..SPI_TFOR
	wire	[AXI_SPI_DATA_WIDTH-1:0]	spi_rx_fifo_occupancy_reg;				//..SPI_RFOR
	reg		[AXI_SPI_DATA_WIDTH-1:0]	spi_global_interrupt_en_reg = 0;	//..SPI_GIER..(not implemented)
	reg		[AXI_SPI_DATA_WIDTH-1:0]	spi_interrupt_status_reg = 0;			//..SPI_ISR..(not implemented)
	reg		[AXI_SPI_DATA_WIDTH-1:0]	spi_interrupt_enable_reg = 0;			//..SPI_IER..(not implemented)

	/* write data */
	generate
		for(I=0; I<AXI_SPI_BYTE_NUM; I=I+1)	begin:	write_data_byte_en
				assign write_data[(I*8)+:8]	= (axi_wstrb[I]) ? axi_wdata[(I*8)+:8] : {BYTE{1'b0}};
		end
	endgenerate

	/* axi slave interface write fsm parameters */
	reg 	[4:0]	fsm_axi_wr;
		localparam 	StateInitWr			=	5'b00000;
		localparam	StateResetWr		=	5'b00011;
		localparam	StateIdleWr			=	5'b00101;
		localparam	StateControlWr	=	5'b01001;
		localparam	StateResponseWr	=	5'b10001;
			initial fsm_axi_wr = StateInitWr;

	/* axi slave interface read fsm parameters */
	reg 	[2:0]	fsm_axi_rd;
		localparam  StateInitRd			= 3'b000;
		localparam  StateIdleRd			= 3'b011;
		localparam  StateResponseRd	= 3'b101;
			initial fsm_axi_rd = StateInitRd;

	/* axi slave write interface fsm */
	always @ (posedge axi_aclk)	begin
		case(fsm_axi_wr)
			StateInitWr:	begin			//..reset axi regs
				spi_control_reg							<=	SPI_CR_Init;
				spi_slave_select_reg				<=	SPI_SSR_Init;
				spi_global_interrupt_en_reg	<=	SPI_GIER_Init;
				spi_interrupt_status_reg		<=	SPI_ISR_Init;
				spi_interrupt_enable_reg		<=	SPI_IER_Init;
				soft_reset									<=	1'b1;
				axi_awready									<=	1'b0;
				axi_wready 									<=	1'b0;
				axi_bresp										<=	2'b00;
				axi_bvalid									<=	1'b0;
				axi_bid 										<=	12'd0;
				wr_deadlock									<=	1'b0;
				fsm_axi_wr									<=	StateResetWr;
			end
			StateResetWr:	begin
				spi_control_reg							<=	SPI_CR_Init;
				spi_slave_select_reg				<=	SPI_SSR_Init;
				spi_global_interrupt_en_reg	<=	SPI_GIER_Init;
				spi_interrupt_status_reg		<=	SPI_ISR_Init;
				spi_interrupt_enable_reg		<=	SPI_IER_Init;
				soft_reset									<=	1'b0;
				axi_awready									<=	1'b0;
				axi_wready 									<=	1'b0;
				axi_bresp										<=	2'b00;
				axi_bvalid									<=	1'b0;
				axi_bid											<=	12'd0;
				wr_deadlock									<=	1'b0;
				if(axi_aresetn)
					fsm_axi_wr							<=	StateIdleWr;
			end
			StateIdleWr:	begin
				if(~axi_aresetn)
					fsm_axi_wr	<=	StateResetWr;
				else begin
					if(slv_reg_wren)	begin	//..write operation
						/* update data */
						case(axi_awaddr[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH])
							SPI_GIER[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	spi_global_interrupt_en_reg	<=	write_data;
							SPI_ISR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	spi_interrupt_status_reg		<=	spi_interrupt_status_reg ^ write_data;
							SPI_IER[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	spi_interrupt_enable_reg		<=	write_data;
							SPI_CR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:		spi_control_reg							<=	write_data;
							SPI_DTR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	begin
								spi_tx_fifo_data	<=	write_data[DATA_WIDTH_SPI-1:0];
								if(spi_tx_fifo_ack)
									spi_tx_fifo_req	<=	0;
								else
									spi_tx_fifo_req	<=	1;
							end
							SPI_SSR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	spi_slave_select_reg				<=	write_data;
							default:	begin
								spi_global_interrupt_en_reg	<=	spi_global_interrupt_en_reg;
								spi_interrupt_status_reg		<=	spi_interrupt_status_reg;
								spi_interrupt_enable_reg		<=	spi_interrupt_enable_reg;
								spi_control_reg							<=	spi_control_reg;
								spi_tx_fifo_data						<=	spi_tx_fifo_data;
								spi_tx_fifo_req							<=	spi_tx_fifo_req;
								spi_slave_select_reg				<=	spi_slave_select_reg;
							end
						endcase
						/* change state */
						case(axi_awaddr[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH])
							SPI_DTR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	begin	//..add an entry into the TX fifo if there is a free slot
								if(spi_tx_fifo_ack)	begin
									axi_awready	<=	1'b1;			//..write address transaction acknowledge
									axi_wready	<=	1'b1;			//..write data transaction acknowledge
									axi_bresp		<=	2'b00;		//..write response "OKAY"
									axi_bvalid	<=	1'b1;			//..write response valid
									axi_bid			<=	axi_awid;	//..write transaction id
									fsm_axi_wr	<=	StateResponseWr;
								end
							end
							SPI_SRR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	begin	//..check for "0x0000000a", then reset axi spi reg values
								if(write_data==SPI_SRR_Value)
									soft_reset		<=	1'b1;			//..soft reset asserted
								axi_awready		<=	1'b1;			//..write address transaction acknowledge
								axi_wready		<=	1'b1;			//..write data transaction acknowledge
								axi_bresp			<=	2'b00;		//..write response "OKAY"
								axi_bvalid		<=	1'b1;			//..write response valid
								axi_bid				<=	axi_awid;	//..write transaction id
								fsm_axi_wr		<=	StateResponseWr;
							end
							SPI_CR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:		begin	//..update control (just clear fifo reset bits)
								fsm_axi_wr		<=	StateControlWr;
							end
							default:		begin	//..assert "request_finished" signal
								axi_awready		<=	1'b1;			//..write address transaction acknowledge
								axi_wready		<=	1'b1;			//..write data transaction acknowledge
								axi_bresp			<=	2'b00;		//..write response "OKAY"
								axi_bvalid		<=	1'b1;			//..write response valid
								axi_bid				<=	axi_awid;	//..write transaction id
								fsm_axi_wr		<=	StateResponseWr;
							end
						endcase
					end
				end
				wr_deadlock		<=	1'b0;
			end
			StateControlWr:	begin
				if(~axi_aresetn)
					fsm_axi_wr			<=	StateResetWr;
				else	begin
					spi_control_reg[CR_TX_FIFO_RESET_BIT]	<=	1'b0;
					spi_control_reg[CR_RX_FIFO_RESET_BIT]	<=	1'b0;
					axi_awready														<=	1'b1;			//..write address transaction acknowledge
					axi_wready														<=	1'b1;			//..write data transaction acknowledge
					axi_bresp															<=	2'b00;		//..write response "OKAY"
					axi_bvalid														<=	1'b1;			//..write response valid
					axi_bid																<=	axi_awid;	//..write transaction id
					fsm_axi_wr														<=	StateResponseWr;
				end
				wr_deadlock		<=	1'b0;
			end
			StateResponseWr:	begin
				if(~axi_aresetn)
					fsm_axi_wr			<=	StateResetWr;
				else	begin
					if(slv_reg_nwren)	begin	//..wait for the write transaction to finish
						if(soft_reset)
							fsm_axi_wr		<=	StateResetWr;
						else
							fsm_axi_wr		<=	StateIdleWr;
						axi_bid				<=	12'd0;
					end
					else if(wr_timeout)
						fsm_axi_wr		<=	StateInitWr;
				end
				/* clear ready and valid bits for every channel */
				// if(~axi_wvalid)
				axi_wready	<=	1'b0;
				// if(~axi_awvalid)
				axi_awready	<=	1'b0;
				// if(axi_bready)
				axi_bvalid	<=	1'b0;
				/* deadlock-free */
				wr_deadlock		<=	1'b1;
			end
			default: fsm_axi_wr <= fsm_axi_wr;
		endcase
	end

	/* axi slave read interface fsm */
	always @ (posedge axi_aclk)	begin
		case(fsm_axi_rd)
			StateInitRd:	begin			//..reset axi regs
				axi_arready			<=	1'b0;
				axi_rdata				<=	{AXI_SPI_DATA_WIDTH{1'b0}};
				axi_rresp				<=	2'b00;
				axi_rvalid			<=	1'b0;
				axi_rid					<=	12'd0;
				spi_rx_fifo_ack	<=	1'b0;
				rd_deadlock			<=	1'b0;
				if(axi_aresetn)
					fsm_axi_rd			<=	StateIdleRd;
			end
			StateIdleRd:	begin
				if(~axi_aresetn)
					fsm_axi_rd	<=	StateInitRd;
				else begin
					if(slv_reg_rden)	begin	//..read operation
						case(axi_araddr[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH])
							SPI_GIER[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	axi_rdata	<=	spi_global_interrupt_en_reg;
							SPI_ISR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	axi_rdata	<=	spi_interrupt_status_reg;
							SPI_IER[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	axi_rdata	<=	spi_interrupt_enable_reg;
							SPI_CR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:		axi_rdata	<=	spi_control_reg;
							SPI_SR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:		axi_rdata	<=	spi_status_reg;
							SPI_DTR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	axi_rdata	<=	{{`_DIFF_SIZE_(AXI_SPI_DATA_WIDTH, DATA_WIDTH_SPI){1'b0}}, spi_tx_fifo_data};
							SPI_DRR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	begin
								axi_rdata	<=	{{`_DIFF_SIZE_(AXI_SPI_DATA_WIDTH, DATA_WIDTH_SPI){1'b0}}, spi_rx_fifo_data};
								if(spi_rx_fifo_resp)
									spi_rx_fifo_req	<=	0;
								else
									spi_rx_fifo_req	<=	1;
							end
							SPI_SSR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	axi_rdata	<=	spi_slave_select_reg;
							SPI_TFOR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	axi_rdata	<=	spi_tx_fifo_occupancy_reg;
							SPI_RFOR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	axi_rdata	<=	spi_rx_fifo_occupancy_reg;
							default:																					axi_rdata	<=	32'h61626364;
						endcase
						/* change state */
						case(axi_araddr[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH])
							SPI_DRR[AXI_SPI_ADDR_WIDTH-1:AXI_SPI_LSB_WIDTH]:	begin
								if(spi_rx_fifo_resp)	begin
									axi_arready			<=	1'b1;
									axi_rresp				<=	2'b00;
									axi_rvalid			<=	1'b1;
									axi_rid					<=	axi_arid;
									spi_rx_fifo_ack	<=	1'b1;
									fsm_axi_rd			<=	StateResponseRd;
								end
							end
							default:	begin
								axi_arready		<=	1'b1;
								axi_rresp			<=	2'b00;
								axi_rvalid		<=	1'b1;
								axi_rid				<=	axi_arid;
								fsm_axi_rd		<=	StateResponseRd;
							end
						endcase
					end
				end
				rd_deadlock		<=	1'b0;
			end
			StateResponseRd:	begin
				if(~axi_aresetn)
					fsm_axi_rd	<=	StateInitRd;
				else	begin
					if(slv_reg_nrden)	begin
						axi_rid			<=	12'd0;
						fsm_axi_rd	<=	StateIdleRd;
					end
					else if(rd_timeout)
						fsm_axi_rd	<=	StateInitRd;
				end
				/* clear ready and valid bits for every channel */
				// if(~axi_arvalid)
				axi_arready			<=	1'b0;
				// if(axi_rready)
				axi_rvalid			<=	1'b0;
				spi_rx_fifo_ack	<=	1'b0;
				/* deadlock-free */
				rd_deadlock			<=	1'b1;
			end
			default: fsm_axi_rd <= fsm_axi_rd;
		endcase
	end

	/* deadlock counters */
	always @ (posedge axi_aclk) begin
		/* write deadlock counter */
		if(wr_deadlock)	begin
			wr_deadlock_cnt	<=	wr_deadlock_cnt + {{`_myLOG2_(DEADLOCK_LIMIT-1){1'b0}},1'b1};
			if(wr_deadlock_cnt==DEADLOCK_LIMIT)
				wr_timeout			<=	1'b1;
		end
		else	begin
			wr_deadlock_cnt	<=	0;
			wr_timeout			<=	1'b0;
		end

		/* read deadlock counter */
		if(rd_deadlock)	begin
			rd_deadlock_cnt	<=	rd_deadlock_cnt + {{`_myLOG2_(DEADLOCK_LIMIT-1){1'b0}},1'b1};
			if(rd_deadlock_cnt==DEADLOCK_LIMIT)
				rd_timeout			<=	1'b1;
		end
		else	begin
			rd_deadlock_cnt	<=	0;
			rd_timeout			<=	1'b0;
		end
	end

	/* axi spi ctrl */
	axi_spi_ctrl
		#	(
				.FREQ_CLK					(FREQ_CLK),
				.FREQ_SPI					(FREQ_SPI),
				.DATA_WIDTH				(DATA_WIDTH_SPI),
				.REG_WIDTH				(AXI_SPI_DATA_WIDTH),
				.FIFO_DEPTH				(AXI_SPI_FIFO_DEPTH),
				.FIFO_ADDR				(AXI_SPI_FIFO_ADDR),
				.SR_RX_EMPTY_BIT	(SR_RX_EMPTY_BIT),
				.SR_RX_FULL_BIT		(SR_RX_FULL_BIT),
				.SR_TX_EMPTY_BIT	(SR_TX_EMPTY_BIT),
				.SR_TX_FULL_BIT		(SR_TX_FULL_BIT),
				.SR_MODF_BIT			(SR_MODF_BIT),
				.SR_SMOD_SEL_BIT	(SR_SMOD_SEL_BIT)
			)
		axi_spi_ctrl_i0	(
			/* flow ctrl */
			.iclk										(axi_aclk),
			.irst										(soft_reset),

			/* ctrl regs */
			.islave_select					(spi_slave_select_reg[0]),
			.icontrol_lsb						(spi_control_reg[CR_LSB_FIRST_BIT]),
			.icontrol_rx_fifo_reset	(spi_control_reg[CR_RX_FIFO_RESET_BIT]),
			.icontrol_tx_fifo_reset	(spi_control_reg[CR_TX_FIFO_RESET_BIT]),
			.icontrol_cpha					(spi_control_reg[CR_CPHA_BIT]),
			.icontrol_cpol					(spi_control_reg[CR_CPOL_BIT]),
			.icontrol_master				(spi_control_reg[CR_MASTER_BIT]),
			.icontrol_spi_enable		(spi_control_reg[CR_SPI_ENABLE_BIT]),
			.ostatus								(spi_status_reg),

			/* tx fifo */
			.itx_req								(spi_tx_fifo_req),
			.itx_data								(spi_tx_fifo_data),
			.otx_ack								(spi_tx_fifo_ack),
			.otx_occupancy					(spi_tx_fifo_occupancy_reg),

			/* rx fifo */
			.irx_req								(spi_rx_fifo_req),
			.orx_data								(spi_rx_fifo_data),
			.orx_resp								(spi_rx_fifo_resp),
			.irx_ack 								(spi_rx_fifo_ack),
			.orx_occupancy					(spi_rx_fifo_occupancy_reg),

			/* spi */
			.spi_clk								(spi_clk),
			.spi_cs_n								(spi_cs_n),
			.spi_mosi								(spi_mosi),
			.spi_miso								(spi_miso),

			/* db */
			.db_probes							(db_probes_spi)
		);

		assign	db_probes_top[0]	=	slv_reg_rden;
		assign	db_probes_top[1]	=	slv_reg_nrden;
		assign	db_probes_top[2]	=	slv_reg_wren;
		assign	db_probes_top[3]	=	slv_reg_nwren;
		assign	db_probes_top[4]	=	rd_deadlock;
		assign	db_probes_top[5]	=	wr_deadlock;
		assign	db_probes_top[6]	=	(fsm_axi_rd==StateIdleRd) ? 1'b1 : 1'b0;
		assign	db_probes_top[7]	=	(fsm_axi_wr==StateIdleWr) ? 1'b1 : 1'b0;

endmodule
