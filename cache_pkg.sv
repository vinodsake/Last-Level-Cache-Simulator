//-----------------------------------------------------------------------------
//
// Title       : Cache Pakage
// Author      : kundan vanama <durga@pdx.edu>
//        	 vinod sake <vinosake@pdx.edu>
// Company     : PSU
//
//-----------------------------------------------------------------------------
//
// File        : cache_pakage.sv
// Generated   : 1 Mar 2017
// Last Updated: 21 Mar 2017
//-----------------------------------------------------------------------------
//
// Description : All the Parameters and Macros are defined in the package
//		 
//		 	
//-----------------------------------------------------------------------------

package cache_pkg;

`define DEBUG		0
`define CACHE_CAP 	16*(2**20)*8  					// 16MB of cache, expressed in bits
`define LINE_CAP 	64*8						// 64B line capacity in cache
`define WAYS		8						// 8 Way Associativity in cache
`define ADR_BITS	32						// Address bits of cache
`define CPU_DATA_BUS	8						// CPU is a byte addressable
`define STATE_BITS	2						// MESI protocol
`define TRUE		1
`define FALSE		0


parameter debug_switch = `DEBUG;

parameter CACHE_CAP			=	`CACHE_CAP;  		// 16MB of cache, expressed in bits
parameter LINE_CAP			=	`LINE_CAP;		// 64B line capacity in cache
parameter WAYS				=	`WAYS;			// 8 Way Associativity in cache
parameter ADR_BITS			=	`ADR_BITS;		// Address bits of cache
parameter CPU_DATA_BUS			=	`CPU_DATA_BUS;		// CPU is a byte addressable
parameter STATE_BITS			=	`STATE_BITS;		// MESI protocol
parameter TRUE				=	`TRUE;
parameter FALSE				=	`FALSE;


typedef enum bit[3:0]{CPU_READ_DATA,CPU_WRITE_DATA,CPU_READ_INSTRUCTION,SNOOP_INVALIDATE,SNOOP_READ,SNOOP_WRITE,SNOOP_RWIM,no_op,CLEAR,PRINT}cmd_t;

typedef enum bit[1:0] {M,E,S,I}state_t;

parameter BYTE_OFF_BITS 		=	$clog2(LINE_CAP/CPU_DATA_BUS);
parameter SETS				= 	CACHE_CAP/(WAYS*LINE_CAP);
parameter SET_BITS			=	$clog2(SETS);
parameter TAG_BITS			=	ADR_BITS - SET_BITS - BYTE_OFF_BITS;
parameter LRU_BITS			=	$clog2(WAYS);

parameter commandsize			=	4;
parameter addresssize			=	32;

parameter CPU_READ 			= 	0;
parameter CPU_WRITE 			= 	1;

const bit [3:0]cpu_cmnds  [] 	= 	{CPU_READ, CPU_WRITE};
const bit [3:0]snp_cmnds  [] 	= 	{SNOOP_INVALIDATE, SNOOP_READ, SNOOP_WRITE, SNOOP_RWIM};
const bit [3:0]misc_cmnds [] 	=	{CLEAR,PRINT};


typedef enum bit[1:0] {NOHIT, HIT, HITM}snp_rslt_t;
typedef enum bit[2:0] {NO_OP, READ, WRITE, INVALIDATE, RWIM}bus_op_t;

endpackage : cache_pkg

