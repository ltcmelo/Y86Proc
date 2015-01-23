/*****************************************************************************

 The original version of this code comes from the book "Computer Systems: A
 Programmer's Perspective (2o. Edition)", which is copyrighted by the
 authors Randal E. Bryant and David R O'Hallaron.

 The adaptation for the Altera DE2-115 FPGA along with further extensions
 are authored by Leandro T. C. Melo with contributions by Jeferson Chaves.
 No warranties of any kind given.

******************************************************************************/

module ALU(valA, valB, fun, result, flags);
   input signed [31:0] valA, valB;
   input [3:0]  fun;
   output reg signed [31:0] result;
   output [2:0] flags;

   always @ (valA, valB, fun)
     case (fun)
       4'h0: result = valB + valA;  //ADD
       4'h1: result = valB - valA;  //SUB
       4'h2: result = valB & valA;  //AND
       4'h3: result = valB ^ valA;  //XOR
       4'h4: result = valB * valA;  //MUL
       4'h6: result = valB << valA; //SAL
       4'h7: result = valB >> valA; //SAR
       4'h8: result = valB | valA;  //OR
       4'h9: result = ~valB;        //NOT
       default: result = valB;
     endcase

   // Condition codes.
   assign flags[2] = (result == 32'b0);    // ZF (zero flag).
   assign flags[1] = result[31];           // SF (sign flag).
   assign flags[0] = (fun == 4'h0) ?       // OF (overflow flag).
                         (valA[31] == valB[31]) & (valA[31] == ~result[31]) :
                     (fun == 4'h1) ?
                         (~valA[31] == valB[31]) & (valB[31] == ~result[31]) :
                     1'b0;
endmodule
