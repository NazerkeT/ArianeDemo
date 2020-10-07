/* Copyright 2018 ETH Zurich and University of Bologna.
 * Copyright and related rights are licensed under the Solderpad Hardware
 * License, Version 0.51 (the “License”); you may not use this file except in
 * compliance with the License.  You may obtain a copy of the License at
 * http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
 * or agreed to in writing, software, hardware and materials distributed under
 * this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
 * CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 *
 * File:   ariane_pkg.sv
 * Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
 * Date:   8.4.2017
 *
 * Description: Contains all the necessary defines for Ariane
 *              in one package.
 */

// this is needed to propagate the
// configuration in case Ariane is
// instantiated in OpenPiton


package ariane_pkg;

    // ---------------
    // Global Config
    // ---------------
    // This is the new user config interface system. If you need to parameterize something
    // within Ariane add a field here and assign a default value to the config. Please make
    // sure to add a propper parameter check to the `check_cfg` function.
    localparam NrMaxRules = 16;

    typedef struct packed {
      int                               RASDepth;
      int                               BTBEntries;
      int                               BHTEntries;
      // PMAs
      int unsigned                      NrNonIdempotentRules;  // Number of non idempotent rules
      logic [NrMaxRules-1:0][63:0]      NonIdempotentAddrBase; // base which needs to match
      logic [NrMaxRules-1:0][63:0]      NonIdempotentLength;   // bit mask which bits to consider when matching the rule
      int unsigned                      NrExecuteRegionRules;  // Number of regions which have execute property
      logic [NrMaxRules-1:0][63:0]      ExecuteRegionAddrBase; // base which needs to match
      logic [NrMaxRules-1:0][63:0]      ExecuteRegionLength;   // bit mask which bits to consider when matching the rule
      int unsigned                      NrCachedRegionRules;   // Number of regions which have cached property
      logic [NrMaxRules-1:0][63:0]      CachedRegionAddrBase;  // base which needs to match
      logic [NrMaxRules-1:0][63:0]      CachedRegionLength;    // bit mask which bits to consider when matching the rule
      // cache config
      bit                               Axi64BitCompliant;     // set to 1 when using in conjunction with 64bit AXI bus adapter
      bit                               SwapEndianess;         // set to 1 to swap endianess inside L1.5 openpiton adapter
      //
      logic [63:0]                      DmBaseAddress;         // offset of the debug module
    } ariane_cfg_t;

    localparam ariane_cfg_t ArianeDefaultConfig = '{
      RASDepth: 2,
      BTBEntries: 32,
      BHTEntries: 128,
      // idempotent region
      NrNonIdempotentRules: 2,
      NonIdempotentAddrBase: {64'b0, 64'b0},
      NonIdempotentLength:   {64'b0, 64'b0},
      NrExecuteRegionRules: 3,
      //                      DRAM,          Boot ROM,   Debug Module
      ExecuteRegionAddrBase: {64'h8000_0000, 64'h1_0000, 64'h0},
      ExecuteRegionLength:   {64'h40000000,  64'h10000,  64'h1000},
      // cached region
      NrCachedRegionRules:    1,
      CachedRegionAddrBase:  {64'h8000_0000},
      CachedRegionLength:    {64'h40000000},
      //  cache config
      Axi64BitCompliant:      1'b1,
      SwapEndianess:          1'b0,
      // debug
      DmBaseAddress:          64'h0
    };

    // TODO: Slowly move those parameters to the new system.
    localparam NR_SB_ENTRIES = 8; // number of scoreboard entries
    localparam TRANS_ID_BITS = $clog2(NR_SB_ENTRIES); // depending on the number of scoreboard entries we need that many bits
                                                      // to uniquely identify the entry in the scoreboard
    localparam ASID_WIDTH    = 1;
    localparam BITS_SATURATION_COUNTER = 2;
    localparam NR_COMMIT_PORTS = 2;

    localparam ENABLE_RENAME = 1'b0;

    localparam ISSUE_WIDTH = 1;
    // amount of pipeline registers inserted for load/store return path
    // this can be tuned to trade-off IPC vs. cycle time
    localparam int unsigned NR_LOAD_PIPE_REGS = 1;
    localparam int unsigned NR_STORE_PIPE_REGS = 0;

    // depth of store-buffers, this needs to be a power of two
    localparam int unsigned DEPTH_SPEC   = 4;

    // Floating-point extensions configuration
    localparam bit RVF = 1'b1; // Is F extension enabled
    localparam bit RVD = 1'b1; // Is D extension enabled
    localparam bit RVB = 1'b1; // Is B extension enabled

    typedef enum logic[3:0] {
        NONE,      // 0
        LOAD,      // 1
        STORE,     // 2
        ALU,       // 3
        CTRL_FLOW, // 4
        MULT,      // 5
        CSR,       // 6
        FPU,       // 7
        FPU_VEC    // 8
    } fu_t;

     // ----------------------
    // Arithmetic Functions
    // ----------------------
    function automatic logic [63:0] sext32 (logic [31:0] operand);
        return {{32{operand[31]}}, operand[31:0]};
    endfunction

    // ---------------
    // EX Stage
    // ---------------
    // fu_op has changed from [6:0] to [7:0] due to newly added B-Ext
    typedef enum logic [7:0] { // basic ALU op
                               ADD, SUB, ADDW, SUBW,
                               // logic operations
                               XORL, ORL, ANDL,
			       // logic bit negate
                               XORN, ORN, ANDN,
                               // shifts
                               SRA, SRL, SLL, SRLW, SLLW, SRAW,
			       // shift ones and rotation
			       SLO, SRO, ROL, ROR,
			       // min, max (un)signed
			       MIN, MAX, MINU, MAXU,
         		       // single bit instructions
			       SBCLR, SBSET, SBINV, SBEXT,
			       // general rev and orc
			       GORC, GREV,
			       // (un)shuffle
			       SHFL, UNSHFL,
			       // bit deposit and extract
			       BDEP, BEXT,
			       // pack(u,h)
			       PACK, PACKU, PACKH,
			       // bit counting
			       CLZ, CTZ, PCNT,
			       // sign extend
			       SEXTB, SEXTH,	
                               // comparisons
                               LTS, LTU, GES, GEU, EQ, NE,
                               // jumps
                               JALR, BRANCH,
                               // set lower than operations
                               SLTS, SLTU,
                               // CSR functions
                               MRET, SRET, DRET, ECALL, WFI, FENCE, FENCE_I, SFENCE_VMA, CSR_WRITE, CSR_READ, CSR_SET, CSR_CLEAR,
                               // LSU functions
                               LD, SD, LW, LWU, SW, LH, LHU, SH, LB, SB, LBU,
                               // Atomic Memory Operations
                               AMO_LRW, AMO_LRD, AMO_SCW, AMO_SCD,
                               AMO_SWAPW, AMO_ADDW, AMO_ANDW, AMO_ORW, AMO_XORW, AMO_MAXW, AMO_MAXWU, AMO_MINW, AMO_MINWU,
                               AMO_SWAPD, AMO_ADDD, AMO_ANDD, AMO_ORD, AMO_XORD, AMO_MAXD, AMO_MAXDU, AMO_MIND, AMO_MINDU,
                               // Multiplications
                               MUL, MULH, MULHU, MULHSU, MULW,
                               // Divisions
                               DIV, DIVU, DIVW, DIVUW, REM, REMU, REMW, REMUW,
                               // Floating-Point Load and Store Instructions
                               FLD, FLW, FLH, FLB, FSD, FSW, FSH, FSB,
                               // Floating-Point Computational Instructions
                               FADD, FSUB, FMUL, FDIV, FMIN_MAX, FSQRT, FMADD, FMSUB, FNMSUB, FNMADD,
                               // Floating-Point Conversion and Move Instructions
                               FCVT_F2I, FCVT_I2F, FCVT_F2F, FSGNJ, FMV_F2X, FMV_X2F,
                               // Floating-Point Compare Instructions
                               FCMP,
                               // Floating-Point Classify Instruction
                               FCLASS,
                               // Vectorial Floating-Point Instructions that don't directly map onto the scalar ones
                               VFMIN, VFMAX, VFSGNJ, VFSGNJN, VFSGNJX, VFEQ, VFNE, VFLT, VFGE, VFLE, VFGT, VFCPKAB_S, VFCPKCD_S, VFCPKAB_D, VFCPKCD_D
                             } fu_op;

    typedef struct packed {
        fu_t                      fu;
        fu_op                     operator;
        logic [63:0]              operand_a;
        logic [63:0]              operand_b;
        logic [63:0]              imm;
        logic [TRANS_ID_BITS-1:0] trans_id;
    } fu_data_t;


endpackage
