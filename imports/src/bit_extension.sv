// Date: 12.08.2020
// Description: Seperate bit extension module to keep ALU clean

import ariane_pkg::*;

module bit_extension (
    input  logic                     clk_i,          // Clock
    input  logic                     rst_ni,         // Asynchronous reset active low
    input  fu_data_t                 fu_data_i,
    output logic  		             multi_cycle_o,        // for bext, bdep
    output logic [63:0]              multi_cycle_result_o , // for bext, bdep
    output logic [63:0]              result_o
);

    ////////////////////////
    //  Pack instructions //
    ////////////////////////
    logic [63:0] pack_result;
    
    always_comb begin
        unique case (fu_data_i.operator) 
            PACKU   : pack_result = {fu_data_i.operand_b[63:32], fu_data_i.operand_a[63:32]};
            PACKH   : pack_result = {48'b0, fu_data_i.operand_b[7:0], fu_data_i.operand_a[7:0]};
            default : pack_result = {fu_data_i.operand_b[31:0], fu_data_i.operand_a[31:0]}; // pack case
        endcase
    end

    ///////////////////////////////
    //  Sign extend instructions //
    ///////////////////////////////
    logic [63:0] sign_ext_result;
    
    assign sign_ext_result = (fu_data_i.operator == SEXTB) ? {{56{fu_data_i.operand_a[7]}},fu_data_i.operand_a[7:0]} 
                                                           : {{48{fu_data_i.operand_a[15]}},fu_data_i.operand_a[15:0]};    

    ///////////////////////////////
    //  Permutation instructions //
    ///////////////////////////////
    
    // Generalised reverse, generalised or combined
    logic [63:0] grev_result; 
    logic        gorc_op;
    
    assign gorc_op = (fu_data_i.operator == GORC) ? 'd1 : 'd0;
    
    localparam [63:0] GREV_MASK_L [6] = '{64'h5555555555555555,
                                          64'h3333333333333333,
                                          64'h0F0F0F0F0F0F0F0F,
                                          64'h00FF00FF00FF00FF,
                                          64'h0000FFFF0000FFFF,
                                          64'h00000000FFFFFFFF};
                                          
    localparam [63:0] GREV_MASK_R [6] = '{64'hAAAAAAAAAAAAAAAA,
                                          64'hCCCCCCCCCCCCCCCC,
                                          64'hF0F0F0F0F0F0F0F0,
                                          64'hFF00FF00FF00FF00,
                                          64'hFFFF0000FFFF0000,
                                          64'hFFFFFFFF00000000};
    
    logic [63:0] shift_amt;
    assign shift_amt = fu_data_i.operand_b & 'd63;
    
    //Make sure that gorc_op is either 0 or 1, otherwise logic will fail                                      
    always_comb begin
        grev_result = fu_data_i.operand_a;
        
        for (int i = 0; i<6; i++) begin
            if (shift_amt & (2**i)) begin
                grev_result = (gorc_op ? grev_result : 64'h0)            |
                              ((grev_result & GREV_MASK_L[i]) << (2**i)) | 
                              ((grev_result & GREV_MASK_R[i]) >> (2**i));  
            end
        end
    end
    
    // Shuffle, unshuffle
    logic [63:0] shuffle_result;
    logic [63:0] shuffle_mode;
    logic        unshuffle_op;
    
    assign unshuffle_op = (fu_data_i.operator == UNSHFL) ? 'd1 : 'd0;
    
    localparam [63:0] SHFL_MASK_L [5] = '{64'h4444444444444444,
                                          64'h3030303030303030,
                                          64'h0f000f000f000f00,
                                          64'h00ff000000ff0000,
                                          64'h0000ffff00000000};
    
    localparam [63:0] SHFL_MASK_R [5] = '{64'h2222222222222222,
                                          64'h0c0c0c0c0c0c0c0c,
                                          64'h00f000f000f000f0,
                                          64'h0000ff000000ff00,
                                          64'h00000000ffff0000};
    
    logic [63:0] SHFL_MASK [5];
    
    for (genvar i = 0; i < 5; i++) begin: shfl_mask_gen
        assign SHFL_MASK[i] = ~(SHFL_MASK_L[i] | SHFL_MASK_R[i]);
    end
                                          
    localparam [63:0] SHFL_FLIP_MASK_L [4] = '{64'h2200110022001100,
                                               64'h0044000000440000,
                                               64'h4411000044110000,
                                               64'h1100000011000000};
                                               
    localparam [63:0] SHFL_FLIP_MASK_R [4] = '{64'h0088004400880044,
                                               64'h0000220000002200,
                                               64'h0000882200008822,
                                               64'h0000008800000088};
                                               
    localparam [63:00 ] SHFL_FLIP_MASK = 64'h8822441188224411;
    
    always_comb begin
        shuffle_result = fu_data_i.operand_a;
                
        //Flip stage
        if (unshuffle_op) begin
            shuffle_result = (shuffle_result & SHFL_FLIP_MASK)              |
                             ((shuffle_result << 6)  & SHFL_FLIP_MASK_L[0]) | ((shuffle_result >> 6)  & SHFL_FLIP_MASK_R[0]) |
                             ((shuffle_result << 9)  & SHFL_FLIP_MASK_L[1]) | ((shuffle_result >> 9)  & SHFL_FLIP_MASK_R[1]) |
                             ((shuffle_result << 15) & SHFL_FLIP_MASK_L[2]) | ((shuffle_result >> 15) & SHFL_FLIP_MASK_R[2]) |
                             ((shuffle_result << 21) & SHFL_FLIP_MASK_L[3]) | ((shuffle_result >> 21) & SHFL_FLIP_MASK_R[3]) ;
        end
        
        //Mode detection
        shuffle_mode = 0;
        if (shift_amt & 1)  shuffle_mode |= 16;
        if (shift_amt & 2)  shuffle_mode |= 8;
        if (shift_amt & 4)  shuffle_mode |= 4;
        if (shift_amt & 8)  shuffle_mode |= 2;
        if (shift_amt & 16) shuffle_mode |= 1;
       
        //Inner shuffle stages
        for (int i = 4; i>=0; i--) begin
            if (shuffle_mode &'d31 & (2**i)) begin
                shuffle_result = (shuffle_result & SHFL_MASK[i])               |
                                 ((shuffle_result << (2**i)) & SHFL_MASK_L[i]) | 
                                 ((shuffle_result >> (2**i)) & SHFL_MASK_R[i]); 
            end
        end
        
        //Flip stage
        if (unshuffle_op) begin
            shuffle_result = (shuffle_result & SHFL_FLIP_MASK)              |
                             ((shuffle_result << 6)  & SHFL_FLIP_MASK_L[0]) | ((shuffle_result >> 6)  & SHFL_FLIP_MASK_R[0]) |
                             ((shuffle_result << 9)  & SHFL_FLIP_MASK_L[1]) | ((shuffle_result >> 9)  & SHFL_FLIP_MASK_R[1]) |
                             ((shuffle_result << 15) & SHFL_FLIP_MASK_L[2]) | ((shuffle_result >> 15) & SHFL_FLIP_MASK_R[2]) |
                             ((shuffle_result << 21) & SHFL_FLIP_MASK_L[3]) | ((shuffle_result >> 21) & SHFL_FLIP_MASK_R[3]) ;
        end
        
    end

    //////////////////////////////////
    //  Basic bitcount instructions //
    //////////////////////////////////

    // Basic count instructions: pcnt,clz,ctz

    logic [63:0] pcnt_result;
        
    logic        ctz_op; 
    logic        clz_op; 
    
    assign ctz_op = (fu_data_i.operator == CTZ) ? 'd1 : 'd0;
    assign clz_op = (fu_data_i.operator == CLZ) ? 'd1 : 'd0;
    
    logic [63:0] cz_mask;
     
    always_comb begin
        cz_mask = clz_op ? fu_data_i.operand_a : (fu_data_i.operand_a & (-fu_data_i.operand_a));
        cz_mask |= (cz_mask >> 1);
        cz_mask |= (cz_mask >> 2);
        cz_mask |= (cz_mask >> 4);
        cz_mask |= (cz_mask >> 8);
        cz_mask |= (cz_mask >> 16);
        cz_mask |= (cz_mask >> 32);
    end 

    //////////////////////////
    //  Parallel prefix sum //
    //////////////////////////

    logic [6:0]  pps          [64]; //parallel prefix sum
    logic [6:0]  pps_temporal [64];
    logic [63:0] pps_input;
    logic [6:0]  offset;

    always_comb begin
        unique case (fu_data_i.operator) 
            CLZ, CTZ   : pps_input = ~cz_mask;
            BEXT, BDEP : pps_input = fu_data_i.operand_b;
            default    : pps_input = fu_data_i.operand_a;
        endcase
    end
    
    //Prefix counter
    always_comb begin   
        // stage 0 ==> initialization
        for (int i = 0; i <= 63; i += 1)begin
            pps[i] = {5'd0, pps_input[i]};    
        end
        // stage 1 ==> radix-3 Brent Kung Upsweep
        pps[1] = pps_input[1] + pps_input[0];
        for (int i = 3; i < 63; i += 4) begin
            pps[i]   = pps_input[i] + pps_input[i-1] + pps_input[i-2];
            pps[i+1] = pps_input[i+1] + pps_input[i] + pps_input[i-1];
            pps[i+2] = pps_input[i+2] + pps_input[i+1];
        end
        
        // stage 2-4 ==> radix 3 Kogge Stone 
        pps_temporal = pps;
        for (int i = 1;i < 4; i += 1) begin
            for (int j = 2**(2+i) - 5; j < 63;j += 4)begin
                offset = 3**(i) - 2**(i-1) + 1;
                if ($signed(j - (2*offset)) >= i) begin
                    pps_temporal[j] = pps[j] + pps[j-offset] + pps[j-2*offset];
                end else begin
                    pps_temporal[j] = pps[j] + pps[j-offset];
                end
            end
            pps = pps_temporal;
        end
        
        // stage 5 ==> radix-3 Brent Kung Downsweep
        for (int i = 5; i < 63; i += 4) begin
            pps[i] = pps[i] + pps[i-2];
        end 
        // stage 6 ==> radix-3 Brent Kung Downsweep
        for (int i = 2; i < 63; i += 4) begin
            pps[i]   = pps[i] + pps[i-1];
            pps[i+2] = pps[i+2] + pps[i-1];
        end
        pps[63] = pps[63] + pps[62];     
    end
    
    // Bitcount results for clz, ctz, pcnt
    assign pcnt_result = (ctz_op) ? ('d63 - pps[63]) : pps[63];

    ///////////////////////////////////////
    //  Bit extract/deposit instructions //
    ///////////////////////////////////////
        
    // Flag for multi cycle result of bext, bdep 
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if(~rst_ni) begin
            multi_cycle_o <= '0;
        end else if (fu_data_i.operator inside {BEXT, BDEP}) begin
            multi_cycle_o <= multi_cycle_o + '1;
        end else begin
	        multi_cycle_o <= '1;	
	    end
    end
    
    logic [6:0] pps_q [64];
    
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (~rst_ni) begin
            pps_q <= '{default:7'b0};
        end else begin
            if (fu_data_i.operator inside {BEXT, BDEP} & multi_cycle_o) 
                pps_q <= pps;
        end
    end
    
    // LROTC stages and bit mask generation    
    logic [63:0] lrotc_stages        [6];
    
    logic [63:0] bfly_control_bits   [6];
    logic [63:0] bfly_control_bits_r [6]; 
    logic [63:0] bfly_control_bits_l [6]; 
    
    logic [63:0] bdep_result;
    logic [63:0] bext_result;
    logic [63:0] result;

    //LROTC    
    function automatic logic [31:0] lrotc(input logic [6:0] k, input logic[7:0] pcnt);
        for (int i = 0; i < pcnt + 1; i++) lrotc = i == 0 ? 32'b0 : ((lrotc<<1) | {31'b0,~lrotc[k-1]}); 
    endfunction
        
    `define K(i) (64/(2**(i)))
    `define M(j,k) (j+1)*k-1
    
    for(genvar i = 0; i < 6; i++) begin : bfly_ctrl_stages
        for (genvar j = 0; j < (2**(i+1)) - 1; j += 2) begin : bfly_cntrl_bits
            assign lrotc_stages[i][`K(i + 1) * (j) +:`K(i+1)] = lrotc(`K(i+1), pps_q[`M(j,`K(i+1))]);
            assign lrotc_stages[i][(`K(i + 1) * (j) + `K(i+1)) +:`K(i+1)] = 32'hffffffff;
        end
        assign bfly_control_bits_l[i] = ~(lrotc_stages[i]);
        assign bfly_control_bits_r[i] = bfly_control_bits_l[i] << `K(i+1);
        assign bfly_control_bits[i]   = lrotc_stages[i] ^ bfly_control_bits_r[i];
    end

    //Bit deposit
    always_comb begin
        bdep_result = fu_data_i.operand_a;
        for (int i = 0; i < 6; i++) begin
            bdep_result = (bdep_result  & bfly_control_bits[i])               | 
                          ((bdep_result & bfly_control_bits_l[i]) << `K(i+1)) | 
                          ((bdep_result & bfly_control_bits_r[i]) >> `K(i+1)); 
        end
        bdep_result = bdep_result & fu_data_i.operand_b;
    end
    
    //Bit extract
    always_comb begin
        bext_result = fu_data_i.operand_a & fu_data_i.operand_b;
        for (int i = 5; i >= 0; i--) begin
            bext_result = (bext_result  & bfly_control_bits[i])               | 
                          ((bext_result & bfly_control_bits_l[i]) << `K(i+1)) | 
                          ((bext_result & bfly_control_bits_r[i]) >> `K(i+1)); 
        end
    end
    
    assign result = (fu_data_i.operator == BEXT) ? bext_result : bdep_result;
    assign multi_cycle_result_o = (multi_cycle_o) ? result : '0;
        
    // -----------
    // Result MUX
    // -----------
    always_comb begin
        result_o   = '0;

        unique case (fu_data_i.operator)	
	        // Pack bits
            PACK, PACKU, PACKH : result_o = pack_result;
            // Bit count
            PCNT, CLZ, CTZ     : result_o = pcnt_result;
            // Sign extend
            SEXTB, SEXTH       : result_o = sign_ext_result;
            // General permutations
            GREV, GORC         : result_o = grev_result;
            // Shuffle, unshuffle
            SHFL, UNSHFL        :  result_o = shuffle_result;
            default: ; // default case to suppress unique warning
        endcase
    end
endmodule
