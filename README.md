This is hardware developed for RISCV Bit Manipulation support to Ariane (CVA6) Core, especially for Zbb, Zbe, Zbp, Zbs subgroups during Summer 2020.
Hardware behaves well for basic test of all instructions in above mentioned groups, but not yet integrated with the Decoder. In general, approximate size after implementing RVB support is twice the size of original ALU+MULT according to Vivado synthesys. More details may come later, stay tuned :)

Zbb denotes - basic bit instructions, Zbe - extract/ deposit instructions, Zbp - bit permutation instructions, Zbs - single bit instructions.  

'new' folder contains wrapper, 'imports' folder contains include packages of 'riscv', 'ariane'. Also it contains all the source files necessary for wrapper functionality.  

I have designed bit_extension.sv and adapted core specific alu.sv, mult.sv, multiplier.sv modules for bit extension unit. multi_cycle_o and multi_cycle_result_o wires were added to alu to implement bext and bdep instructions. You can particularly refer to the last part of the alu, where major bit_extension related changes have been done. I have separated bit extension instructions to alu and a distinct module, to both use existing ALU hardware effectively and to keep complex bit extension-related structures in the neighbourhood.

Bit extract(bext) and bit deposit(bdep) instructions were one of the most complicated ones, as they require to be multicycle. That is why I have used the existing pipeline register of the multiplier unit. Each time when bext, bdep instructions come, multiplier unit redirects it to ALU, from there it reaches bit_extension.sv, then by every clock multiplier unit save the intermediate and final results. 

_______________________________________________________________________________

You may find following links useful, if you are interested with this project:

Ariane(CVA6) Core page: https://github.com/openhwgroup/cva6

RISCV-Bitmanip page   : https://github.com/riscv/riscv-bitmanip

OpenPiton Platform    : https://github.com/PrincetonUniversity/openpiton

Ibex RISC-V Core      : https://github.com/lowRISC/ibex

