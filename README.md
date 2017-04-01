# *Last-Level-Cache-Simulator*

`CURRENT STATUS : stable`

## Basic features

* A generic trace driven cache simulator of last level Cache for a new processor that can be used with up to three other processors in a shared memory configuration.
* It employs a write allocate policy and uses the MESI protocol to ensure coherence.
* The replacement policy is implemented with a true-LRU scheme.
* The simulator was configurable in terms of cache size, block size and associativity.

## Architecture

## Getting Started

Download all the project files into your local system.

### Prerequisites

`Mentor Questasim\Modelsim`

### Installing

Step by step instructions to setup the project in your local machine

* Open the directory in your local machine which contains all files of the project
* Open terminal with the same directory

### Executing

* Execute `make` command in the command line which will execute  `all_traces.txt` trace file
* For executing other trace files use - `make trace_name=<Trace file name>`

## Project Status/TODO

- [x] Compiles
- [x] Change Cache parameters during runtime
- [x] Change input Trace file during runtime
- [x] Simulated `CPU reads`
- [x] simulated `CPU writes`
- [x] Simulated `Snoop reads`
- [x] Simulated `Snoop writes`
- [x] Simulated `Snoop RWIM`
- [x] Simulated `Snoop Invalidate`

## Project Setup

This project has been developed with Mentor Questasim.

## Authors

* **Vinod Sake** - *Initial work* - [Github](https://github.com/vinodsake)
* **Kundan Vanama** 

## License

This project is licensed under the open-source license
