//-----------------------------------------------------------------------------
//
// Title       : Trace_handler
// Author      : kundan vanama <durga@pdx.edu>
//        	 vinod sake <vinosake@pdx.edu>
// Company     : PSU
//
//-----------------------------------------------------------------------------
//
// File        : Trace_handler.sv
// Generated   : 27 Feb 2017
// Last Updated: 21 Mar 2017
//-----------------------------------------------------------------------------
//
// Description : 
//		 
//		 	
//-----------------------------------------------------------------------------
import cache_pkg::*;

module Trace_handler();

logic [commandsize - 1:0] command;
logic [addresssize - 1:0] address;
logic eof = FALSE;

cache_controller cc(
	.command(command),
	.address(address),
	.eof(eof)
);

parameter trace_file;
integer file;
integer trace;

initial begin
		file = $fopen(trace_file,"r");
		while(!$feof(file)) begin
			#10 trace = $fscanf(file,"%d", command);
			if(command < 8) begin
				trace = $fscanf(file, "%h", address);
				$display("<---- TRACE_CMD: %s :: TRACE_ADDRESS: %h ---->\n",cmd_t'(command), address);
			end
			else ;
			#10 command = 'dz; address = 'dz;
			eof = FALSE;
		end
		eof = TRUE;
		$fclose(file);
	#10;
	$stop;
end
endmodule

