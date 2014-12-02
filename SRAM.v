module SRAM(ADDR, DATA, WE_N, OE_N, UB_N, LB_N, CE_N);

   input [19:0] ADDR;
   inout [15:0] DATA;
   input WE_N;
   input OE_N;
   input UB_N;
   input LB_N;
   input CE_N;

   reg [15:0] MEM [0:1<<19];
   reg [15:0] D;
   wire [15:0] Q;
   wire [19:0] ADDR;

   assign Q = MEM[ADDR];

   assign DATA[7:0]  = (~CE_N & ~OE_N & ~LB_N & WE_N) ?  Q[7:0] : 8'bzzzzzzzz;
   assign DATA[15:8] = (~CE_N & ~OE_N & ~UB_N & WE_N) ? Q[15:8] : 8'bzzzzzzzz;

   always @(CE_N, WE_N, UB_N, LB_N, ADDR, DATA, D)
   begin
      if (~CE_N & ~WE_N)
      begin
         D[15:0] = MEM[ADDR];
         if (~UB_N)
         begin
            D[15:8] = DATA[15:8];
         end
         if (~LB_N)
         begin
            D[7:0] = DATA[7:0];
         end
         //$display("Writing Memory -> Addr:%0x Block:%0x Val:%0x ", {ADDR,1'b0}, ADDR, D);
         MEM[ADDR] = D[15:0];
      end
   end

endmodule

