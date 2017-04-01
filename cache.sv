//-----------------------------------------------------------------------------
//
// Title       : Cache
// Author      : kundan vanama <durga@pdx.edu>
//        	 vinod sake <vinosake@pdx.edu>
// Company     : PSU
//
//-----------------------------------------------------------------------------
//
// File        : cache.sv
// Generated   : 1 Mar 2017
// Last Updated: 21 Mar 2017
//-----------------------------------------------------------------------------
//
// Description : 8 Way Set Assosiative L3 Cache with LRU Replacement policy 
//		 and MESI Cohenrency Protocol
//		 	
//-----------------------------------------------------------------------------

import cache_pkg::*;

module cache(
	input [commandsize - 1:0]cmnd,			// Input trace command
	input [ADR_BITS-1:0]addr,			// Input trace address
	output real read,				// Output total cache reads
	output real write,				// Output total cache writes
	output real cache_hit,				// Output total cache hits
	output real cache_miss				// Output total cache misses
);	

/************************************** CACHE MEMORY *******************************************/
logic [STATE_BITS-1:0] STATE[SETS-1:0][WAYS-1:0];
logic [LRU_BITS-1:0] LRU[SETS-1:0][WAYS-1:0];	
logic [TAG_BITS-1:0] TAG[SETS-1:0][WAYS-1:0];
/***********************************************************************************************/

/************************** Internal Variables ******************************/
logic [(TAG_BITS+SET_BITS)-1:0]trace_address;
logic [(TAG_BITS+SET_BITS)-1:0]evict_address;

logic [SET_BITS-1:0]req_set; 
logic [TAG_BITS-1:0]req_tag; 

logic [STATE_BITS-1:0]hit_state;
logic tag_hit 	= 0;
logic tag_miss 	= 0;

integer hit_way;

logic [LRU_BITS-1:0]Lru_return_way;
logic [STATE_BITS-1:0]mesi_cpu_initial_state;
logic [STATE_BITS-1:0]mesi_snp_initial_state;

logic [(TAG_BITS+SET_BITS)-1:0]L2_address;

snp_rslt_t SnoopResult;

bit L2_control = FALSE;
/***********************************************************************************************/

/*************************************** Files *************************************************/
integer file;
integer print_valid_file;
/***********************************************************************************************/

assign trace_address = addr[ADR_BITS-1:BYTE_OFF_BITS];

assign req_set = addr[BYTE_OFF_BITS +: SET_BITS]; 			
assign req_tag = addr[(SET_BITS + BYTE_OFF_BITS) +: TAG_BITS];


assign hit_state = STATE[req_set][hit_way];

/************************************* Debug Variables *****************************************/								       
typedef enum bit {TAG_HIT,TAG_MISS}tag_t;
typedef enum bit {CACHE_HIT, CACHE_MISS}cache_t;
typedef enum bit {FALSE,TRUE}bin_t;

state_t mesi_fsm_prev, mesi_fsm_nxt, mesi_sn_prev, mesi_sn_nxt ;
tag_t tag_res;
cache_t cache_res;
bus_op_t bus_chk;
snp_rslt_t get_SnoopResult;
snp_rslt_t put_SnoopResult;

bit [LRU_BITS-1:0]miss_way;

bit tag_hit_res, tag_miss_res;
bit [LRU_BITS-1:0]way_hit, way_miss, way_Lru_returned;
bit [LRU_BITS-1:0]Lru_set_prev[WAYS];
bit [LRU_BITS-1:0]Lru_set_nxt[WAYS];
bit [LRU_BITS-1:0]Lru_set_snp_prev[WAYS];
bit [LRU_BITS-1:0]Lru_set_snp_nxt[WAYS];
bit [ADR_BITS-1:0]trc_addr,evct_addr;
/***********************************************************************************************/

