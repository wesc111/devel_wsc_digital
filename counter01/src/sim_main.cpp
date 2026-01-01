// testbench.cpp

// based on template from https://github.com/verilator/example-systemverilog/blob/master/sim_main.cpp

#include <verilated.h>         // Include common routines
#include "Vsat_counter_tb.h"  // Include the generated header for the testbench

// Current simulation time (64-bit unsigned)
vluint64_t main_time = 0;
double sc_time_stamp() {
    return main_time;  // Note does conversion to real, to match SystemC
}

int main(int argc, char** argv, char** env){
  VerilatedContext*    m_contextp = new VerilatedContext; // Create a new Verilated context
  Vsat_counter_tb*     top_tb     = new Vsat_counter_tb;       // <-- design changes here

  Verilated::debug(0);                  // Debug level off
  Verilated::randReset(2);              // Random initialization of registers
  Verilated::traceEverOn(true);         // Enable waveform tracing
  Verilated::commandArgs(argc, argv);  // Remember to init top level
  m_contextp->traceEverOn(true);
  
  // Simulation loop
  while (!m_contextp->gotFinish()) {
    ++main_time;
    top_tb->eval();
    m_contextp->timeInc(1);   // 1 timeunit per cycle
  }
  top_tb->final();           // Invoke final blocks

  // Remember to close the trace object to save data in the file
  delete top_tb;
  top_tb=NULL;
  return 0;
}
