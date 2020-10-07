This is hardware developed for RISCV Bit Manipulation support to Ariane (CVA6) Core, especially for Zbb, Zbe, Zbp, Zbs subgroups during Summer 2020.
Hardware behaves well for basic test of all instructions in above mentioned groups, but not yet integrated with Decoder. In general, approximate size after implementing RVB support is twice the size of original ALU+MULT according to Vivado synthesys. More details may come later, stay tuned :)

Zbb denotes - basic bit instructions, Zbe - extract/ deposit instructions, Zbp - bit permutation instructions, Zbs - single bit instructions.  

'new' folder contains wrapper, 'imports' folder contains include packages of 'riscv', 'ariane'. Also it contains all the source files necessary for wrapper functionality.  

_______________________________________________________________________________

You may find follwoing links useful if you interested with this project:

Ariane(CVA6) Core page: https://github.com/openhwgroup/cva6

RISCV-Bitmanip page   : https://github.com/riscv/riscv-bitmanip

OpenPiton Platform    : https://github.com/PrincetonUniversity/openpiton

Ibex RISC-V Core      : https://github.com/lowRISC/ibex