initial begin
	clear_cache;																	// Initially clearing cache
	if(debug_switch)begin
		file = $fopen("check_output.csv","w");
		$fwrite(file,"COMMAND,INP_ADDR,");
		$fwrite(file,"TRACE_ADDRESS,TRACE_BYTE_OFFSET,TRACE_SET,TRACE_TAG,");
		$fwrite(file,"MEM_TAG_INI,MEM_TAG_FINAL,TAG_HIT,TAG_MISS,TRACE_STATE,");
		$fwrite(file,"CACHE_RESP,READ'S,WRITE'S,HIT'S,MISSES,");
		$fwrite(file,"HIT_WAY,EVICT_WAY,EVICT_ADDRESS,GET_SNP_RSLT,PUT_SNP_RSLT,BUS_OP,MESI_CUR_STATE,MESI_NXT_STATE,SNP_CUR_STATE,SNP_CUR_STATE,");
		$fwrite(file,"INI_LRU,NXT_LRU,SNP_INI_LRU, SNP_NXT_LRU");
		$fclose(file);
	end
end

/************************************************************************************************************************************************
* 					This Section controls the flow of executions based on command 						*
*							and results from each task 								*
*																		*
*	CPU COMMANDS		: check_cache --> cache_hit/cache_miss --> LRU(Replacement policy) --> MESI(Coherency protocol)			*
*																		*
*						 |--- tag_hit ----> MESI(Coherency protocol)							*
*	SNOOPING COMMANDS	: check_cache -->|												*	
*						 |--- tag_miss ---> PutSnoopResult								*
*																		*
************************************************************************************************************************************************/
always@(addr or cmnd) begin
	case(cmnd) 
		
		CPU_READ:																
		begin
				read = read + 1'b1;													// Incrementing cache reads count 
				check_cache;														
				if(tag_hit) begin
					if( STATE[req_set][hit_way] == M || STATE[req_set][hit_way] == E || STATE[req_set][hit_way] == S ) begin
						cache_hit = cache_hit + 1'b1;										
		
						if(debug_switch) cache_res = CACHE_HIT; 								// DEBUG
					end
					else if(STATE[req_set][hit_way] == I)begin
						cache_miss = cache_miss + 1'b1;										
				
						if(debug_switch) cache_res = CACHE_MISS; 								// DEBUG
					end
				end
				else if(tag_miss) begin
					cache_miss = cache_miss + 1'b1;											
					
					if(debug_switch) cache_res = CACHE_MISS; 									// DEBUG
				end		
				task_LRU;														
				task_MESI;														
		end	

		CPU_WRITE:																
		begin
				write = write + 1'b1;													// Incrementing cache reads count
				check_cache;														
				if(tag_hit) begin													
					if( STATE[req_set][hit_way] == M || STATE[req_set][hit_way] == E || STATE[req_set][hit_way] == S ) begin
						cache_hit = cache_hit + 1'b1;										
		
						if(debug_switch) cache_res = CACHE_HIT; 								// DEBUG
					end
					else if(STATE[req_set][hit_way] == I)begin
						cache_miss = cache_miss + 1'b1;										
				
						if(debug_switch) cache_res = CACHE_MISS; 								// DEBUG
					end
				end
				else if(tag_miss) begin
					cache_miss = cache_miss + 1'b1;											
					
					if(debug_switch) cache_res = CACHE_MISS; 									// DEBUG
				end
				task_LRU;														
				task_MESI;														
		end

		SNOOP_INVALIDATE:
		begin
				check_cache;
				if(tag_hit) begin
					task_MESI;
				end
				else if(tag_miss) begin
					PutSnoopResult(trace_address, NOHIT);
				end
		end	
	
		SNOOP_READ:
		begin
				check_cache;
				if(tag_hit) begin
					task_MESI;
				end
				else if(tag_miss) begin
					PutSnoopResult(trace_address, NOHIT);
				end
		end	

		SNOOP_WRITE:
		begin
				check_cache;
				if(tag_hit) begin
					task_MESI;
				end
				else if(tag_miss) begin
					PutSnoopResult(trace_address, NOHIT);
				end
		end	

		SNOOP_RWIM:
		begin
				check_cache;
				if(tag_hit) begin
					task_MESI;
				end
				else if(tag_miss) begin
					PutSnoopResult(trace_address, NOHIT);
				end
		end	

		CLEAR:
		begin
				clear_cache;														// Clear cache
		end

		PRINT :
		begin 
				print_valid;														// Print valid lines in cache
		end

		default: ;
	endcase
		
	if(debug_switch == 1)	debug_print;														// DEBUG print
