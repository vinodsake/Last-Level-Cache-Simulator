
trace_name ?= all_traces.txt 

all:	compile run 

compile:
	vlib work
	vmap work work
	vlog -sv cache_pkg.sv cache.sv cache_controller.sv Trace_handler.sv
run:
	vsim -do "vsim -Gtrace_file=$(trace_name) work.Trace_handler; run -all;exit"
