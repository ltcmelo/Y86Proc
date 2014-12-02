/*****************************************************************************

 The original version of this code comes from the book "Computer Systems: A
 Programmer's Perspective (2o. Edition)", which is copyrighted by the
 authors Randal E. Bryant and David R O'Hallaron.

 The adaptation for the Altera DE2-115 FPGA along with further extensions
 are authored by Leandro T. C. Melo with contributions by Jeferson Chaves.
 No warranties of any kind given.

******************************************************************************/

module Register(Out, In, Enable, Reset, ResetVal, Clock);
   parameter width = 32;

   output [width-1:0] Out;
   reg [width-1:0] Out;
   input [width-1:0] In;
   input Enable;
   input Reset;
   input [width-1:0] ResetVal;
   input Clock;

   always @(posedge Clock)
     begin
        if (Reset)
          Out <= ResetVal;
        else if (Enable)
          Out <= In;
     end
endmodule

// General Purpose Register
module GPR(Out, In, Enable, Reset, ResetVal, Clock);
   output [31:0] Out;
   input [31:0] In;
   input Enable;
   input Reset;
   input [31:0] ResetVal;
   input Clock;

   Register #(32) register(Out, In, Enable, Reset, ResetVal, Clock);
endmodule

// Condition Codes Register
module CC(Out, In, SetCC, Reset, Clock);
   output [2:0] Out;
   input [2:0] In;
   input SetCC;
   input Reset;
   input Clock;

   Register #(3) register(Out, In, SetCC, Reset, 3'b100, Clock);
endmodule

// Branching Register
module Branch(Func, CC, Condition);
   input [3:0] Func;
   input [2:0] CC;
   output Condition;

   wire ZeroFlag     = CC[2];
   wire SignFlag     = CC[1];
   wire OverflowFlag = CC[0];

   // Evaluated conditions
   parameter YES = 4'h0;
   parameter LEQ = 4'h1;
   parameter L   = 4'h2;
   parameter EQ  = 4'h3;
   parameter NEQ = 4'h4;
   parameter GEQ = 4'h5;
   parameter G   = 4'h6;

   assign Condition = (Func == YES) |
                      (Func == LEQ & ((SignFlag ^ OverflowFlag) | ZeroFlag)) |
                      (Func == L   &  (SignFlag ^ OverflowFlag)) |
                      (Func == EQ  & ZeroFlag) |
                      (Func == NEQ & ~ZeroFlag) |
                      (Func == GEQ &  (~SignFlag ^ OverflowFlag)) |
                      (Func == G   & ((~SignFlag ^ OverflowFlag) | ~ZeroFlag));
endmodule

// Architecture Register File
module ARF(CalcValcReg, CalcVal, MemValReg, MemVal,
           Ra, RaVal, Rb, RbVal,
           Reset, Clock,
           EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI);
   input Reset;
   input Clock;
   input [3:0] CalcValcReg;
   input [31:0] CalcVal;
   input [3:0] MemValReg;
   input [31:0] MemVal;
   input [3:0] Ra;
   input [3:0] Rb;
   output [31:0] RaVal;
   output [31:0] RbVal;
   output [31:0] EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI;

   // Register identifiers
   parameter ID_EAX = 4'h0;
   parameter ID_ECX = 4'h1;
   parameter ID_EDX = 4'h2;
   parameter ID_EBX = 4'h3;
   parameter ID_ESP = 4'h4;
   parameter ID_EBP = 4'h5;
   parameter ID_ESI = 4'h6;
   parameter ID_EDI = 4'h7;
   parameter ID_INVALID = 4'hF;

   wire [31:0] InputEAX, InputECX, InputEDX, InputEBX,
               InputESP, InputEBP, InputESI, InputEDI;
   wire WriteEAX, WriteECX, WriteEDX, WriteEBX,
        WriteESP, WriteEBP, WriteESI, WriteEDI;

   // Instances
   GPR RegEAX(EAX, InputEAX, WriteEAX, Reset, 0, Clock);
   GPR RegECX(ECX, InputECX, WriteECX, Reset, 0, Clock);
   GPR RegEDX(EDX, InputEDX, WriteEDX, Reset, 0, Clock);
   GPR RegEBX(EBX, InputEBX, WriteEBX, Reset, 0, Clock);
   GPR RegESP(ESP, InputESP, WriteESP, Reset, 0, Clock);
   GPR RegEBP(EBP, InputEBP, WriteEBP, Reset, 0, Clock);
   GPR RegESI(ESI, InputESI, WriteESI, Reset, 0, Clock);
   GPR RegEDI(EDI, InputEDI, WriteEDI, Reset, 0, Clock);

   assign RaVal = Ra == ID_EAX ? EAX :
                  Ra == ID_ECX ? ECX :
                  Ra == ID_EDX ? EDX :
                  Ra == ID_EBX ? EBX :
                  Ra == ID_ESP ? ESP :
                  Ra == ID_EBP ? EBP :
                  Ra == ID_ESI ? ESI :
                  Ra == ID_EDI ? EDI : 0;
   assign RbVal = Rb == ID_EAX ? EAX :
                  Rb == ID_ECX ? ECX :
                  Rb == ID_EDX ? EDX :
                  Rb == ID_EBX ? EBX :
                  Rb == ID_ESP ? ESP :
                  Rb == ID_EBP ? EBP :
                  Rb == ID_ESI ? ESI :
                  Rb == ID_EDI ? EDI : 0;

   assign InputEAX = MemValReg == ID_EAX ? MemVal : CalcVal;
   assign InputECX = MemValReg == ID_ECX ? MemVal : CalcVal;
   assign InputEDX = MemValReg == ID_EDX ? MemVal : CalcVal;
   assign InputEBX = MemValReg == ID_EBX ? MemVal : CalcVal;
   assign InputESP = MemValReg == ID_ESP ? MemVal : CalcVal;
   assign InputEBP = MemValReg == ID_EBP ? MemVal : CalcVal;
   assign InputESI = MemValReg == ID_ESI ? MemVal : CalcVal;
   assign InputEDI = MemValReg == ID_EDI ? MemVal : CalcVal;

   assign WriteEAX = MemValReg == ID_EAX | CalcValcReg == ID_EAX;
   assign WriteECX = MemValReg == ID_ECX | CalcValcReg == ID_ECX;
   assign WriteEDX = MemValReg == ID_EDX | CalcValcReg == ID_EDX;
   assign WriteEBX = MemValReg == ID_EBX | CalcValcReg == ID_EBX;
   assign WriteESP = MemValReg == ID_ESP | CalcValcReg == ID_ESP;
   assign WriteEBP = MemValReg == ID_EBP | CalcValcReg == ID_EBP;
   assign WriteESI = MemValReg == ID_ESI | CalcValcReg == ID_ESI;
   assign WriteEDI = MemValReg == ID_EDI | CalcValcReg == ID_EDI;
endmodule