end

/************************************************************************************************************************************************
* 					This Section updates LRU counters based on Tag hit and Tag miss 					*
*					   Most Recently Used - 7	     Least Recently Used - 0						*
*																		*
*	tag_hit		: Increment the LRU counters for ways which has count less than hit way LRU counter and set hit way LRU counter to zero	*
*																		*
*																		*
*	tag_miss	: Evict the way which is least recently used and increment all LRU counters						*	
*						 												*
************************************************************************************************************************************************/
task task_LRU;
	if(tag_hit)begin 							
		for(int asc_lp = 0; asc_lp < WAYS; asc_lp = asc_lp + 1)begin
			
			if(debug_switch) Lru_set_prev[asc_lp] = LRU[req_set][asc_lp];									// DEBUG							

			if(LRU[req_set][asc_lp] < LRU[req_set][hit_way])
				LRU[req_set][asc_lp] = LRU[req_set][asc_lp] + 'b1;
			
			if(debug_switch) Lru_set_nxt[asc_lp] = LRU[req_set][asc_lp]; 									// DEBUG
		end
		LRU[req_set][hit_way] = 0;
		Lru_return_way = hit_way;

		if(debug_switch) Lru_set_nxt[hit_way] = LRU[req_set][hit_way];										// DEBUG
		
	end
	else if(tag_miss)begin 							
		for(int asc_lp = 0; asc_lp < WAYS; asc_lp = asc_lp + 1)begin

			if(debug_switch) Lru_set_prev[asc_lp] = LRU[req_set][asc_lp];									// DEBUG
			
			if(LRU[req_set][asc_lp] == (WAYS - 1)) 			
				Lru_return_way = asc_lp;    			
			LRU[req_set][asc_lp]= LRU[req_set][asc_lp] + 1'b1; 	
			
			if(debug_switch) begin														// DEBUG
				Lru_set_nxt[asc_lp] = LRU[req_set][asc_lp];
				way_Lru_returned = Lru_return_way;
			end
		end	
		evict_address = {TAG[req_set][Lru_return_way],req_set};
	end
endtask : task_LRU

/************************************************************************************************************************************************
* 					This Section updates LRU counters based on any state transition to Invalid state 			*
*																		*
*		      Decrement the LRU counters for ways which has count greater than hit way LRU counter else maintain them unchanged		*
*							and set the hit way counter to Most Recently Used					*
*																		*
************************************************************************************************************************************************/
task snoop_update_LRU;
	for(int asc_lp=0; asc_lp < WAYS; asc_lp = asc_lp + 1)begin
		
		if(debug_switch) Lru_set_snp_prev[asc_lp] = LRU[req_set][asc_lp];									// DEBUG			
		
		if(LRU[req_set][asc_lp] > LRU[req_set][hit_way]) 			
			LRU[req_set][asc_lp] = LRU[req_set][asc_lp] - 1'b1;		
		
		if(debug_switch) Lru_set_snp_nxt[asc_lp] = LRU[req_set][asc_lp];									// DEBUG
	end
	LRU[req_set][hit_way] = WAYS - 1;
	if(debug_switch) Lru_set_snp_nxt[hit_way] = LRU[req_set][hit_way];

endtask : snoop_update_LRU

