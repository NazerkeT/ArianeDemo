This is hardware developed for RISCV Bit Manipulation support to Ariane (CVA6) Core, especially for Zbb, Zbe, Zbp, Zbs subgroups during Summer 2020.
Hardware behaves well for basic test of all instructions in above mentioned groups, but not yet integrated with Decoder. In general, approximate size after implementing RVB support is twice the size of original ALU+MULT according to Vivado synthesys. More details may come later, stay tuned :)

Zbb denotes - basic bit instructions, Zbe - extract/ deposit instructions, Zbp - bit permutation instructions, Zbs - single bit instructions.  

'new' folder contains wrapper, 'imports' folder contains include packages of 'riscv', 'ariane'. Also it contains all the source files necessary for wrapper functionality.  
