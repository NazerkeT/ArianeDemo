// Copyright 2018 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Author: Matthias Baer <baermatt@student.ethz.ch>
// Author: Igor Loi <igor.loi@unibo.it>
// Author: Andreas Traber <atraber@student.ethz.ch>
// Author: Lukas Mueller <lukasmue@student.ethz.ch>
// Author: Florian Zaruba <zaruabf@iis.ee.ethz.ch>
//
// Date: 19.03.2017
// Description: Ariane ALU based on RI5CY's ALU

import ariane_pkg::*;

module alu (
    input  logic                     clk_i,          // Clock
    input  logic                     rst_ni,         // Asynchronous reset active low
    input  fu_data_t                 fu_data_i,
    output logic         	         multi_cycle_o,             // for bext, bdep
    output logic [63:0]		         multi_cycle_result_o , // for bext, bdep
    output logic [63:0]              result_o,
    output logic                     alu_branch_res_o
);
                   
    logic [63:0] operand_a_rev;
    logic [31:0] operand_a_rev32;
    logic [64:0] operand_b_neg;
    logic [65:0] adder_result_ext_o;
    logic        less;  // handles both signed and unsigned forms
    
    // bit reverse operand_a for left shifts and bit counting
    generate
      genvar k;
      for(k = 0; k < 64; k++)
        assign operand_a_rev[k] = fu_data_i.operand_a[63-k];

      for (k = 0; k < 32; k++)
        assign operand_a_rev32[k] = fu_data_i.operand_a[31-k];
    endgenerate

    // ------
    // Adder
    // ------
    logic        adder_op_b_negate;
    logic        adder_z_flag;
    logic [64:0] adder_in_a, adder_in_b;
    logic [63:0] adder_result;

    always_comb begin
      adder_op_b_negate = 1'b0;

      unique case (fu_data_i.operator)
        // ADDER OPS
        EQ,  NE,
        SUB, SUBW,
	    ANDN, ORN, XORN: adder_op_b_negate = 1'b1;
        default: ;
      endcase
    end

    // prepare operand a
    assign adder_in_a    = {fu_data_i.operand_a, 1'b1};

    // prepare operand b
    assign operand_b_neg = {fu_data_i.operand_b, 1'b0} ^ {65{adder_op_b_negate}};
    assign adder_in_b    =  operand_b_neg ;

    // actual adder
    assign adder_result_ext_o = $unsigned(adder_in_a) + $unsigned(adder_in_b);
    assign adder_result       = adder_result_ext_o[64:1];
    assign adder_z_flag       = ~|adder_result;
    
    // get the right branch comparison result
    always_comb begin : branch_resolve
        // set comparison by default
        alu_branch_res_o      = 1'b1;
        case (fu_data_i.operator)
            EQ:       alu_branch_res_o = adder_z_flag;
            NE:       alu_branch_res_o = ~adder_z_flag;
            LTS, LTU: alu_branch_res_o = less;
            GES, GEU: alu_branch_res_o = ~less;
	        MIN,MINU: alu_branch_res_o = less;
            MAX,MAXU: alu_branch_res_o = ~less;
            default:  alu_branch_res_o = 1'b1;
        endcase
    end

    // ---------
    // Shifts
    // ---------

    // TODO: this can probably optimized significantly
    logic        shift_left;          // should we shift left
    logic        shift_arithmetic;

    logic [63:0] shift_amt;           // amount of shift, to the right
    logic [63:0] shift_op_a;          // input of the shifter, put above
    logic [31:0] shift_op_a32;        // input to the 32 bit shift operation

    logic [63:0] shift_result;
    logic [31:0] shift_result32;

    logic [64:0] shift_right_result;
    logic [32:0] shift_right_result32;

    logic [63:0] shift_left_result;
    logic [31:0] shift_left_result32;

    assign shift_amt = fu_data_i.operand_b & 'd63;

    //assign shift_left = (fu_data_i.operator == SLL) | (fu_data_i.operator == SLLW);
    always_comb begin : shift_left_resolve
       unique case (fu_data_i.operator)
           SBSET,SBCLR,SBINV, 
           SLLW,SLL,SLO,ROL     : shift_left = 1'b1;
           default              : shift_left = 1'b0;
       endcase
    end

    assign shift_arithmetic = (fu_data_i.operator == SRA) | (fu_data_i.operator == SRAW);

    // right shifts, we let the synthesizer optimize this
    logic [64:0] shift_op_a_64;
    logic [32:0] shift_op_a_32;
    
    // input of the single bit instrs
    logic [63:0] sbit_const; 
    assign sbit_const = 64'h8000000000000000;

    // choose the bit reversed or the normal input for shift operand a
    //assign shift_op_a    = shift_left ? operand_a_rev   : fu_data_i.operand_a;
    always_comb begin : shift_op_resolve
       unique case (fu_data_i.operator)
           SBSET,SBCLR, 
           SBINV	     : shift_op_a = sbit_const;
	       SLLW,
           SLL,ROL       : shift_op_a = operand_a_rev;
           SRO           : shift_op_a = ~fu_data_i.operand_a;
           SLO           : shift_op_a = ~operand_a_rev;
           default       : shift_op_a = fu_data_i.operand_a;
       endcase
    end

    assign shift_op_a32  = shift_left ? operand_a_rev32 : fu_data_i.operand_a[31:0];

    assign shift_op_a_64 = { shift_arithmetic & shift_op_a[63], shift_op_a};
    assign shift_op_a_32 = { shift_arithmetic & shift_op_a[31], shift_op_a32};

    assign shift_right_result     = $unsigned($signed(shift_op_a_64) >>> shift_amt[5:0]);

    assign shift_right_result32   = $unsigned($signed(shift_op_a_32) >>> shift_amt[4:0]);
    // bit reverse the shift_right_result for left shifts
    genvar j;
    generate
      for(j = 0; j < 64; j++)
        assign shift_left_result[j] = shift_right_result[63-j];

      for(j = 0; j < 32; j++)
        assign shift_left_result32[j] = shift_right_result32[31-j];

    endgenerate

    assign shift_result = shift_left ? shift_left_result : shift_right_result[63:0];
    assign shift_result32 = shift_left ? shift_left_result32 : shift_right_result32[31:0];

    // ------------
    // Comparisons
    // ------------

    always_comb begin
        logic sgn;
        sgn = 1'b0;

        if ((fu_data_i.operator == SLTS) ||
            (fu_data_i.operator == LTS)  ||
	    (fu_data_i.operator == MIN)  ||
            (fu_data_i.operator == MAX)  ||
            (fu_data_i.operator == GES))
            sgn = 1'b1;

        less = ($signed({sgn & fu_data_i.operand_a[63], fu_data_i.operand_a})  <  $signed({sgn & fu_data_i.operand_b[63], fu_data_i.operand_b}));
    end
    
    ///////////////////////////
    //  Bit Extension Module //
    ///////////////////////////
    
    logic [63:0] rvb_result;

    generate 

        if (RVB) begin : bit_ext_gen

            // Basic RVB instrs
    
            ////////////////
            //  Neg logic //
            ////////////////
            
            logic [63:0] neg_l_result;  
            always_comb begin
                unique case (fu_data_i.operator) 
                    ANDN    : neg_l_result = fu_data_i.operand_a & operand_b_neg[64:1];
                    ORN     : neg_l_result = fu_data_i.operand_a | operand_b_neg[64:1];
                    default : neg_l_result = fu_data_i.operand_a ^ operand_b_neg[64:1]; //xorn case
                endcase
            end
    
            ///////////////
            //  Min, max //
            ///////////////

            logic [63:0] minmax_result;
            assign minmax_result  = alu_branch_res_o ? fu_data_i.operand_a : fu_data_i.operand_b; 
    
            /////////////////
            //  Single bit //
            /////////////////

            logic [63:0] single_bit_result;
            
            always_comb begin : single_bit_resolve
                unique case (fu_data_i.operator) 
                    SBSET   : single_bit_result = fu_data_i.operand_a |  shift_left_result;
                    SBCLR   : single_bit_result = fu_data_i.operand_a & ~shift_left_result;
                    SBINV   : single_bit_result = fu_data_i.operand_a ^  shift_left_result;
                    default : single_bit_result = shift_right_result[0]; // sbext case
                endcase
            end    
		
            ///////////////
            //  Rotation //
            ///////////////
    
            logic [63:0] rotation_result;    
            logic [63:0] rot_left_half;    
            logic [63:0] rot_right_half;    
            logic [63:0] shift_amt_rev;
            
            // Additional shift structure for second half of the instruction expression
            assign shift_amt_rev  = ('d64 - shift_amt) & 'd63;
            assign rot_right_half = (shift_left ? fu_data_i.operand_a : operand_a_rev) >> shift_amt_rev;
            
            for(genvar i = 0; i < 64; i++)
            assign rot_left_half[i] = rot_right_half[63-i];
            
            always_comb begin
                unique case (fu_data_i.operator)
                    ROL     : rotation_result = shift_left_result  |  rot_right_half;
                    default : rotation_result = shift_right_result |  rot_left_half; // ror case
                endcase
            end

            //////////////////
            //  Permutation //
            //////////////////
            
            // Shift ones (left,right) 
            logic [63:0] shift_ones_result;
            
            assign shift_ones_result = (fu_data_i.operator == SLO) ? ~shift_left_result : ~shift_right_result;
    
            // Complex RVB instrs
            logic [63:0] c_rvb_result;
    
            bit_extension i_bit_extension (
                .clk_i,
                .rst_ni,         
                .fu_data_i,
                .multi_cycle_o,
                .multi_cycle_result_o,
                .result_o ( c_rvb_result )
            );
	       
	       always_comb begin
	           unique case(fu_data_i.operator)
                   // Logic Negate Operations
                   ANDN, ORN, XORN:  rvb_result = neg_l_result;
                   // Min, max 
                   MIN, MINU, MAX, MAXU : rvb_result = minmax_result;
                   // Single bit instructions
                   SBSET, SBCLR, SBINV, SBEXT: rvb_result = single_bit_result;
                   // Shift in ones
                   SLO, SRO: rvb_result = shift_ones_result;
                   // Rotation
                   ROL, ROR: rvb_result = rotation_result;
                   default : rvb_result = c_rvb_result;
               endcase    
	       end
            
	    end else begin : no_bit_ext_gen
            assign rvb_result    = '0;
            assign multi_cycle_o = '0;
            assign multi_cycle_result_o = '0;
        end

    endgenerate  
    
    // -----------
    // Result MUX
    // -----------
    always_comb begin
        result_o = rvb_result;

        unique case (fu_data_i.operator)
            // Standard Operations
            ANDL:  result_o = fu_data_i.operand_a & fu_data_i.operand_b;
            ORL:   result_o = fu_data_i.operand_a | fu_data_i.operand_b;
            XORL:  result_o = fu_data_i.operand_a ^ fu_data_i.operand_b;

            // Adder Operations
            ADD, SUB: result_o = adder_result;
            // Add word: Ignore the upper bits and sign extend to 64 bit
            ADDW, SUBW: result_o = {{32{adder_result[31]}}, adder_result[31:0]};
            // Shift Operations
            SLL,
            SRL, SRA: result_o = shift_result;
            // Shifts 32 bit
            SLLW,
            SRLW, SRAW: result_o = {{32{shift_result32[31]}}, shift_result32[31:0]};

            // Comparison Operations
            SLTS,  SLTU: result_o = {63'b0, less};
	    
            default: result_o = rvb_result; // default case to suppress unique warning
        endcase
    end
endmodule