/************************************************************************************************************************************************
* 					This Section updates states of ways based on command and tag_hit/tag_miss 				*
*																		*
*		      						MESI COHERENCY PROTOCOL							        *
*																		*
*																		*
************************************************************************************************************************************************/
task task_MESI;

	mesi_cpu_initial_state = STATE[req_set][Lru_return_way];
	mesi_snp_initial_state = STATE[req_set][hit_way];
	
	if(debug_switch)begin																// DEBUG
		mesi_fsm_prev = state_t'(mesi_cpu_initial_state);
		mesi_sn_prev = state_t'(mesi_snp_initial_state);
	end

	if(tag_hit) begin
		if(cmnd inside {cpu_cmnds})begin: CPU_HIT_REQ
			case(mesi_cpu_initial_state)
				M : 	
				begin
						if(debug_switch) mesi_fsm_nxt = M;									// DEBUG
	
						if(cmnd == CPU_READ) begin
							STATE[req_set][Lru_return_way] = M;	
						end
						else if(cmnd == CPU_WRITE) begin
							STATE[req_set][Lru_return_way] = M;	
						end				
				end		
		
				E : 
				begin
						if(cmnd == CPU_READ) begin
							STATE[req_set][Lru_return_way] = E;
							
							if(debug_switch) mesi_fsm_nxt = E;								// DEBUG
						end
						else if(cmnd == CPU_WRITE) begin
							STATE[req_set][Lru_return_way] = M;		
							
							if(debug_switch) mesi_fsm_nxt = M;								// DEBUG			
						end
				end
	
				S :	   
				begin
						if(cmnd == CPU_READ) begin
							STATE[req_set][Lru_return_way] = S;	

							if(debug_switch) mesi_fsm_nxt = S;					
						end
						else if(cmnd == CPU_WRITE) begin
							STATE[req_set][Lru_return_way] = M;
							BusOperation(INVALIDATE, trace_address);							// Bus Operation

							if(debug_switch) mesi_fsm_nxt = M;								// DEBUG
						end
				end		
	
				I :   
				begin
						if(cmnd == CPU_READ) begin
							BusOperation(READ, trace_address);								// Bus Operation							
							if((SnoopResult == HIT) || (SnoopResult == HITM)) begin		
								STATE[req_set][Lru_return_way] = S;
								
								if(debug_switch) mesi_fsm_nxt = S;							// DEBUG						
							end
							else if(SnoopResult == NOHIT) begin
								STATE[req_set][Lru_return_way] = E;
								
								if(debug_switch) mesi_fsm_nxt = E;							// DEBUG
							end
						end
						else if(cmnd == CPU_WRITE) begin
							STATE[req_set][Lru_return_way] = M;
							BusOperation(RWIM, trace_address);								// Bus Operation

							if(debug_switch) mesi_fsm_nxt = M;								// DEBUG
						end
				end
			endcase 
		end: CPU_HIT_REQ	

	else if(cmnd inside {snp_cmnds})begin: SNOOP_HIT_REQ
			case(mesi_snp_initial_state)
				M : 
				begin
						if(cmnd == SNOOP_READ) begin
							STATE[req_set][hit_way] = S;	
							PutSnoopResult(trace_address, HITM);								// Put Snoop
							BusOperation(WRITE, trace_address);								// Bus Operation

							if(debug_switch) mesi_sn_nxt = S;								// DEBUG
						end
						else if(cmnd == SNOOP_WRITE) begin	
							//	Invalid state
						end
						else if(cmnd == SNOOP_INVALIDATE) begin	
							//	Invalid state 
						end
						else if(cmnd == SNOOP_RWIM) begin	
							STATE[req_set][hit_way] = I;
							PutSnoopResult(trace_address, HITM);								// Put Snoop
							snoop_update_LRU;										// Snoop update LRU
							BusOperation(WRITE, trace_address);								// Bus Operation
							L2_control = TRUE;										// L2 Message
							L2_address = trace_address;

							if(debug_switch) mesi_sn_nxt = I;								// DEBUG
						end
				end
			
				E : 
				begin
						if(cmnd == SNOOP_READ) begin
							STATE[req_set][hit_way] = S;
							PutSnoopResult(trace_address, HIT);								// Put Snoop

							if(debug_switch) mesi_sn_nxt = S;								// DEBUG					
						end
						else if(cmnd == SNOOP_WRITE) begin	
							//	Invalid state
						end
						else if(cmnd == SNOOP_INVALIDATE) begin	
							//	Invalid state 
						end
						else if(cmnd == SNOOP_RWIM) begin	
							STATE[req_set][hit_way] = I;
							PutSnoopResult(trace_address, HIT);								// Put Snoop
							snoop_update_LRU;										// Snoop update LRU
							L2_control = TRUE;
							L2_address = trace_address;									// L2 Message
	
							if(debug_switch) mesi_sn_nxt = I;								// DEBUG
						end
				end

				S : 
				begin
						if(cmnd == SNOOP_READ) begin
							STATE[req_set][hit_way] = S;
							PutSnoopResult(trace_address, HIT);								// Put Snoop

							if(debug_switch) mesi_sn_nxt = S;								// DEBUG
						end
						else if(cmnd == SNOOP_WRITE) begin	
							//	Invalid state
						end
						else if(cmnd == SNOOP_INVALIDATE) begin	
							STATE[req_set][hit_way] = I;
							PutSnoopResult(trace_address, HIT);								// Put Snoop
							snoop_update_LRU;										// Snoop update LRU
							L2_control = TRUE;
							L2_address = trace_address;									// L2 Message

							if(debug_switch) mesi_sn_nxt = I;								// DEBUG			
						end
						else if(cmnd == SNOOP_RWIM) begin	
							STATE[req_set][hit_way] = I;
							PutSnoopResult(trace_address, HIT);								// Put Snoop
							snoop_update_LRU;										// Snoop update LRU
							L2_control = TRUE;
							L2_address = trace_address;									// L2 Message

							if(debug_switch) mesi_sn_nxt = I;								// DEBUG
						end	
				end

				I : 
				begin
						if(cmnd == SNOOP_READ) begin
							STATE[req_set][hit_way] = I;
							PutSnoopResult(trace_address, NOHIT);								// Put Snoop

							if(debug_switch) mesi_sn_nxt = I;								// DEBUG
						end
						else if(cmnd == SNOOP_WRITE) begin	
							STATE[req_set][hit_way] = I;
							PutSnoopResult(trace_address, NOHIT);								// Put Snoop

							if(debug_switch) mesi_sn_nxt = I;								// DEBUG
						end
						else if(cmnd == SNOOP_INVALIDATE) begin	
							STATE[req_set][hit_way] = I;
							PutSnoopResult(trace_address, NOHIT);								// Put Snoop

							if(debug_switch) mesi_sn_nxt = I;								// DEBUG
						end
						else if(cmnd == SNOOP_RWIM) begin	
							STATE[req_set][hit_way] = I;
							PutSnoopResult(trace_address, NOHIT);								// Put Snoop

							if(debug_switch) mesi_sn_nxt = I;								// DEBUG
						end
				end
			endcase
		end : SNOOP_HIT_REQ
	end 

	else if(tag_miss) begin
		if(cmnd inside {cpu_cmnds})begin: CPU_MISS_REQ
			case(mesi_cpu_initial_state)
				M : 
				begin
						if(cmnd == CPU_READ) begin
							BusOperation(WRITE, evict_address);								// Bus operation
							L2_control = TRUE;
							L2_address = evict_address;									// L2 Message
							BusOperation(READ, trace_address);								// Bus operation
							if((SnoopResult == HIT) || (SnoopResult == HITM)) begin	
								STATE[req_set][Lru_return_way] = S;
								TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
								
								if(debug_switch) mesi_fsm_nxt = S;							// DEBUG
							end
							else if(SnoopResult == NOHIT) begin
								STATE[req_set][Lru_return_way] = E;
								TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
	
								if(debug_switch) mesi_fsm_nxt = E;							// DEBUG
							end
						end
						else if(cmnd == CPU_WRITE) begin
							BusOperation(WRITE, evict_address);								// Bus operation
							L2_control = TRUE;
							L2_address = evict_address;									// L2 Message
							BusOperation(RWIM, trace_address);								// Bus operation
							STATE[req_set][Lru_return_way] = M;
							TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
		
							if(debug_switch) mesi_fsm_nxt = M;	
						end				
				end			
		
				E : 
				begin
						if(cmnd == CPU_READ) begin
							BusOperation(READ, trace_address);								// Bus operation
							L2_control = TRUE;
							L2_address = evict_address;									// L2 Message
							if((SnoopResult == HIT) || (SnoopResult == HITM)) begin	
								STATE[req_set][Lru_return_way] = S;	
								TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
	
								if(debug_switch) mesi_fsm_nxt = S;	
							end
							else if(SnoopResult == NOHIT) begin
								STATE[req_set][Lru_return_way] = E;
								TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
	
								if(debug_switch) mesi_fsm_nxt = E;
							end
						end
						else if(cmnd == CPU_WRITE) begin
							BusOperation(RWIM, trace_address);								// Bus operation
							L2_control = TRUE;
							L2_address = evict_address;									// L2 Message
							STATE[req_set][Lru_return_way] = M;
							TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
	
							if(debug_switch) mesi_fsm_nxt = M;	
						end	
				end
	
				S :	   
				begin
						if(cmnd == CPU_READ) begin
							BusOperation(READ, trace_address);								// Bus operation
							L2_control = TRUE;
							L2_address = evict_address;									// L2 Message
							if((SnoopResult == HIT) || (SnoopResult == HITM)) begin
								STATE[req_set][Lru_return_way] = S;
								TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
		
								if(debug_switch) mesi_fsm_nxt = S;	
							end
							else if(SnoopResult == NOHIT) begin
								STATE[req_set][Lru_return_way] = E;
								TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
	
								if(debug_switch) mesi_fsm_nxt = E;
							end
						end
						else if(cmnd == CPU_WRITE) begin
							BusOperation(RWIM, trace_address);								// Bus operaion
							L2_control = TRUE;
							L2_address = evict_address;									// L2 Message
							STATE[req_set][Lru_return_way] = M;
							TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];	

							if(debug_switch) mesi_fsm_nxt = M;	
						end	
				end		
	
				I :   
				begin
						if(cmnd == CPU_READ) begin
							BusOperation(READ, trace_address);								// Bus operaion
							if((SnoopResult == HIT) || (SnoopResult == HITM)) begin
								STATE[req_set][Lru_return_way] = S;
								TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];

								if(debug_switch) mesi_fsm_nxt = S;
							end
							else if(SnoopResult == NOHIT) begin
								STATE[req_set][Lru_return_way] = E;
								TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];
								
								if(debug_switch) mesi_fsm_nxt = E;
							end
						end
						else if(cmnd == CPU_WRITE) begin
							BusOperation(RWIM, trace_address);								// Bus operation
							STATE[req_set][Lru_return_way] = M;
							TAG[req_set][Lru_return_way] = addr[ADR_BITS - 1: SET_BITS + BYTE_OFF_BITS];

							if(debug_switch) mesi_fsm_nxt = M;	
						end	
				end
			endcase 
		end: CPU_MISS_REQ
	end

	if(L2_control)
		 MessageToL2Cache(L2_address);														// Call MessageToL2Cache task

