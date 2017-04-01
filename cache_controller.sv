//-----------------------------------------------------------------------------
//
// Title       : cache controller
// Author      : kundan vanama <durga@pdx.edu>
//        	 vinod sake <vinosake@pdx.edu>
// Company     : PSU
//
//-----------------------------------------------------------------------------
//
// File        : cache_controller.sv
// Generated   : 28 Feb 2017
// Last Updated: 21 Mar 2017
//-----------------------------------------------------------------------------
//
// Description : Sends CPU & SNOOP commands to cache and display statistics
//		 at the end of trace file		 
//		 	
//-----------------------------------------------------------------------------
import cache_pkg::*;

module cache_controller(
	input [commandsize - 1:0]command,
	input [ADR_BITS-1:0]address,
	input eof
);

logic [commandsize - 1:0]cmnd;
logic [ADR_BITS-1:0]addr;

// Statistics variables
real read=0,write=0,cache_hit=0,cache_miss=0;
real total,prfmnc;
// Statistics file
integer statistics;

cache l3cache(
	.cmnd(cmnd),
	.addr(addr),
	.cache_hit(cache_hit),
	.cache_miss(cache_miss),
	.write(write),
	.read(read)	
);

assign total = cache_hit + cache_miss;

always @(cache_hit or cache_miss) begin
	prfmnc = cache_hit/total;
end

always @(posedge eof) begin
	$display("STATSITICS:");
	$display("\nCACHE READS|CACHE WRITES|CACHE HITS|CACHE MISSES|CACHE HIT RATIO\n");
	$display("%d	|\t%d	|\t%d	|\t%d	|\t%f%%\t",read,write,cache_hit,cache_miss, prfmnc*100);
	
	statistics = $fopen("statistics.csv","w");
	$fwrite(statistics,"\nCACHE READS,CACHE WRITES,CACHE HITS,CACHE MISSES,CACHE HIT RATIO\n");
    	$fwrite(statistics,"%d,%d,%d,%d,%f%%\n",read,write,cache_hit,cache_miss, prfmnc*100);
  	$fclose(statistics);
end

always@(command) begin
	case(command)
	
		CPU_READ_DATA : 
		begin 
						cmnd = CPU_READ;
						addr = address;
		end

		CPU_WRITE_DATA : 
		begin 
						cmnd = CPU_WRITE;
						addr = address;
		end

		CPU_READ_INSTRUCTION : 
		begin 
						cmnd = CPU_READ;
						addr = address;
		end

		SNOOP_INVALIDATE : 
		begin 
						cmnd = SNOOP_INVALIDATE;
						addr = address;
		end 

		SNOOP_READ : 
		begin 
						cmnd = SNOOP_READ;
						addr = address;
		end 

		SNOOP_WRITE : 
		begin 
						cmnd = SNOOP_WRITE;
						addr = address;
		end 

		SNOOP_RWIM : 
		begin 
						cmnd = SNOOP_RWIM;
						addr = address;
		end
 
		PRINT : 
		begin 
						cmnd = PRINT;
						addr = address;
		end
 
		default	: 
		begin 
						cmnd = command;
						addr = address;
		end 
	endcase
end
endmodule 
 