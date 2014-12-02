/*****************************************************************************

 The original version of this code comes from the book "Computer Systems: A
 Programmer's Perspective (2o. Edition)", which is copyrighted by the
 authors Randal E. Bryant and David R O'Hallaron.

 The adaptation for the Altera DE2-115 FPGA along with further extensions
 are authored by Leandro T. C. Melo with contributions by Jeferson Chaves.
 No warranties of any kind given.

******************************************************************************/

// Implementation of a Y86 processor for the Altera DE2-115 FPGA based on the
// Verilog code from the book Computer Systems: A Programmer's Perspective.
// The overall design of the processor is pretty much the same. However, the
// Fetch and Memory stages needed to be completely re-written and few other
// parts adjusted. This is because the SRAM component from the DE2-115 do not
// satisfy the requirements of the original implementation, which are too
// strong: It assumes a memory component with 8 banks, no alignment
// restrictions, possibility of simultaneous read of instructions and data,
// and the ability to entirely fetch the 48 bits of maximum instruction
// length at once.

module Proc(Mode, Clock, Status,
            SRAM_Addr, SRAM_Data, SRAM_Write, SRAM_Read, UB_N, LB_N, CE_N,
            EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI);
   output CE_N;
   output UB_N;
   output LB_N;
   output SRAM_Write;
   output SRAM_Read;
   output [31:0] SRAM_Addr; // Most significant bits will be truncated.
   inout [15:0] SRAM_Data;
   output [31:0] EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI; // For debug.

   wire SRAM_LoHi; // Whether both low and hi bytes will be read.
   wire SRAM_AccessOK;

   input [2:0] Mode;
   input Clock;
   output [2:0] Status;

   /////////////// Constants ///////////////

   // Modos:
   //  1 - Normal execution
   //  2 - Reset
   //  3,4 - Reserved
   parameter MODE_EXECUTION = 3'b0;
   parameter MODE_RESET = 3'b1;

   // Instructions
   parameter IHALT   = 4'h1;
   parameter INOP    = 4'h0;
   parameter IRRMOVL = 4'h2;
   parameter IIRMOVL = 4'h3;
   parameter IRMMOVL = 4'h4;
   parameter IMRMOVL = 4'h5;
   parameter IOPL    = 4'h6;
   parameter IJXX    = 4'h7;
   parameter ICALL   = 4'h8;
   parameter IRET    = 4'h9;
   parameter IPUSHL  = 4'hA;
   parameter IPOPL   = 4'hB;

   // ALU
   parameter ALU_ADD = 4'h0;
   parameter ALU_SUB = 4'h1;
   parameter ALU_AND = 4'h2;
   parameter ALU_XOR = 4'h3;
   parameter ALU_MUL = 4'h4;
   parameter ALU_SHL = 4'h5;
   parameter ALU_SHR = 4'h6;
   parameter ALU_OR  = 4'h7;
   parameter ALU_NOT = 4'h8;
   parameter NO_FUNC = 4'h0; // Invalid function.

   // We only use explicitly use ESP and the invalid register within the proc.
   parameter REG_ESP = 4'h4;
   parameter REG_INVALID = 4'hF;

   // Status
   parameter STATUS_BUBBLE  = 3'h0;
   parameter STATUS_OK      = 3'h1;
   parameter STATUS_HALT    = 3'h2;
   parameter STATUS_ADDRERR = 3'h3;
   parameter STATUS_INSTERR = 3'h4;


   ///////////////////////// Signals /////////////////////////////

   wire Executing = (Mode == MODE_EXECUTION);
   wire Resetting = (Mode == MODE_RESET);

   // Fetch Stage
   wire Fetch_Bubble;
   wire Fetch_Stall;
   wire Fetch_Complete; // Whether the fetch iterations are complete.
   wire [2:0] Fetch_ByteCount, FETCH_ByteCount; // Fetch iteration control.
   wire [2:0] Fetch_ValidByteCount;
   wire [2:0] Fetch_Status, FETCH_Status;
   wire [3:0] Fetch_OpCode, FETCH_OpCode;
   wire [3:0] Fetch_Func, FETCH_Func;
   wire [3:0] Fetch_Ra, FETCH_Ra;
   wire [3:0] Fetch_Rb, FETCH_Rb;
   wire [7:0] Fetch_ConstLoLo, FETCH_ConstLoLo;
   wire [7:0] Fetch_ConstLo, FETCH_ConstLo;
   wire [7:0] Fetch_ConstHi, FETCH_ConstHi;
   wire [7:0] Fetch_ConstHiHi, FETCH_ConstHiHi;
   wire [15:0] Fetch_OutMem; // All 16 bits fetched from memory.
   wire [31:0] Fetch_PC, FETCH_PC;
   wire [31:0] Fetch_SeqPC, FETCH_SeqPC; // Sequential PC.
   wire [31:0] Fetch_PredPC, FETCH_PredPC; // Predicted PC.
   wire ValidInstr;
   wire HasRegIds;
   wire HasConst;

   // Decode Stage
   wire Dec_Bubble;
   wire Dec_Stall;
   wire [2:0] DEC_Status;
   wire [31:0] DEC_PC;
   wire [3:0] DEC_OpCode;
   wire [3:0] DEC_Func;
   wire [31:0] DEC_Const;
   wire [31:0] DEC_SeqPC;
   wire [3:0] DEC_Ra;
   wire [3:0] DEC_Rb;
   wire [3:0] Dec_SrcA;
   wire [31:0] Dec_ValRa;
   wire [31:0] Dec_ValA;
   wire [3:0] Dec_SrcB;
   wire [31:0] Dec_ValRb;
   wire [31:0] Dec_ValB;
   wire [3:0] Dec_DstCalc;
   wire [3:0] Dec_DstMem;

   // Execute Stage
   wire Exec_Bubble;
   wire Exec_Stall;
   wire [2:0] EXEC_Status;
   wire [31:0] EXEC_PC;
   wire [3:0] EXEC_OpCode;
   wire [3:0] EXEC_Func;
   wire [31:0] EXEC_Const;
   wire [31:0] Exec_ValA, EXEC_ValA;
   wire [31:0] EXEC_ValB;
   wire [31:0] Exec_ValCalc;
   wire [3:0] EXEC_SrcA;
   wire [3:0] EXEC_SrcB;
   wire [3:0] Exec_DstCalc, EXEC_DstCalc;
   wire [3:0] EXEC_DstMem;
   wire [31:0] AluA;
   wire [31:0] AluB;
   wire [3:0] AluFunc;
   wire [2:0] CurrentCC;
   wire [2:0] NewCC;
   wire Exec_Condition;
   wire SetCC;

   // Memory Stage
   wire Mem_Stall;
   wire Mem_Bubble;
   wire Mem_Condition, MEM_Condition; // Branching check.
   wire [2:0] Mem_Status, MEM_Status;
   wire [31:0] Mem_PC, MEM_PC;
   wire [3:0] Mem_OpCode, MEM_OpCode;
   wire [3:0] Mem_Func, MEM_Func;
   wire [31:0] Mem_ValA, MEM_ValA;
   wire [31:0] Mem_ValCalc, MEM_ValCalc;
   wire [31:0] Mem_ValMem, MEM_ValMem;
   wire [3:0] Mem_DstMem, MEM_DstMem;
   wire [3:0] Mem_DstCalc, MEM_DstCalc;
   wire [2:0] Mem_ReadByteCount, MEM_ReadByteCount;
   wire [2:0] Mem_WriteByteCount, MEM_WriteByteCount;
   wire [2:0] Mem_UnifiedByteCount, MEM_UnifiedByteCount;
   wire [7:0] Mem_OutLoLo, MEM_OutLoLo;
   wire [7:0] Mem_OutLo, MEM_OutLo;
   wire [7:0] Mem_OutHi, MEM_OutHi;
   wire [7:0] Mem_OutHiHi, MEM_OutHiHi;
   wire [31:0] Mem_Addr, MEM_Addr; // Address to read/write.
   wire [15:0] Mem_OutMem; // All 16 bits read during each Memory iteration.
   wire [15:0] Mem_InMem;  // All 16 bits written during each Memory iteration.
   wire Mem_OutComplete; // Whether or not the complete 32-bit value is read.
   wire Mem_InComplete;  // Whether or not the complete 32-bit value is written.
   wire Mem_UnifiedComplete;
   wire Mem_Read;
   wire Mem_Write;
   wire Mem_Busy; // Flag to indicate busy Memory, which has priority over Fetch.
   wire Mem_MakeRelay; // Relay of values during memory iteration.

   // Writeback Stage
   wire Write_Bubble;
   wire Write_Stall;
   wire [2:0] WRITE_Status;
   wire [31:0] WRITE_PC;
   wire [3:0] WRITE_OpCode;
   wire [31:0] Write_ValCalc, WRITE_ValCalc;
   wire [31:0] Write_ValMem, WRITE_ValMem;
   wire [3:0] Write_DstCalc, WRITE_DstCalc;
   wire [3:0] Write_DstMem, WRITE_DstMem;

   wire Fetch_Reset = Fetch_Bubble | Resetting;
   wire Dec_Reset = Dec_Bubble | Resetting;
   wire Exec_Reset = Exec_Bubble | Resetting;
   wire Mem_Reset = Mem_Bubble | Resetting;
   wire Write_Reset = Write_Bubble | Resetting;

   // Global status
   wire [2:0] ProcStatus;

   assign Status = ProcStatus;


   /////////////////////////////////////////////////////////////////////////////
   //                           SRAM Integration
   /////////////////////////////////////////////////////////////////////////////

   // TODO: Correctly connect UB_N/LB_N with SRAM_LoHi.
   assign UB_N = 1'b0;
   assign LB_N = 1'b0;
   assign CE_N = 1'b0;

   assign SRAM_Addr = Mem_Busy ? Mem_Addr : Fetch_PC;
   assign SRAM_Data = (Mem_Busy & ~Mem_Read) ? Mem_InMem : 16'bzzzzzzzzzzzzzzzz;
   assign SRAM_Write = Mem_Busy & Mem_Write;
   assign SRAM_Read = Mem_Busy ? Mem_Read : 1'b1;
   assign SRAM_LoHi = ~SRAM_Addr[0];
   assign SRAM_AccessOK = 1'b1; // Always OK?


   /////////////////////////////////////////////////////////////////////////////
   //                                 Fetch
   /////////////////////////////////////////////////////////////////////////////

   Register #(3)  FETCH_REG_Status(FETCH_Status, Fetch_Status, ~Fetch_Stall, Fetch_Reset, 3'b0, Clock);
   Register #(32) FETCH_REG_PC(FETCH_PC, Fetch_PC, ~Fetch_Stall & Fetch_ValidByteCount == 0,
                               Fetch_Reset, 32'b0, Clock);
   Register #(32) FETCH_REG_SeqPC(FETCH_SeqPC, Fetch_SeqPC, ~Fetch_Stall, Fetch_Reset, 32'b0, Clock);
   Register #(32) FETCH_REG_PredPC(FETCH_PredPC, Fetch_PredPC, ~Fetch_Stall, Fetch_Reset, 32'b0, Clock);

   // Registers to keep the state of the Fetch. The essential idea is to preserve
   // the part of the instruction already read through auxiliary registers while
   // further access to memory are made. Once is the instruction is complete, we
   // let it go.
   Register #(3)  FETCH_REG_ByteCount(FETCH_ByteCount, Fetch_ByteCount, ~Fetch_Stall,
                                      Fetch_Complete | Fetch_Reset, 3'b0, Clock);
   Register #(4)  FETCH_REG_OpCode(FETCH_OpCode, Fetch_OpCode, ~Fetch_Stall, Fetch_Reset, INOP,
                                   Clock);
   Register #(4)  FETCH_REG_Func(FETCH_Func, Fetch_Func, ~Fetch_Stall, Fetch_Reset, NO_FUNC, Clock);
   Register #(4)  FETCH_REG_Ra(FETCH_Ra, Fetch_Ra, ~Fetch_Stall, Fetch_Reset, REG_INVALID, Clock);
   Register #(4)  FETCH_REG_Rb(FETCH_Rb, Fetch_Rb, ~Fetch_Stall, Fetch_Reset, REG_INVALID, Clock);
   Register #(8)  FETCH_REG_ConstLoLo(FETCH_ConstLoLo, Fetch_ConstLoLo, ~Fetch_Stall, Fetch_Reset,
                                      8'b0, Clock);
   Register #(8)  FETCH_REG_ConstLo(FETCH_ConstLo, Fetch_ConstLo, ~Fetch_Stall, Fetch_Reset, 8'b0,
                                    Clock);
   Register #(8)  FETCH_REG_ConstHi(FETCH_ConstHi, Fetch_ConstHi, ~Fetch_Stall, Fetch_Reset, 8'b0,
                                    Clock);
   Register #(8)  FETCH_REG_ConstHiHi(FETCH_ConstHiHi, Fetch_ConstHiHi, ~Fetch_Stall, Fetch_Reset,
                                      8'b0, Clock);

   assign Fetch_OutMem = ~Mem_Busy ? SRAM_Data : 16'bzzzzzzzzzzzzzzzz;

   // OpCode extraction: Will always be in the first chunk.
   assign Fetch_OpCode = Fetch_ValidByteCount == 0 ?
                         (SRAM_LoHi ? Fetch_OutMem[15:12] : Fetch_OutMem[7:4]) : FETCH_OpCode;
   assign Fetch_Func   = Fetch_ValidByteCount == 0 ?
                         (SRAM_LoHi ? Fetch_OutMem[11:8]  : Fetch_OutMem[3:0]) : FETCH_Func;

   // Ra/Rb extraction: Maybe in the first chunk, but depends of alignment.
   assign Fetch_Ra = HasRegIds ?
                     (Fetch_ValidByteCount == 1 ? (SRAM_LoHi ? Fetch_OutMem[15:12] : Fetch_OutMem[7:4]) :
                     ((Fetch_ValidByteCount == 0 & SRAM_LoHi) ? Fetch_OutMem[7:4] : FETCH_Ra)) : FETCH_Ra;
   assign Fetch_Rb = HasRegIds ?
                     (Fetch_ValidByteCount == 1 ? (SRAM_LoHi ? Fetch_OutMem[11:8]  : Fetch_OutMem[3:0]) :
                     ((Fetch_ValidByteCount == 0 & SRAM_LoHi) ? Fetch_OutMem[3:0] : FETCH_Rb)) : FETCH_Rb;

   // Constant extraction: Things can get complex...
   assign Fetch_ConstLoLo = HasConst ?
                            (HasRegIds ?
                            (Fetch_ValidByteCount == 2 ? (SRAM_LoHi ? Fetch_OutMem[15:8] : Fetch_OutMem[7:0]) :
                            ((Fetch_ValidByteCount == 1 & SRAM_LoHi) ? Fetch_OutMem[7:0] : FETCH_ConstLoLo)) :
                            // ~HasRegIds
                            (Fetch_ValidByteCount == 1 ? (SRAM_LoHi ? Fetch_OutMem[15:8] : Fetch_OutMem[7:0]) :
                            ((Fetch_ValidByteCount == 0 & SRAM_LoHi) ? Fetch_OutMem[7:0] : FETCH_ConstLoLo))) :
                            FETCH_ConstLoLo;
   assign Fetch_ConstLo   = HasConst ?
                            (HasRegIds ?
                            (Fetch_ValidByteCount == 3 ? (SRAM_LoHi ? Fetch_OutMem[15:8] : Fetch_OutMem[7:0]) :
                            ((Fetch_ValidByteCount == 2 & SRAM_LoHi) ? Fetch_OutMem[7:0] : FETCH_ConstLo)) :
                            // ~HasRegIds
                            (Fetch_ValidByteCount == 2 ? (SRAM_LoHi ? Fetch_OutMem[15:8] : Fetch_OutMem[7:0]) :
                            ((Fetch_ValidByteCount == 1 & SRAM_LoHi) ? Fetch_OutMem[7:0] : FETCH_ConstLo))) :
                            FETCH_ConstLo;
   assign Fetch_ConstHi   = HasConst ?
                            (HasRegIds ?
                            (Fetch_ValidByteCount == 4 ? (SRAM_LoHi ? Fetch_OutMem[15:8] : Fetch_OutMem[7:0]) :
                            ((Fetch_ValidByteCount == 3 & SRAM_LoHi) ? Fetch_OutMem[7:0] : FETCH_ConstHi)) :
                            // ~HasRegIds
                            (Fetch_ValidByteCount == 3 ? (SRAM_LoHi ? Fetch_OutMem[15:8] : Fetch_OutMem[7:0]) :
                            ((Fetch_ValidByteCount == 2 & SRAM_LoHi) ? Fetch_OutMem[7:0] : FETCH_ConstHi))) :
                            FETCH_ConstHi;
   assign Fetch_ConstHiHi = HasConst ?
                            (HasRegIds ?
                            (Fetch_ValidByteCount == 5 ? (SRAM_LoHi ? Fetch_OutMem[15:8] : Fetch_OutMem[7:0]) :
                            ((Fetch_ValidByteCount == 4 & SRAM_LoHi) ? Fetch_OutMem[7:0] : FETCH_ConstHiHi)) :
                            // ~HasRegIds
                            (Fetch_ValidByteCount == 4 ? (SRAM_LoHi ? Fetch_OutMem[15:8] : Fetch_OutMem[7:0]) :
                            ((Fetch_ValidByteCount == 3 & SRAM_LoHi) ? Fetch_OutMem[7:0] : FETCH_ConstHiHi))) :
                            FETCH_ConstHiHi;

   // Increment read byte count approprietly.
   assign Fetch_ByteCount = Fetch_Stall ? Fetch_ValidByteCount :
                            ((Fetch_ValidByteCount == 0 & SRAM_LoHi & ~HasRegIds & ~HasConst) ?
                                Fetch_ValidByteCount + 3'h1 :
                            (Fetch_ValidByteCount == 1 & SRAM_LoHi & ~HasConst) ?
                                Fetch_ValidByteCount + 3'h1 :
                            (Fetch_ValidByteCount == 4 & SRAM_LoHi & ~HasRegIds) ?
                                Fetch_ValidByteCount + 3'h1 :
                            (Fetch_ValidByteCount == 5 & SRAM_LoHi) ? Fetch_ValidByteCount + 3'h1 :
                            (~SRAM_LoHi) ? Fetch_ValidByteCount + 3'h1 : Fetch_ValidByteCount + 3'h2);

   // Track whether the instruction fetching is complete.
   assign Fetch_Complete = (Fetch_OpCode == INOP | Fetch_OpCode == IHALT) ? Fetch_ByteCount == 3'b1 :
                           (Fetch_OpCode == IRRMOVL) ? Fetch_ByteCount == 3'h2 :
                           (Fetch_OpCode == IIRMOVL |
                            Fetch_OpCode == IRMMOVL |
                            Fetch_OpCode == IMRMOVL ) ? Fetch_ByteCount == 3'h6 :
                           (Fetch_OpCode == IOPL) ? Fetch_ByteCount == 3'h2 :
                           (Fetch_OpCode == IJXX | Fetch_OpCode == ICALL) ? Fetch_ByteCount == 3'h5 :
                           (Fetch_OpCode == IRET) ? Fetch_ByteCount == 3'h1 :
                           (Fetch_OpCode == IPUSHL | Fetch_OpCode == IPOPL) ? Fetch_ByteCount == 3'h2 :
                           1'b0;

   // We cannot simply rely on byte counting for the instructions, since we
   // need an "artificial" reset upon a Jump or Ret.
   assign Fetch_ValidByteCount = ((MEM_OpCode == IJXX ) & ~MEM_Condition) |
                                 WRITE_OpCode == IRET ? 0 : FETCH_ByteCount;

   // PC computation is critical, we not only need to remember about jumping
   // but also consider the instructions are not read at once.
   assign Fetch_PC = ((MEM_OpCode == IJXX ) & ~MEM_Condition) ? MEM_ValA :
                     (WRITE_OpCode == IRET) ? WRITE_ValMem :
                     (Fetch_ValidByteCount == 0) ? FETCH_PredPC :
                     FETCH_PC + Fetch_ValidByteCount;

   assign ValidInstr = Fetch_OpCode == INOP |
                       Fetch_OpCode == IHALT |
                       Fetch_OpCode == IRRMOVL |
                       Fetch_OpCode == IIRMOVL |
                       Fetch_OpCode == IRMMOVL |
                       Fetch_OpCode == IMRMOVL |
                       Fetch_OpCode == IOPL |
                       Fetch_OpCode == IJXX |
                       Fetch_OpCode == ICALL |
                       Fetch_OpCode == IRET |
                       Fetch_OpCode == IPUSHL |
                       Fetch_OpCode == IPOPL;

   assign HasRegIds = Fetch_OpCode == IRRMOVL |
                      Fetch_OpCode == IOPL |
                      Fetch_OpCode == IPUSHL |
                      Fetch_OpCode == IPOPL |
                      Fetch_OpCode == IIRMOVL |
                      Fetch_OpCode == IRMMOVL |
                      Fetch_OpCode == IMRMOVL;

   assign HasConst = Fetch_OpCode == IIRMOVL |
                     Fetch_OpCode == IRMMOVL |
                     Fetch_OpCode == IMRMOVL |
                     Fetch_OpCode == IJXX |
                     Fetch_OpCode == ICALL;

   assign Fetch_Status = Fetch_Complete ?
                         (~SRAM_AccessOK ? STATUS_ADDRERR :
                         ~ValidInstr ? STATUS_INSTERR :
                         (Fetch_OpCode == IHALT) ? STATUS_HALT : STATUS_OK) :
                         FETCH_Status;

   assign Fetch_PredPC = ((Fetch_OpCode == IJXX | Fetch_OpCode == ICALL)  ?
                          {Fetch_ConstHiHi, Fetch_ConstHi, Fetch_ConstLo, Fetch_ConstLoLo} :
                          Fetch_SeqPC);

   assign Fetch_SeqPC = (Fetch_ValidByteCount == 0) ?
                        (Fetch_PC + 1 + HasRegIds + 4 * HasConst) : FETCH_SeqPC;


   /////////////////////////////////////////////////////////////////////////////
   //                                Decode
   /////////////////////////////////////////////////////////////////////////////

   ARF regFile(Write_DstCalc, Write_ValCalc,
               Write_DstMem, Write_ValMem,
               Dec_SrcA, Dec_ValRa, Dec_SrcB, Dec_ValRb,
               Resetting, Clock,
               EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI);

   Register #(3)  DEC_REG_Status(DEC_Status, Fetch_Status, ~Dec_Stall, Dec_Reset, STATUS_BUBBLE,
                                 Clock);
   Register #(32) DEC_REG_PC(DEC_PC, Fetch_PC, ~Dec_Stall, Dec_Reset, 0, Clock);
   Register #(32) DEc_REG_SeqPC(DEC_SeqPC, Fetch_SeqPC, ~Dec_Stall, Dec_Reset, 0, Clock);
   Register #(4)  DEC_REG_OpCode(DEC_OpCode, Fetch_OpCode, ~Dec_Stall, Dec_Reset, INOP, Clock);
   Register #(4)  DEC_REG_Func(DEC_Func, Fetch_Func, ~Dec_Stall, Dec_Reset, NO_FUNC, Clock);
   Register #(4)  DEC_REG_Ra(DEC_Ra, Fetch_Ra, ~Dec_Stall, Dec_Reset, REG_INVALID, Clock);
   Register #(4)  DEC_REG_Rb(DEC_Rb, Fetch_Rb, ~Dec_Stall, Dec_Reset, REG_INVALID, Clock);
   Register #(32) DEC_REG_Const(DEC_Const,
                                {Fetch_ConstHiHi, Fetch_ConstHi, Fetch_ConstLo, Fetch_ConstLoLo},
                                ~Dec_Stall, Dec_Reset, 0, Clock);

   assign Dec_SrcA = (DEC_OpCode == IRRMOVL |
                      DEC_OpCode == IRMMOVL |
                      DEC_OpCode == IOPL |
                      DEC_OpCode == IPUSHL) ? DEC_Ra :
                     (DEC_OpCode == IPOPL |
                      DEC_OpCode == IRET) ? REG_ESP : REG_INVALID;

   assign Dec_SrcB = (DEC_OpCode == IRMMOVL |
                      DEC_OpCode == IMRMOVL |
                      DEC_OpCode == IOPL) ? DEC_Rb :
                     (DEC_OpCode == IPUSHL |
                      DEC_OpCode == IPOPL |
                      DEC_OpCode == ICALL |
                      DEC_OpCode == IRET) ? REG_ESP : REG_INVALID;

   assign Dec_DstCalc = (DEC_OpCode == IRRMOVL |
                         DEC_OpCode == IIRMOVL |
                         DEC_OpCode == IOPL) ? DEC_Rb :
                        (DEC_OpCode == IPUSHL |
                         DEC_OpCode == IPOPL |
                         DEC_OpCode == ICALL |
                         DEC_OpCode == IRET) ? REG_ESP : REG_INVALID;

   assign Dec_DstMem = (DEC_OpCode == IMRMOVL | DEC_OpCode == IPOPL) ? DEC_Ra : REG_INVALID;

   assign Dec_ValA = (DEC_OpCode == ICALL | DEC_OpCode == IJXX ) ? DEC_SeqPC :
                     (Dec_SrcA == Exec_DstCalc) ? Exec_ValCalc :
                     (Dec_SrcA == MEM_DstMem) ? Mem_ValMem :
                     (Dec_SrcA == MEM_DstCalc) ? MEM_ValCalc :
                     (Dec_SrcA == WRITE_DstMem) ? WRITE_ValMem :
                     (Dec_SrcA == WRITE_DstCalc) ? WRITE_ValCalc :
                     Dec_ValRa;

   assign Dec_ValB = (Dec_SrcB == Exec_DstCalc) ? Exec_ValCalc :
                     (Dec_SrcB == MEM_DstMem) ? Mem_ValMem :
                     (Dec_SrcB == MEM_DstCalc) ? MEM_ValCalc :
                     (Dec_SrcB == WRITE_DstMem) ? WRITE_ValMem :
                     (Dec_SrcB == WRITE_DstCalc) ? WRITE_ValCalc :
                     Dec_ValRb;

   assign AluA = (EXEC_OpCode == IRRMOVL | EXEC_OpCode == IOPL) ? EXEC_ValA :
                 (EXEC_OpCode == IIRMOVL |
                  EXEC_OpCode == IRMMOVL |
                  EXEC_OpCode == IMRMOVL) ? EXEC_Const :
                 (EXEC_OpCode == ICALL | EXEC_OpCode == IPUSHL) ? -4 :
                 (EXEC_OpCode == IRET | EXEC_OpCode == IPOPL) ? 4 :
                 0;

   assign AluB = (EXEC_OpCode == IRMMOVL |
                  EXEC_OpCode == IMRMOVL |
                  EXEC_OpCode == IOPL |
                  EXEC_OpCode == ICALL |
                  EXEC_OpCode == IPUSHL |
                  EXEC_OpCode == IRET |
                  EXEC_OpCode == IPOPL) ? EXEC_ValB :
                 (EXEC_OpCode == IRRMOVL |
                  EXEC_OpCode == IIRMOVL) ? 0 :
                 0;


   /////////////////////////////////////////////////////////////////////////////
   //                                Execute
   /////////////////////////////////////////////////////////////////////////////

   ALU alu(AluA, AluB, AluFunc, Exec_ValCalc, NewCC);
   CC ccreg(CurrentCC, NewCC, SetCC & Executing, Resetting, Clock);
   Branch condCheck(EXEC_Func, CurrentCC, Exec_Condition);

   Register #(3)  EXEC_REG_Status(EXEC_Status, DEC_Status, ~Exec_Stall, Exec_Reset, STATUS_BUBBLE, Clock);
   Register #(32) EXEC_REG_PC(EXEC_PC, DEC_PC, ~Exec_Stall, Exec_Reset, 0, Clock);
   Register #(4)  EXEC_REG_OpCode(EXEC_OpCode, DEC_OpCode, ~Exec_Stall, Exec_Reset, INOP, Clock);
   Register #(4)  EXEC_REG_Func(EXEC_Func, DEC_Func, ~Exec_Stall, Exec_Reset, NO_FUNC, Clock);
   Register #(32) EXEC_REG_Const(EXEC_Const, DEC_Const, ~Exec_Stall, Exec_Reset, 0, Clock);
   Register #(32) EXEC_REG_ValA(EXEC_ValA, Dec_ValA, ~Exec_Stall, Exec_Reset, 0, Clock);
   Register #(32) EXEC_REG_ValB(EXEC_ValB, Dec_ValB, ~Exec_Stall, Exec_Reset, 0, Clock);
   Register #(4)  EXEC_REG_DstCalc(EXEC_DstCalc, Dec_DstCalc, ~Exec_Stall, Exec_Reset, REG_INVALID, Clock);
   Register #(4)  EXEC_REG_DstMem(EXEC_DstMem, Dec_DstMem, ~Exec_Stall, Exec_Reset, REG_INVALID, Clock);
   Register #(4)  EXEC_REG_SrcA(EXEC_SrcA, Dec_SrcA, ~Exec_Stall, Exec_Reset, REG_INVALID, Clock);
   Register #(4)  EXEC_REG_SrcB(EXEC_SrcB, Dec_SrcB, ~Exec_Stall, Exec_Reset, REG_INVALID, Clock);

   assign AluFunc = (EXEC_OpCode == IOPL) ? EXEC_Func : ALU_ADD;

   assign SetCC = (EXEC_OpCode == IOPL &
                   ~(Mem_Status == STATUS_ADDRERR |
                     Mem_Status == STATUS_INSTERR |
                     Mem_Status == STATUS_HALT) &
                   ~(WRITE_Status == STATUS_ADDRERR |
                     WRITE_Status == STATUS_INSTERR |
                     WRITE_Status == STATUS_HALT));

   assign Exec_ValA = EXEC_ValA;

   assign Exec_DstCalc = ((EXEC_OpCode == IRRMOVL) & ~Exec_Condition) ? REG_INVALID : EXEC_DstCalc;


   /////////////////////////////////////////////////////////////////////////////
   //                                Memory
   /////////////////////////////////////////////////////////////////////////////

   Register #(3)  MEM_REG_Status(MEM_Status, Mem_Status, ~Mem_Stall, Mem_Reset, STATUS_BUBBLE, Clock);
   Register #(32) MEM_REG_PC(MEM_PC, Mem_PC, ~Mem_Stall, Mem_Reset, 0, Clock);
   Register #(4)  MEM_REG_OpCode(MEM_OpCode, Mem_OpCode, ~Mem_Stall, Mem_Reset, INOP, Clock);
   Register #(4)  MEM_REG_Func(MEM_Func, Mem_Func, ~Mem_Stall, Mem_Reset, NO_FUNC, Clock);
   Register #(1)  MEM_REG_Condition(MEM_Condition, Mem_Condition, ~Mem_Stall, Mem_Reset, 1'b0, Clock);
   Register #(32) MEM_REG_ValCalc(MEM_ValCalc, Mem_ValCalc, ~Mem_Stall, Mem_Reset, 0, Clock);
   Register #(32) MEM_REG_ValA(MEM_ValA, Mem_ValA, ~Mem_Stall, Mem_Reset, 0, Clock);
   Register #(4)  MEM_REG_DstCalc(MEM_DstCalc, Mem_DstCalc, ~Mem_Stall, Mem_Reset, REG_INVALID, Clock);
   Register #(4)  MEM_REG_DstMem(MEM_DstMem, Mem_DstMem, ~Mem_Stall, Mem_Reset, REG_INVALID, Clock);

   // Like in Fetch stage we need to keep the state of the Memory stage through
   // auxiliary registers while the remaining data is read/written.
   Register #(3)  MEM_REG_ReadByteCount(MEM_ReadByteCount, Mem_ReadByteCount, ~Mem_Stall, Mem_OutComplete | Mem_Reset, 3'b0, Clock);
   Register #(3)  MEM_REG_WriteByteCount(MEM_WriteByteCount, Mem_WriteByteCount, ~Mem_Stall, Mem_InComplete | Mem_Reset, 3'b0, Clock);
   Register #(3)  MEM_REG_UnifiedByteCount(MEM_UnifiedByteCount, Mem_UnifiedByteCount, ~Mem_Stall, Mem_UnifiedComplete | Mem_Reset, 3'b0, Clock);
   Register #(32) MEM_REG_Addr(MEM_Addr, Mem_Addr, ~Mem_Stall & MEM_UnifiedByteCount == 0, Mem_Reset, 0, Clock);
   Register #(8)  MEM_REG_DataLoLo(MEM_OutLoLo, Mem_OutLoLo, ~Mem_Stall, Mem_Reset, 8'b0, Clock);
   Register #(8)  MEM_REG_DataLo(MEM_OutLo, Mem_OutLo, ~Mem_Stall, Mem_Reset, 8'b0, Clock);
   Register #(8)  MEM_REG_DataHi(MEM_OutHi, Mem_OutHi, ~Mem_Stall, Mem_Reset, 8'b0, Clock);
   Register #(8)  MEM_REG_DataHiHi(MEM_OutHiHi, Mem_OutHiHi, ~Mem_Stall, Mem_Reset, 8'b0, Clock);
   Register #(32) MEM_REG_ValMem(MEM_ValMem, Mem_ValMem, ~Mem_Stall, Mem_Reset, 0, Clock);

   // Relay for the second Memory iteration.
   assign Mem_MakeRelay = Mem_UnifiedByteCount == 2 | MEM_UnifiedByteCount == 3;
   assign Mem_Status = Mem_MakeRelay ? MEM_Status : EXEC_Status;
   assign Mem_PC = Mem_MakeRelay ? MEM_PC : EXEC_PC;
   assign Mem_OpCode = Mem_MakeRelay ? MEM_OpCode : EXEC_OpCode;
   assign Mem_Func = Mem_MakeRelay ? MEM_Func : EXEC_Func;
   assign Mem_Condition = Mem_MakeRelay ? MEM_Condition : Exec_Condition;
   assign Mem_ValCalc = Mem_MakeRelay ? MEM_ValCalc : Exec_ValCalc;
   assign Mem_ValA = Mem_MakeRelay ? MEM_ValA : Exec_ValA;
   assign Mem_DstCalc = Mem_MakeRelay ? MEM_DstCalc : Exec_DstCalc;
   assign Mem_DstMem = Mem_MakeRelay ? MEM_DstMem : EXEC_DstMem;

   assign Mem_Addr = (MEM_UnifiedByteCount == 0) ?
                     ((MEM_OpCode == IRMMOVL |
                       MEM_OpCode == IPUSHL |
                       MEM_OpCode == ICALL |
                       MEM_OpCode == IMRMOVL) ? MEM_ValCalc :
                      (MEM_OpCode == IPOPL |
                       MEM_OpCode == IRET) ? MEM_ValA :
                      0) :
                      MEM_Addr + MEM_UnifiedByteCount;

   assign Mem_Read  = (MEM_OpCode == IMRMOVL | MEM_OpCode == IPOPL | MEM_OpCode == IRET);
   assign Mem_Write = (MEM_OpCode == IRMMOVL | MEM_OpCode == IPUSHL | MEM_OpCode == ICALL);
   assign Mem_Busy = Mem_Read | Mem_Write;

   assign Mem_OutMem = Mem_Read ? SRAM_Data : 16'bzzzzzzzzzzzzzzzz;

   // Memory reading (similar to the Constant reading) by 1 byte chunks.
   assign Mem_OutLoLo = MEM_ReadByteCount == 0 ?
                        (SRAM_LoHi ? Mem_OutMem[15:8] : Mem_OutMem[7:0]) : MEM_OutLoLo;
   assign Mem_OutLo   = MEM_ReadByteCount == 1 ? (SRAM_LoHi ? Mem_OutMem[15:8] : Mem_OutMem[7:0]) :
                        (MEM_ReadByteCount == 0 & SRAM_LoHi) ? Mem_OutMem[7:0] : MEM_OutLo;
   assign Mem_OutHi   = MEM_ReadByteCount == 2 ? (SRAM_LoHi ? Mem_OutMem[15:8] : Mem_OutMem[7:0]) :
                        (MEM_ReadByteCount == 1 & SRAM_LoHi) ? Mem_OutMem[7:0] : MEM_OutHi;
   assign Mem_OutHiHi = MEM_ReadByteCount == 3 ? (SRAM_LoHi ? Mem_OutMem[15:8] : Mem_OutMem[7:0]) :
                        (MEM_ReadByteCount == 2 & SRAM_LoHi) ? Mem_OutMem[7:0] : MEM_OutHiHi;

   // Whole word value.
   assign Mem_ValMem = {Mem_OutHiHi, Mem_OutHi, Mem_OutLo, Mem_OutLoLo};

   // Memory writting also by chunks.
   assign Mem_InMem  = Mem_Write ?
                       (MEM_WriteByteCount == 0 & SRAM_LoHi) ? {MEM_ValA[7:0], MEM_ValA[15:8]} :
                       ((MEM_WriteByteCount == 0 & ~SRAM_LoHi) ? MEM_ValA[7:0] :
                       ((MEM_WriteByteCount == 1) ? {MEM_ValA[15:8], MEM_ValA[23:16]} :
                       ((MEM_WriteByteCount == 2) ? {MEM_ValA[23:16], MEM_ValA[31:24]} :
                       ((MEM_WriteByteCount == 3) ? MEM_ValA[31:24] : 0)))) : 0;

   // Tracking of bytes read/written.
   assign Mem_ReadByteCount  = Mem_Read ?
                               (SRAM_LoHi ? MEM_ReadByteCount + 3'h2 : MEM_ReadByteCount + 3'h1) :
                               3'h0;
   assign Mem_WriteByteCount = Mem_Write ?
                               (SRAM_LoHi ? MEM_WriteByteCount + 3'h2 : MEM_WriteByteCount + 3'h1) :
                               3'h0;
   assign Mem_UnifiedByteCount = (Mem_Read ? Mem_ReadByteCount : Mem_WriteByteCount);

   assign Mem_OutComplete = Mem_Read ? (Mem_ReadByteCount == 4) : 1;
   assign Mem_InComplete = Mem_Write ? (Mem_WriteByteCount == 4) : 1;
   assign Mem_UnifiedComplete = (Mem_Read ? Mem_OutComplete : Mem_InComplete);


   /////////////////////////////////////////////////////////////////////////////
   //                                Write Back
   /////////////////////////////////////////////////////////////////////////////

   Register #(3)  WRITE_REG_Status(WRITE_Status, Mem_Status, ~Write_Stall, Write_Reset,
                                   STATUS_BUBBLE, Clock);
   Register #(32) WRITE_REG_PC(WRITE_PC, MEM_PC, ~Write_Stall, Write_Reset, 0, Clock);
   Register #(4)  WRITE_REG_OpCode(WRITE_OpCode, MEM_OpCode, ~Write_Stall, Write_Reset, INOP, Clock);
   Register #(32) WRITE_REG_ValCalc(WRITE_ValCalc, MEM_ValCalc, ~Write_Stall, Write_Reset, 0, Clock);
   Register #(32) WRITE_REG_ValMem(WRITE_ValMem, Mem_ValMem, ~Write_Stall, Write_Reset, 0, Clock);
   Register #(4)  WRITE_REG_DstMem(WRITE_DstMem, MEM_DstMem, ~Write_Stall, Write_Reset,
                                   REG_INVALID, Clock);
   Register #(4)  WRITE_REG_DstCalc(WRITE_DstCalc, MEM_DstCalc, ~Write_Stall, Write_Reset,
                                    REG_INVALID, Clock);

   assign Write_DstCalc = WRITE_DstCalc;

   assign Write_ValCalc = WRITE_ValCalc;

   assign Write_DstMem = WRITE_DstMem;

   assign Write_ValMem = WRITE_ValMem;

   assign ProcStatus = (WRITE_Status == STATUS_BUBBLE) ? STATUS_OK : WRITE_Status;


   /////////////// Stalls e Bubbles //////////////////

   assign Fetch_Stall = DEC_OpCode == IRET |
                        EXEC_OpCode == IRET |
                        (MEM_OpCode == IRET & ~Mem_UnifiedComplete) |
                        Dec_Stall |
                        Mem_Busy;

   assign Dec_Stall = (EXEC_OpCode == IMRMOVL |
                       (MEM_OpCode == IMRMOVL & ~Mem_UnifiedComplete) |
                       EXEC_OpCode == IPOPL |
                      (MEM_OpCode == IPOPL & ~Mem_UnifiedComplete)) &
                      (EXEC_DstMem == Dec_SrcA |
                       (MEM_DstMem == Dec_SrcA & ~Mem_UnifiedComplete) |
                       EXEC_DstMem == Dec_SrcB |
                       (MEM_DstMem == Dec_SrcB & ~Mem_UnifiedComplete)) |
                       Exec_Stall;

   assign Exec_Stall = ~Mem_UnifiedComplete &
                       (MEM_OpCode == IPOPL |
                        MEM_OpCode == IPUSHL |
                        MEM_OpCode == IRMMOVL |
                        MEM_OpCode == IMRMOVL |
                        MEM_OpCode == ICALL);

   assign Mem_Stall = 0;

   assign Write_Stall = WRITE_Status == STATUS_ADDRERR |
                        WRITE_Status == STATUS_INSTERR |
                        WRITE_Status == STATUS_HALT;

   assign Fetch_Bubble = 0;

   assign Dec_Bubble = ((EXEC_OpCode == IJXX & ~Exec_Condition) |
                       (MEM_OpCode == IJXX & ~Mem_UnifiedComplete & ~Mem_Condition) |
                       (~((EXEC_OpCode == IMRMOVL |
                           (MEM_OpCode == IMRMOVL & ~Mem_UnifiedComplete) |
                           EXEC_OpCode == IPOPL |
                           (MEM_OpCode == IPOPL & ~Mem_UnifiedComplete)) &
                          (EXEC_DstMem == Dec_SrcA |
                           (MEM_DstMem == Dec_SrcA & ~Mem_UnifiedComplete) |
                           EXEC_DstMem == Dec_SrcB |
                           (MEM_DstMem == Dec_SrcB & ~Mem_UnifiedComplete))) &
                        (DEC_OpCode == IRET |
                         EXEC_OpCode == IRET |
                         MEM_OpCode == IRET)) |
                       ~Fetch_Complete) &
                       ~Dec_Stall;

   assign Exec_Bubble = ((EXEC_OpCode == IJXX & ~Exec_Condition) |
                        (MEM_OpCode == IJXX & ~Mem_UnifiedComplete & ~Mem_Condition) |
                        ((EXEC_OpCode == IMRMOVL |
                           (MEM_OpCode == IMRMOVL & ~Mem_UnifiedComplete) |
                           EXEC_OpCode == IPOPL |
                           (MEM_OpCode == IPOPL & ~Mem_UnifiedComplete)) &
                          (EXEC_DstMem == Dec_SrcA |
                           (MEM_DstMem == Dec_SrcA & ~Mem_UnifiedComplete) |
                           EXEC_DstMem == Dec_SrcB |
                           (MEM_DstMem == Dec_SrcB & ~Mem_UnifiedComplete)))) &
                        ~Exec_Stall;

   assign Mem_Bubble = ((Mem_Status == STATUS_ADDRERR |
                         Mem_Status == STATUS_INSTERR |
                         Mem_Status == STATUS_HALT) |
                        (WRITE_Status == STATUS_ADDRERR |
                         WRITE_Status == STATUS_INSTERR |
                         WRITE_Status == STATUS_HALT));

   assign Write_Bubble = Mem_Busy & ~Mem_UnifiedComplete;

endmodule