endtask : task_MESI


/***************************************** BUS OPERATION ***************************************/
task BusOperation(input bus_op_t bus_op, input [(TAG_BITS+SET_BITS)-1:0]Address);
	bus_chk = bus_op;
	GetSnoopResult(addr, SnoopResult);
	$display("BusOp: %s, Address: %h, TOTAL_Address: %h, Get Snoop Result: %s\n",bus_op, Address, {Address,6'b000000}, SnoopResult);
endtask :  BusOperation
/***********************************************************************************************/

/*************************************** GET SNOOP RESULT **************************************/
task GetSnoopResult(input [ADR_BITS-1:0]Address, output snp_rslt_t snp_rslt);
	bit [1:0]snoop_bits;
	assign snoop_bits = Address[1:0];
	case(snoop_bits)
			2'b01 	: snp_rslt = NOHIT;
			2'b10 	: snp_rslt = HITM;
			default : snp_rslt = HIT;
	endcase
	get_SnoopResult = snp_rslt;
endtask : GetSnoopResult
/***********************************************************************************************/

/*************************************** PUT SNOOP RESULT **************************************/
task PutSnoopResult(input [(TAG_BITS+SET_BITS)-1:0]Address, input snp_rslt_t put_snp_rslt);
	$display("Putsnoop --> Address: %h, Put Snoop Result: %s", Address, put_snp_rslt);
	put_SnoopResult = put_snp_rslt;
endtask : PutSnoopResult
/***********************************************************************************************/

/****************************************** CHECK CACHE ****************************************/
task check_cache;
	tag_hit = FALSE;
	tag_miss = FALSE;
	for(int way_cnt = 0; way_cnt < WAYS; way_cnt = way_cnt + 1'b1) begin
		if(TAG[req_set][way_cnt] == req_tag) begin
			tag_hit = TRUE;
			tag_miss = FALSE; 
			hit_way = way_cnt;

			if(debug_switch) tag_hit_res =(tag_hit);
			if(debug_switch) way_hit=hit_way;
		end
	end
	if(tag_hit == FALSE) begin
		tag_hit = FALSE;
		tag_miss = TRUE;
	
		if(debug_switch) tag_miss_res =(tag_miss);
	end
endtask : check_cache
/***********************************************************************************************/

/****************************************** CLEAR CACHE ****************************************/
task clear_cache;
	cache_hit 	= 0;
	cache_miss 	= 0;
	read 	= 0;
	write 	= 0;
	
	for(bit [SETS-1:0] set_cnt = 0; set_cnt < SETS; set_cnt = set_cnt + 1'b1) begin
			for(bit[WAYS-1:0] way_cnt = 0; way_cnt < WAYS; way_cnt = way_cnt + 1'b1) begin
				if(STATE[set_cnt][way_cnt] != I) begin
					BusOperation(WRITE,{TAG[set_cnt][way_cnt],set_cnt});
					MessageToL2Cache({TAG[set_cnt][way_cnt],set_cnt});
				end
				STATE[set_cnt][way_cnt] = I;
				LRU[set_cnt][way_cnt] = way_cnt;
				TAG[set_cnt][way_cnt] = 'b0;
			end
	end
	
endtask : clear_cache
/***********************************************************************************************/

/***************************************** PRINT VALID *****************************************/
task print_valid;
	
	print_valid_file = $fopen("valid_cache_line.csv","w");
	$fwrite(print_valid_file,"STATE,LRU,TAG,SET,WAY\n");
	for(int set_lp = 0; set_lp < SETS; set_lp = set_lp + 1'b1) begin
		for(int way_lp = 0; way_lp < WAYS; way_lp = way_lp + 1'b1) begin
			if(STATE[set_lp][way_lp] != I) begin
				$fwrite(print_valid_file,"%s,%d,%d,%h,%d\n",STATE[set_lp][way_lp], LRU[set_lp][way_lp], TAG[set_lp][way_lp], set_lp, way_lp);
			end
		end
	end

	$fclose(print_valid_file);
	
	$display("\n************ Valid lines in L3cache ************");
	$display(" MESI |  LRU  |  TAG 	|     SET    |  WAY");
	for(int set_lp = 0; set_lp < SETS; set_lp = set_lp + 1'b1) begin
		for(int way_lp = 0; way_lp < WAYS; way_lp = way_lp + 1'b1) begin
			if(STATE[set_lp][way_lp] != I) begin
				$display(" %s  	|  %d  	|  %d |  %h  | %d", state_t'(STATE[set_lp][way_lp]), LRU[set_lp][way_lp], TAG[set_lp][way_lp], set_lp, way_lp);
			end
		end
	end
	$display("********************* END **********************\n");
endtask :  print_valid
/***********************************************************************************************/

/**************************************** MESSAGE TO L2 ****************************************/
task MessageToL2Cache(input [(TAG_BITS+SET_BITS)-1:0]Address);
	$display("L2: %s %h","Invalidate",{Address,6'b000000});
	$display("L2: %s %h","Invalidate",{Address,6'b100000});
	L2_control = FALSE;
endtask : MessageToL2Cache
/***********************************************************************************************/

/**************************************** DEBUG PRINT ******************************************/
task debug_print;
	
	if(!(($isunknown(trace_address))))begin
	file = $fopen("check_output.csv","a");

	$fwrite(file,"\n%s,%h,",cmd_t'(cmnd),addr,);
	$fwrite(file,"%h,%h,%h,%h,",trace_address,trace_address[BYTE_OFF_BITS-1:0],req_set,req_tag,);
	$fwrite(file,"%h,%h,%b,%b,%s,",TAG[req_set][miss_way],TAG[req_set][Lru_return_way],tag_hit,tag_miss,state_t'(STATE[req_set][Lru_return_way]),);
	$fwrite(file,"%s,%d,%d,%d,%d,",cache_res,read,write,cache_hit,cache_miss,);
	$fwrite(file,"%d,%d,%h,%s,%s,%s,",way_hit,way_Lru_returned,evct_addr,SnoopResult,put_SnoopResult,bus_chk,);
	if(cmnd inside {cpu_cmnds})begin
	$fwrite(file,"%s,%s,",mesi_fsm_prev,mesi_fsm_nxt,);
	$fwrite(file,"x,x,");
	$fwrite(file,"%d:%d:%d:%d:%d:%d:%d:%d,",Lru_set_prev[0],Lru_set_prev[1],Lru_set_prev[2],Lru_set_prev[3],Lru_set_prev[4],Lru_set_prev[5],Lru_set_prev[6],Lru_set_prev[7],);
	$fwrite(file,"%d:%d:%d:%d:%d:%d:%d:%d,",Lru_set_nxt[0],Lru_set_nxt[1],Lru_set_nxt[2],Lru_set_nxt[3],Lru_set_nxt[4],Lru_set_nxt[5],Lru_set_nxt[6],Lru_set_nxt[7],);
	$fwrite(file,"x,x,");
	end
	else if(cmnd inside {snp_cmnds})begin
	$fwrite(file,"x,x,");
	$fwrite(file,"%s,%s,",mesi_sn_prev,mesi_sn_nxt,);
	$fwrite(file,"x,x,");
	$fwrite(file,"%d:%d:%d:%d:%d:%d:%d:%d,",Lru_set_snp_prev[0],Lru_set_snp_prev[1],Lru_set_snp_prev[2],Lru_set_snp_prev[3],Lru_set_snp_prev[4],Lru_set_snp_prev[5],Lru_set_snp_prev[6],Lru_set_snp_prev[7],);
	$fwrite(file,"%d:%d:%d:%d:%d:%d:%d:%d,",Lru_set_snp_nxt[0],Lru_set_snp_nxt[1],Lru_set_snp_nxt[2],Lru_set_snp_nxt[3],Lru_set_snp_nxt[4],Lru_set_snp_nxt[5],Lru_set_snp_nxt[6],Lru_set_snp_nxt[7],);
	end
	$fclose(file);
	end
endtask
/***********************************************************************************************/

endmodule 