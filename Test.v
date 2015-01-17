// Tests for the Y86 processor on the Altera DE2-115 FPGA.
// Copyright Leandro T. C. Melo

module Test;
   wire[31:0] SRAM_ADDR;
   wire [15:0] SRAM_DQ;
   wire SRAM_CE_N,
        SRAM_OE_N,
        SRAM_WE_N,
        SRAM_UB_N,
        SRAM_LB_N;
   wire [2:0] Status;
   wire [31:0] EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI;
   reg CLOCK_50;
   wire LOCK;
   reg [2:0] Mode;
   reg [19:0] i, j, Byte_Addr, DE2_Addr;

   initial #1000000 $finish;

   initial
     begin
        CLOCK_50 = 0;
        forever #5 CLOCK_50 = ~CLOCK_50;
     end

//   always @ (SRAM_ADDR)
//     begin
//        $display("----------> DE2:%0x  Byte:%0x", SRAM_ADDR[20:1], SRAM_ADDR);
//     end

   initial
     begin

        // ----- Test 1 -----
        // Um IRMOVL.
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h30f4;
        sram.MEM[20'h1] = 16'h1122;
        sram.MEM[20'h2] = 16'h3344;
        sram.MEM[20'h3] = 16'h0001;
        #200
        checkReg(ESP, 32'h44332211, 0);


        // ----- Test 2 -----
        // Sequencia de PUSH.
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h30f4; // Inicializa pilha (ESP) no end. 200.
        sram.MEM[20'h1] = 16'h0002;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f1; // Carrega ECX
        sram.MEM[20'h4] = 16'h1020;
        sram.MEM[20'h5] = 16'h3040;
        sram.MEM[20'h6] = 16'h30f2; // Carrega EDX
        sram.MEM[20'h7] = 16'h1122;
        sram.MEM[20'h8] = 16'h3344;
        sram.MEM[20'h9] = 16'ha01f; // PUSH ECX
        sram.MEM[20'ha] = 16'ha02f; // PUSH EDX
        sram.MEM[20'hb] = 16'h0001;
        #200
        checkReg(ESP, 32'h200 - 8, 10);  // ESP decrementado de 8 bytes.
        checkReg(ECX, 32'h40302010, 11); // Little-endian invertido no reg para 0x40302010.
        checkReg(EDX, 32'h44332211, 12);
        checkMemWord(32'h200 - 4, 16'h1020, 14); // Lembre que a pilha cresce para enderecos menores,
        checkMemWord(32'h200 - 2, 16'h3040, 15); // logo 0x10203040 esta de "volta" como original.
        checkMemWord(32'h200 - 8, 16'h1122, 16);
        checkMemWord(32'h200 - 6, 16'h3344, 17);


        // ----- Test 3  -----
        // Um CALL (destino desalinhado - instr de 5 bytes).
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h8011; // CALL
        sram.MEM[20'h1] = 16'h2233;
        sram.MEM[20'h2] = 16'h4401;


        // ----- Test 4 -----
        // Store basico.
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h30f2; // IRMOVL (carrega o registrador primeiro)
        sram.MEM[20'h1] = 16'h1234;
        sram.MEM[20'h2] = 16'h5678;
        sram.MEM[20'h3] = 16'h4025; // RMMOVL (offset 200 do endereco 0)
        sram.MEM[20'h4] = 16'h0002;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h0001;
        #300
        checkReg(EDX, 32'h78563412, 30); // Little-endian invertido no reg para 0x78563412.
        checkMemWord(32'h200, 16'h1234, 31);      // Na "volta" a memoria temos novamente o
        checkMemWord(32'h200 + 2, 16'h5678, 32);  // valor original 0x12345678.


        // ----- Test 5 -----
        // Load basico.
        cleanMem;
        // Popula algumas posicoes de memoria para usar no Test.
        #10 convertAddr(32'h200, DE2_Addr);
        sram.MEM[DE2_Addr] = 16'h2233;
        #10 convertAddr(32'h200 + 2, DE2_Addr);
        sram.MEM[DE2_Addr] = 16'h4455;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h5025; // MRMOVL (offset 200 do endereco 0)
        sram.MEM[20'h1] = 16'h0002;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h0001;
        #300
        checkReg(EDX, 32'h55443322, 40); // Valor 0x22334455 deve estar 0x55443322 no reg.


        // ----- Test 6 -----
        // Soma 5 + 8 com intermediarios.
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h30f2; // IRMOVL
        sram.MEM[20'h1] = 16'h0500;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f3; // IRMOVL
        sram.MEM[20'h4] = 16'h0800;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h6023;
        sram.MEM[20'h7] = 16'h0100;
        #300
        checkReg(EBX, 32'h0000000d, 50);
        checkReg(EDX, 32'h00000005, 51);


        // ----- Test 7 -----
        // Soma 5 + 8 com intermediario e memoria (geral stall).
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h30f2; // IRMOVL (carrega o registrador 2 com valor 5)
        sram.MEM[20'h1] = 16'h0500;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h4025; // RMMOVL (offset eh 0, ja que o registrador 5 eh inicializado com 0)
        sram.MEM[20'h4] = 16'h0000;
        sram.MEM[20'h5] = 16'ha1b2;
        sram.MEM[20'h6] = 16'h30f3; // IRMOVL (carrega o registrador 3 com valor 8)
        sram.MEM[20'h7] = 16'h0800;
        sram.MEM[20'h8] = 16'h0000;
        sram.MEM[20'h9] = 16'h5045; // MRMOVL (carrega o registrador 4 com valor anteriormente escrito)
        sram.MEM[20'ha] = 16'h0000;
        sram.MEM[20'hb] = 16'ha1b2;
        sram.MEM[20'hc] = 16'h6043; // OP (soma o registrador 4 ao 3)
        sram.MEM[20'hd] = 16'h0100;
        #300
        checkReg(EBX, 32'h0000000d, 60);
        checkReg(EDX, 32'h00000005, 61);


        // ----- Test 8 -----
        // Soma 80 + 80 com intermediarios.
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h30f2; // IRMOVL
        sram.MEM[20'h1] = 16'h8000;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f3; // IRMOVL
        sram.MEM[20'h4] = 16'h8000;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h6023;
        sram.MEM[20'h7] = 16'h0100;
        #300
        checkReg(EBX, 32'h00000100, 70);
        checkReg(EDX, 32'h00000080, 71);


        // ----- Test 9 (part of a program) -----
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
                                      // Init:
        sram.MEM[20'h0] = 16'h30f4;   //     irmovl Stack, %esp       # Inicializa ESP
        sram.MEM[20'h1] = 16'h0003;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f5;   //     irmovl Stack, %ebp       # Inicializa EBP
        sram.MEM[20'h4] = 16'h0003;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h8014;   //     call Main
        sram.MEM[20'h7] = 16'h0000;
        sram.MEM[20'h8] = 16'h0000;
        sram.MEM[20'h9] = 16'h0001;   //     halt
                                      // Main:
        sram.MEM[20'ha] = 16'ha05f;   //     pushl %ebp               # Prologo
        sram.MEM[20'hb] = 16'h2045;   //     rrmovl %esp, %ebp
        sram.MEM[20'hc] = 16'ha07f;   //     pushl %edi               # EDI e ESI sao callee-saved regs
        sram.MEM[20'hd] = 16'ha06f;   //     pushl %esi
        sram.MEM[20'he] = 16'h0000;   //                              # NOP (temporario)
        #2000
        checkReg(ESP, 32'h300 - 16, 100);
        checkReg(EBP, 32'h300 - 8, 101);
        checkMemWord(32'h300 - 4, 16'h1100, 102);
        checkMemWord(32'h300 - 4 + 2, 16'h0, 103);


        // ----- Test 10 (continue program)  -----
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
                                      // Init:
        sram.MEM[20'h0] = 16'h30f4;   //     irmovl Stack, %esp       # Inicializa ESP
        sram.MEM[20'h1] = 16'h0003;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f5;   //     irmovl Stack, %ebp       # Inicializa EBP
        sram.MEM[20'h4] = 16'h0003;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h8014;   //     call Main
        sram.MEM[20'h7] = 16'h0000;
        sram.MEM[20'h8] = 16'h0000;
        sram.MEM[20'h9] = 16'h0001;   //     halt
                                      // Main:
        sram.MEM[20'ha] = 16'ha05f;   //     pushl %ebp               # Prologo
        sram.MEM[20'hb] = 16'h2045;   //     rrmovl %esp, %ebp
        sram.MEM[20'hc] = 16'ha07f;   //     pushl %edi               # EDI e ESI sao callee-saved regs
        sram.MEM[20'hd] = 16'ha06f;   //     pushl %esi
        sram.MEM[20'he] = 16'h0000;   //                              # NOP (temporario)
        sram.MEM[20'hf] = 16'h30f1;   //     irmovl $80, %ecx
        sram.MEM[20'h10] = 16'h5000;
        sram.MEM[20'h11] = 16'h0000;
        sram.MEM[20'h12] = 16'h6114;  //     subl %ecx, %esp          # Aloca espaco para locals (e extra para spills)
        #3000
        checkReg(ESP, 32'h300 - 96, 200);
        checkReg(EBP, 32'h300 - 8, 201);
        checkReg(ECX, 80, 202);
        checkMemWord(32'h300 - 4, 16'h1100, 202);
        checkMemWord(32'h300 - 4 + 2, 16'h0, 203);


        // ----- Test 11 (still the program) -----
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
                                      // Init:
        sram.MEM[20'h0] = 16'h30f4;   //     irmovl Stack, %esp       # Inicializa ESP
        sram.MEM[20'h1] = 16'h0003;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f5;   //     irmovl Stack, %ebp       # Inicializa EBP
        sram.MEM[20'h4] = 16'h0003;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h8014;   //     call Main
        sram.MEM[20'h7] = 16'h0000;
        sram.MEM[20'h8] = 16'h0000;
        sram.MEM[20'h9] = 16'h0001;   //     halt
                                      // Main:
        sram.MEM[20'ha] = 16'ha05f;   //     pushl %ebp               # Prologo
        sram.MEM[20'hb] = 16'h2045;   //     rrmovl %esp, %ebp
        sram.MEM[20'hc] = 16'ha07f;   //     pushl %edi               # EDI e ESI sao callee-saved regs
        sram.MEM[20'hd] = 16'ha06f;   //     pushl %esi
        sram.MEM[20'he] = 16'h0000;   //                              # NOP (temporario)
        sram.MEM[20'hf] = 16'h30f1;   //     irmovl $80, %ecx
        sram.MEM[20'h10] = 16'h5000;
        sram.MEM[20'h11] = 16'h0000;
        sram.MEM[20'h12] = 16'h6114;  //     subl %ecx, %esp          # Aloca espaco para locals (e extra para spills)
        sram.MEM[20'h13] = 16'h802c;  //     call L6
        sram.MEM[20'h14] = 16'h0000;
        sram.MEM[20'h15] = 16'h0000;
        #3000
        checkReg(ESP, 32'h300 - 100, 300);
        checkReg(EBP, 32'h300 - 8, 301);
        checkReg(ECX, 80, 302);
        checkMemWord(32'h300 - 100, 16'h2b00, 304);
        checkMemWord(32'h300 - 100 + 2, 16'h0, 305);
        checkMemWord(32'h300 - 4, 16'h1100, 302);
        checkMemWord(32'h300 - 4 + 2, 16'h0, 303);

        // ----- Test 12 (program growing) -----
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
                                      // Init:
        sram.MEM[20'h0] = 16'h30f4;   //     irmovl Stack, %esp       # Inicializa ESP
        sram.MEM[20'h1] = 16'h0003;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f5;   //     irmovl Stack, %ebp       # Inicializa EBP
        sram.MEM[20'h4] = 16'h0003;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h8014;   //     call Main
        sram.MEM[20'h7] = 16'h0000;
        sram.MEM[20'h8] = 16'h0000;
        sram.MEM[20'h9] = 16'h0001;   //     halt
                                      // Main:
        sram.MEM[20'ha] = 16'ha05f;   //     pushl %ebp               # Prologo
        sram.MEM[20'hb] = 16'h2045;   //     rrmovl %esp, %ebp
        sram.MEM[20'hc] = 16'ha07f;   //     pushl %edi               # EDI e ESI sao callee-saved regs
        sram.MEM[20'hd] = 16'ha06f;   //     pushl %esi
        sram.MEM[20'he] = 16'h0000;   //                              # NOP (temporario)
        sram.MEM[20'hf] = 16'h30f1;   //     irmovl $80, %ecx
        sram.MEM[20'h10] = 16'h5000;
        sram.MEM[20'h11] = 16'h0000;
        sram.MEM[20'h12] = 16'h6114;  //     subl %ecx, %esp          # Aloca espaco para locals (e extra para spills)
        sram.MEM[20'h13] = 16'h802c;  //     call L6
        sram.MEM[20'h14] = 16'h0000;
        sram.MEM[20'h15] = 16'h0000;
                                      // L6:
        sram.MEM[20'h16] = 16'hb00f;  //     popl %eax                # Salva o endereco de retorno do call anterior
        #3000
        checkReg(ESP, 32'h300 - 96, 400);
        checkReg(EBP, 32'h300 - 8, 401);
        checkReg(ECX, 80, 402);
        checkReg(EAX, 16'h2b, 403);
        checkMemWord(32'h300 - 100, 16'h2b00, 404);
        checkMemWord(32'h300 - 100 + 2, 16'h0, 405);
        checkMemWord(32'h300 - 4, 16'h1100, 406);
        checkMemWord(32'h300 - 4 + 2, 16'h0, 407);


        // ----- Test 13 (and more from the program) -----
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
                                      // Init:
        sram.MEM[20'h0] = 16'h30f4;   //     irmovl Stack, %esp       # Inicializa ESP
        sram.MEM[20'h1] = 16'h0003;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f5;   //     irmovl Stack, %ebp       # Inicializa EBP
        sram.MEM[20'h4] = 16'h0003;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h8014;   //     call Main
        sram.MEM[20'h7] = 16'h0000;
        sram.MEM[20'h8] = 16'h0000;
        sram.MEM[20'h9] = 16'h0001;   //     halt
                                      // Main:
        sram.MEM[20'ha] = 16'ha05f;   //     pushl %ebp               # Prologo
        sram.MEM[20'hb] = 16'h2045;   //     rrmovl %esp, %ebp
        sram.MEM[20'hc] = 16'ha07f;   //     pushl %edi               # EDI e ESI sao callee-saved regs
        sram.MEM[20'hd] = 16'ha06f;   //     pushl %esi
        sram.MEM[20'he] = 16'h0000;   //                              # NOP (temporario)
        sram.MEM[20'hf] = 16'h30f1;   //     irmovl $80, %ecx
        sram.MEM[20'h10] = 16'h5000;
        sram.MEM[20'h11] = 16'h0000;
        sram.MEM[20'h12] = 16'h6114;  //     subl %ecx, %esp          # Aloca espaco para locals (e extra para spills)
        sram.MEM[20'h13] = 16'h802c;  //     call L6
        sram.MEM[20'h14] = 16'h0000;
        sram.MEM[20'h15] = 16'h0000;
                                      // L6:
        sram.MEM[20'h16] = 16'hb00f;  //     popl %eax                # Salva o endereco de retorno do call anterior
        sram.MEM[20'h17] = 16'h30f1;  //     irmovl $0, %ecx
        sram.MEM[20'h18] = 16'h2233;  // *** ATENCAO: Valor real aqui seria 0, mas esta
        sram.MEM[20'h19] = 16'h4455;  // *** com 0x22334455 apenas para fins de Test.
        sram.MEM[20'h1a] = 16'h4015;  //     rmmovl %ecx, -12(%ebp)   # Inicializa var locais com 0 de ecx
        sram.MEM[20'h1b] = 16'hf4ff;
        sram.MEM[20'h1c] = 16'hffff;
        sram.MEM[20'h1d] = 16'h4015;  //     rmmovl %ecx, -16(%ebp)
        sram.MEM[20'h1e] = 16'hf0ff;
        sram.MEM[20'h1f] = 16'hffff;
        sram.MEM[20'h20] = 16'h4015;  //     rmmovl %ecx, -20(%ebp)
        sram.MEM[20'h21] = 16'hecff;
        sram.MEM[20'h22] = 16'hffff;
        sram.MEM[20'h23] = 16'h4015;  //     rmmovl %ecx, -24(%ebp)
        sram.MEM[20'h24] = 16'he8ff;
        sram.MEM[20'h25] = 16'hffff;
        sram.MEM[20'h26] = 16'h4015;  //     rmmovl %ecx, -28(%ebp)
        sram.MEM[20'h27] = 16'he4ff;
        sram.MEM[20'h28] = 16'hffff;
        sram.MEM[20'h29] = 16'h4015;  //     rmmovl %ecx, -32(%ebp)
        sram.MEM[20'h2a] = 16'he0ff;
        sram.MEM[20'h2b] = 16'hffff;
        sram.MEM[20'h2c] = 16'h4015;  //     rmmovl %ecx, -36(%ebp)
        sram.MEM[20'h2d] = 16'hdcff;
        sram.MEM[20'h2e] = 16'hffff;
        sram.MEM[20'h2f] = 16'h4015;  //     rmmovl %ecx, -40(%ebp)
        sram.MEM[20'h30] = 16'hd8ff;
        sram.MEM[20'h31] = 16'hffff;
        sram.MEM[20'h32] = 16'h4005;  //     rmmovl %eax, -44(%ebp)  # Spill do endereco de retorno salvo em EAX
        sram.MEM[20'h33] = 16'hd4ff;
        sram.MEM[20'h34] = 16'hffff;
        #5000
        checkReg(ESP, 32'h300 - 96, 500);
        checkReg(EBP, 32'h300 - 8, 501);
        checkReg(ECX, 32'h55443322, 502);
        checkMemWord(32'h300 - 4, 16'h1100, 502);
        checkMemWord(32'h300 - 4 + 2, 16'h0, 503);
        checkMemWord(32'h300 - 8 - 12, 16'h2233, 503); // -12(%EBP)
        checkMemWord(32'h300 - 8 - 12 + 2, 16'h4455, 503);
        checkMemWord(32'h300 - 8 - 20, 16'h2233, 504); // -20(%EBP)
        checkMemWord(32'h300 - 8 - 20 + 2, 16'h4455, 505);
        checkMemWord(32'h300 - 8 - 24, 16'h2233, 506); // -24(%EBP)
        checkMemWord(32'h300 - 8 - 24 + 2, 16'h4455, 507);
        checkMemWord(32'h300 - 8 - 28, 16'h2233, 508); // -28(%EBP)
        checkMemWord(32'h300 - 8 - 28 + 2, 16'h4455, 509);
        checkMemWord(32'h300 - 8 - 32, 16'h2233, 510); // -32(%EBP)
        checkMemWord(32'h300 - 8 - 32 + 2, 16'h4455, 511);
        checkMemWord(32'h300 - 8 - 36, 16'h2233, 512); // -36(%EBP)
        checkMemWord(32'h300 - 8 - 36 + 2, 16'h4455, 513);
        checkMemWord(32'h300 - 8 - 40, 16'h2233, 513); // -40(%EBP)
        checkMemWord(32'h300 - 8 - 40 + 2, 16'h4455, 513);
        checkMemWord(32'h300 - 8 - 44, 16'h2b00, 514); // -44(%EBP) mas agora moveu EAX
        checkMemWord(32'h300 - 8 - 44 + 2, 16'h0, 515);
        checkReg(EAX, 16'h2b, 516);


        // ----- Test 14 (the same program goes on) -----
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
                                      // Init:
        sram.MEM[20'h0] = 16'h30f4;   //     irmovl Stack, %esp       # Inicializa ESP
        sram.MEM[20'h1] = 16'h0003;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f5;   //     irmovl Stack, %ebp       # Inicializa EBP
        sram.MEM[20'h4] = 16'h0003;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h8014;   //     call Main
        sram.MEM[20'h7] = 16'h0000;
        sram.MEM[20'h8] = 16'h0000;
        sram.MEM[20'h9] = 16'h0001;   //     halt
                                      // Main:
        sram.MEM[20'ha] = 16'ha05f;   //     pushl %ebp               # Prologo
        sram.MEM[20'hb] = 16'h2045;   //     rrmovl %esp, %ebp
        sram.MEM[20'hc] = 16'ha07f;   //     pushl %edi               # EDI e ESI sao callee-saved regs
        sram.MEM[20'hd] = 16'ha06f;   //     pushl %esi
        sram.MEM[20'he] = 16'h0000;   //                              # NOP (temporario)
        sram.MEM[20'hf] = 16'h30f1;   //     irmovl $80, %ecx
        sram.MEM[20'h10] = 16'h5000;
        sram.MEM[20'h11] = 16'h0000;
        sram.MEM[20'h12] = 16'h6114;  //     subl %ecx, %esp          # Aloca espaco para locals (e extra para spills)
        sram.MEM[20'h13] = 16'h802c;  //     call L6
        sram.MEM[20'h14] = 16'h0000;
        sram.MEM[20'h15] = 16'h0000;
                                      // L6:
        sram.MEM[20'h16] = 16'hb00f;  //     popl %eax                # Salva o endereco de retorno do call anterior
        sram.MEM[20'h17] = 16'h30f1;  //     irmovl $0, %ecx
        sram.MEM[20'h18] = 16'h0500;  // *** ATENCAO: Valor real aqui seria 0, mas esta
        sram.MEM[20'h19] = 16'h0000;  // *** com 5 apenas para fins de Test.
        sram.MEM[20'h1a] = 16'h4015;  //     rmmovl %ecx, -12(%ebp)   # Inicializa var locais com 0 de ecx
        sram.MEM[20'h1b] = 16'hf4ff;
        sram.MEM[20'h1c] = 16'hffff;
        sram.MEM[20'h1d] = 16'h4015;  //     rmmovl %ecx, -16(%ebp)
        sram.MEM[20'h1e] = 16'hf0ff;
        sram.MEM[20'h1f] = 16'hffff;
        sram.MEM[20'h20] = 16'h4015;  //     rmmovl %ecx, -20(%ebp)
        sram.MEM[20'h21] = 16'hecff;
        sram.MEM[20'h22] = 16'hffff;
        sram.MEM[20'h23] = 16'h4015;  //     rmmovl %ecx, -24(%ebp)
        sram.MEM[20'h24] = 16'he8ff;
        sram.MEM[20'h25] = 16'hffff;
        sram.MEM[20'h26] = 16'h4015;  //     rmmovl %ecx, -28(%ebp)
        sram.MEM[20'h27] = 16'he4ff;
        sram.MEM[20'h28] = 16'hffff;
        sram.MEM[20'h29] = 16'h4015;  //     rmmovl %ecx, -32(%ebp)
        sram.MEM[20'h2a] = 16'he0ff;
        sram.MEM[20'h2b] = 16'hffff;
        sram.MEM[20'h2c] = 16'h4015;  //     rmmovl %ecx, -36(%ebp)
        sram.MEM[20'h2d] = 16'hdcff;
        sram.MEM[20'h2e] = 16'hffff;
        sram.MEM[20'h2f] = 16'h4015;  //     rmmovl %ecx, -40(%ebp)
        sram.MEM[20'h30] = 16'hd8ff;
        sram.MEM[20'h31] = 16'hffff;
        sram.MEM[20'h32] = 16'h4005;  //     rmmovl %eax, -44(%ebp)  # Spill do endereco de retorno salvo em EAX
        sram.MEM[20'h33] = 16'hd4ff;
        sram.MEM[20'h34] = 16'hffff;
                                      // LBB6_1:                     # Loop de inicializacao da memoria
        sram.MEM[20'h35] = 16'h30f1;  //     irmovl $320, %ecx       # Emula a instrucao CMP (nao existe no Y86)
        sram.MEM[20'h36] = 16'h4001;
        sram.MEM[20'h37] = 16'h0000;
        sram.MEM[20'h38] = 16'h5005;  //     mrmovl -16(%ebp), %eax
        sram.MEM[20'h39] = 16'hf0ff;
        sram.MEM[20'h3a] = 16'hffff;
        sram.MEM[20'h3b] = 16'h6110;  //     subl %ecx, %eax
        sram.MEM[20'h3c] = 16'h7578;  //     jge LBB6_8              # Jump se terminou a iteracao
        sram.MEM[20'h3d] = 16'h0000;
        sram.MEM[20'h3e] = 16'h0000;
        #5000
        checkReg(ESP, 32'h300 - 96, 600);
        checkReg(EBP, 32'h300 - 8, 601);
        checkReg(ECX, 320, 602);
        checkReg(EAX, -315, 603);


        // ----- Test 15 (finishing the program) -----
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
                                      // Init:
        sram.MEM[20'h0] = 16'h30f4;   //     irmovl Stack, %esp       # Inicializa ESP
        sram.MEM[20'h1] = 16'h0007;
        sram.MEM[20'h2] = 16'h0000;
        sram.MEM[20'h3] = 16'h30f5;   //     irmovl Stack, %ebp       # Inicializa EBP
        sram.MEM[20'h4] = 16'h0007;
        sram.MEM[20'h5] = 16'h0000;
        sram.MEM[20'h6] = 16'h8014;   //     call Main
        sram.MEM[20'h7] = 16'h0000;
        sram.MEM[20'h8] = 16'h0000;
        sram.MEM[20'h9] = 16'h0001;   //     halt
                                      // Main:
        sram.MEM[20'ha] = 16'ha05f;   //     pushl %ebp               # Prologo
        sram.MEM[20'hb] = 16'h2045;   //     rrmovl %esp, %ebp
        sram.MEM[20'hc] = 16'ha07f;   //     pushl %edi               # EDI e ESI sao callee-saved regs
        sram.MEM[20'hd] = 16'ha06f;   //     pushl %esi
        sram.MEM[20'he] = 16'h0000;   //                              # NOP (temporario)
        sram.MEM[20'hf] = 16'h30f1;   //     irmovl $80, %ecx
        sram.MEM[20'h10] = 16'h5000;
        sram.MEM[20'h11] = 16'h0000;
        sram.MEM[20'h12] = 16'h6114;  //     subl %ecx, %esp          # Aloca espaco para locals (e extra para spills)
        sram.MEM[20'h13] = 16'h802c;  //     call L6
        sram.MEM[20'h14] = 16'h0000;
        sram.MEM[20'h15] = 16'h0000;
                                      // L6:
        sram.MEM[20'h16] = 16'hb00f;  //     popl %eax                # Salva o endereco de retorno do call anterior
        sram.MEM[20'h17] = 16'h30f1;  //     irmovl $0, %ecx
        sram.MEM[20'h18] = 16'h0000;
        sram.MEM[20'h19] = 16'h0000;
        sram.MEM[20'h1a] = 16'h4015;  //     rmmovl %ecx, -12(%ebp)   # Inicializa var locais com 0 de ecx
        sram.MEM[20'h1b] = 16'hf4ff;
        sram.MEM[20'h1c] = 16'hffff;
        sram.MEM[20'h1d] = 16'h4015;  //     rmmovl %ecx, -16(%ebp)
        sram.MEM[20'h1e] = 16'hf0ff;
        sram.MEM[20'h1f] = 16'hffff;
        sram.MEM[20'h20] = 16'h4015;  //     rmmovl %ecx, -20(%ebp)
        sram.MEM[20'h21] = 16'hecff;
        sram.MEM[20'h22] = 16'hffff;
        sram.MEM[20'h23] = 16'h4015;  //     rmmovl %ecx, -24(%ebp)
        sram.MEM[20'h24] = 16'he8ff;
        sram.MEM[20'h25] = 16'hffff;
        sram.MEM[20'h26] = 16'h4015;  //     rmmovl %ecx, -28(%ebp)
        sram.MEM[20'h27] = 16'he4ff;
        sram.MEM[20'h28] = 16'hffff;
        sram.MEM[20'h29] = 16'h4015;  //     rmmovl %ecx, -32(%ebp)
        sram.MEM[20'h2a] = 16'he0ff;
        sram.MEM[20'h2b] = 16'hffff;
        sram.MEM[20'h2c] = 16'h4015;  //     rmmovl %ecx, -36(%ebp)
        sram.MEM[20'h2d] = 16'hdcff;
        sram.MEM[20'h2e] = 16'hffff;
        sram.MEM[20'h2f] = 16'h4015;  //     rmmovl %ecx, -40(%ebp)
        sram.MEM[20'h30] = 16'hd8ff;
        sram.MEM[20'h31] = 16'hffff;
        sram.MEM[20'h32] = 16'h4005;  //     rmmovl %eax, -44(%ebp)  # Spill do endereco de retorno salvo em EAX
        sram.MEM[20'h33] = 16'hd4ff;
        sram.MEM[20'h34] = 16'hffff;
                                      // LBB6_1:                     # Loop de inicializacao da memoria
        sram.MEM[20'h35] = 16'h30f1;  //     irmovl $320, %ecx       # Emula a instrucao CMP (nao existe no Y86)
        sram.MEM[20'h36] = 16'h0900;  // *** ATENCAO: Deve ser 4001 (esta 9 apenas para Test)
        sram.MEM[20'h37] = 16'h0000;
        sram.MEM[20'h38] = 16'h5005;  //     mrmovl -16(%ebp), %eax
        sram.MEM[20'h39] = 16'hf0ff;
        sram.MEM[20'h3a] = 16'hffff;
        sram.MEM[20'h3b] = 16'h6110;  //     subl %ecx, %eax
        sram.MEM[20'h3c] = 16'h75fe;  //     jge LBB6_8              # Jump se terminou a iteracao
        sram.MEM[20'h3d] = 16'h0000;
        sram.MEM[20'h3e] = 16'h0000;
        sram.MEM[20'h3f] = 16'h30f0;  //     irmovl $0, %eax
        sram.MEM[20'h40] = 16'h0000;
        sram.MEM[20'h41] = 16'h0000;
        sram.MEM[20'h42] = 16'h4005;  //     rmmovl %eax, -20(%ebp)  # Inicializa posV no loop interno
        sram.MEM[20'h43] = 16'hecff;
        sram.MEM[20'h44] = 16'hffff;
                                      // LBB6_3:                     # Loop (interno) de inicializacao da memoria
        sram.MEM[20'h45] = 16'h30f7;  // *** ATENCAO: Deve ser 30f1    irmovl $240, %ecx       # Emula a instrucao CMP (nao existe no Y86)
        sram.MEM[20'h46] = 16'h0500;  // *** ATENCAO: Deve ser f000
        sram.MEM[20'h47] = 16'h0000;
        sram.MEM[20'h48] = 16'h5005;  //     mrmovl -20(%ebp), %eax
        sram.MEM[20'h49] = 16'hecff;
        sram.MEM[20'h4a] = 16'hffff;
        sram.MEM[20'h4b] = 16'h6170;  // *** ATENCAO: Deve ser 6110    subl %ecx, %eax
        sram.MEM[20'h4c] = 16'h75de;  //     jge LBB6_6              # Jump se terminou a iteracao interna
        sram.MEM[20'h4d] = 16'h0000;
        sram.MEM[20'h4e] = 16'h0000;
        sram.MEM[20'h4f] = 16'h5015;  //     mrmovl -16(%ebp), %ecx  # Acesso ao VGA
        sram.MEM[20'h50] = 16'hf0ff;
        sram.MEM[20'h51] = 16'hffff;
        sram.MEM[20'h52] = 16'h30f2;  //     irmovl $240, %edx
        sram.MEM[20'h53] = 16'h0500;  // *** ATENCAO: Deve ser f000
        sram.MEM[20'h54] = 16'h0000;
        sram.MEM[20'h55] = 16'h6412;  //     mull %ecx, %edx         # Multiplicacao
        sram.MEM[20'h56] = 16'h5015;  //     mrmovl -20(%ebp), %ecx
        sram.MEM[20'h57] = 16'hecff;
        sram.MEM[20'h58] = 16'hffff;
        sram.MEM[20'h59] = 16'h6012;  //     addl %ecx, %edx
        sram.MEM[20'h5a] = 16'h30f1;  //     irmovl $4, %ecx
        sram.MEM[20'h5b] = 16'h0400;
        sram.MEM[20'h5c] = 16'h0000;
        sram.MEM[20'h5d] = 16'h6412;  //     mull %ecx, %edx
        sram.MEM[20'h5e] = 16'h30f6;  // *** ATENCAO: Deve ser 30f0    irmovl $0, %eax
        sram.MEM[20'h5f] = 16'h6688;  // *** ATENCAO: Deve ser 0000
        sram.MEM[20'h60] = 16'h7799;  // *** ATENCAO: Deve ser 0000
        sram.MEM[20'h61] = 16'h4062;  // *** ATENCAO: Deve ser 4002    rmmovl %eax, 0xED400(%edx)
        sram.MEM[20'h62] = 16'h00d4;
        sram.MEM[20'h63] = 16'h0e00;
        sram.MEM[20'h64] = 16'h5005;  //     mrmovl -20(%ebp), %eax  # Incrementa posV
        sram.MEM[20'h65] = 16'hecff;
        sram.MEM[20'h66] = 16'hffff;
        sram.MEM[20'h67] = 16'h30f2;  //     irmovl $1, %edx
        sram.MEM[20'h68] = 16'h0100;
        sram.MEM[20'h69] = 16'h0000;
        sram.MEM[20'h6a] = 16'h6020;  //     addl %edx, %eax
        sram.MEM[20'h6b] = 16'h4005;  //     rmmovl %eax, -20(%ebp)
        sram.MEM[20'h6c] = 16'hecff;
        sram.MEM[20'h6d] = 16'hffff;
        sram.MEM[20'h6e] = 16'h708a;  //     jmp LBB6_3
        sram.MEM[20'h6f] = 16'h0000;
        sram.MEM[20'h70] = 16'h0000;
                                      // LBB6_6:
        sram.MEM[20'h71] = 16'h70e4;  //     jmp LBB6_7
        sram.MEM[20'h72] = 16'h0000;
        sram.MEM[20'h73] = 16'h0000;
                                      // LBB6_7:
        sram.MEM[20'h74] = 16'h5005;  //     mrmovl -16(%ebp), %eax  # Incrementa posH
        sram.MEM[20'h75] = 16'hf0ff;
        sram.MEM[20'h76] = 16'hffff;
        sram.MEM[20'h77] = 16'h30f2;  //     irmovl $1, %edx
        sram.MEM[20'h78] = 16'h0100;
        sram.MEM[20'h79] = 16'h0000;
        sram.MEM[20'h7a] = 16'h6020;  //     addl %edx, %eax
        sram.MEM[20'h7b] = 16'h4005;  //     rmmovl %eax, -16(%ebp)
        sram.MEM[20'h7c] = 16'hf0ff;
        sram.MEM[20'h7d] = 16'hffff;
        sram.MEM[20'h7e] = 16'h706a;  //     jmp LBB6_1
        sram.MEM[20'h7f] = 16'h0000;
        sram.MEM[20'h80] = 16'h0000;
                                      // LBB6_8
        sram.MEM[20'h81] = 16'h30f0;  //     irmovl $0, %eax
        sram.MEM[20'h82] = 16'h0000;
        sram.MEM[20'h83] = 16'h0000;
        sram.MEM[20'h84] = 16'h4005;  //     rmmovl %eax, -20(%ebp)    # Atribui 0 a posV/posH para proxima iteracao
        sram.MEM[20'h85] = 16'hecff;
        sram.MEM[20'h86] = 16'hffff;
        sram.MEM[20'h87] = 16'h4005;  //     rmmovl %eax, -16(%ebp)
        sram.MEM[20'h88] = 16'hf0ff;
        sram.MEM[20'h89] = 16'hffff;
        $display("Este Test demora um pouquinho. Aguarde...");
        #50000
        checkReg(ESP, 32'h700 - 96, 700);
        checkReg(EBP, 32'h700 - 8, 701);
        checkReg(ECX, 9, 702); // VGA H -> 9
        checkReg(EDI, 5, 703); // VGA V -> 5
        checkReg(EDX, 1, 704);
        checkReg(EAX, 0, 705);
        checkReg(ESI, 32'h99778866, 706);
        Byte_Addr = 20'hed400;
        for (i = 0; i < (9 * 5); i = i + 1) begin
            checkMemWord(Byte_Addr, 16'h6688, 707);
            checkMemWord(Byte_Addr + 2, 16'h7799, 708);
            Byte_Addr = Byte_Addr + 4;
        end

        // ----- Test Fig. 4.7 -----
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[0] = 16'h30f4;
        sram.MEM[1] = 16'h0001;
        sram.MEM[2] = 16'h0000;
        sram.MEM[3] = 16'h30f5;
        sram.MEM[4] = 16'h0001;
        sram.MEM[5] = 16'h0000;
        sram.MEM[6] = 16'h8024;
        sram.MEM[7] = 16'h0000;
        sram.MEM[8] = 16'h0000;
        sram.MEM[9] = 16'h0000;
        sram.MEM[10] = 16'h0d00;
        sram.MEM[11] = 16'h0000;
        sram.MEM[12] = 16'hc000;
        sram.MEM[13] = 16'h0000;
        sram.MEM[14] = 16'h000b;
        sram.MEM[15] = 16'h0000;
        sram.MEM[16] = 16'h00a0;
        sram.MEM[17] = 16'h0000;
        sram.MEM[18] = 16'ha05f;
        sram.MEM[19] = 16'h2045;
        sram.MEM[20] = 16'h30f0;
        sram.MEM[21] = 16'h0400;
        sram.MEM[22] = 16'h0000;
        sram.MEM[23] = 16'ha00f;
        sram.MEM[24] = 16'h30f2;
        sram.MEM[25] = 16'h1400;
        sram.MEM[26] = 16'h0000;
        sram.MEM[27] = 16'ha02f;
        sram.MEM[28] = 16'h8042;
        sram.MEM[29] = 16'h0000;
        sram.MEM[30] = 16'h0020;
        sram.MEM[31] = 16'h54b0;
        sram.MEM[32] = 16'h5f90;
        sram.MEM[33] = 16'ha05f;
        sram.MEM[34] = 16'h2045;
        sram.MEM[35] = 16'h5015;
        sram.MEM[36] = 16'h0800;
        sram.MEM[37] = 16'h0000;
        sram.MEM[38] = 16'h5025;
        sram.MEM[39] = 16'h0c00;
        sram.MEM[40] = 16'h0000;
        sram.MEM[41] = 16'h6300;
        sram.MEM[42] = 16'h6222;
        sram.MEM[43] = 16'h7378;
        sram.MEM[44] = 16'h0000;
        sram.MEM[45] = 16'h0050;
        sram.MEM[46] = 16'h6100;
        sram.MEM[47] = 16'h0000;
        sram.MEM[48] = 16'h0060;
        sram.MEM[49] = 16'h6030;
        sram.MEM[50] = 16'hf304;
        sram.MEM[51] = 16'h0000;
        sram.MEM[52] = 16'h0060;
        sram.MEM[53] = 16'h3130;
        sram.MEM[54] = 16'hf3ff;
        sram.MEM[55] = 16'hffff;
        sram.MEM[56] = 16'hff60;
        sram.MEM[57] = 16'h3274;
        sram.MEM[58] = 16'h5b00;
        sram.MEM[59] = 16'h0000;
        sram.MEM[60] = 16'h2054;
        sram.MEM[61] = 16'hb05f;
        sram.MEM[62] = 16'h9090;
        sram.MEM[63] = 16'h0000;
        #10000
        printRegs;


        $display("!!! Tests finished successfully !!!");
        $finish;
     end


   Proc core(Mode, CLOCK_50, Status,
             SRAM_ADDR, SRAM_DQ, SRAM_WE_N, SRAM_OE_N, SRAM_UB_N, SRAM_LB_N, SRAM_CE_N,
             EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI);
   SRAM sram(SRAM_ADDR[20:1], SRAM_DQ, ~SRAM_WE_N, ~SRAM_OE_N, SRAM_UB_N, SRAM_LB_N, SRAM_CE_N);

   task printRegs;
      begin
         $display("%%eax: 0x%x", EAX);
         $display("%%ecx: 0x%x", ECX);
         $display("%%edx: 0x%x", EDX);
         $display("%%ebx: 0x%x", EBX);
         $display("%%esp: 0x%x", ESP);
         $display("%%ebp: 0x%x", EBP);
         $display("%%esi: 0x%x", ESI);
         $display("%%edi: 0x%x", EDI);
         $display("top of stack: 0x%x%x", sram.MEM[ESP[20:1]], sram.MEM[ESP[20:1]+1]);
         $display("base pointer: 0x%x%x", sram.MEM[EBP[20:1]], sram.MEM[EBP[20:1]+1]);
      end
   endtask

   task checkReg;
      input [31:0] actual, expected, checkID;
      begin
         if (expected != actual)
           begin
              $display("*** (%0d) Register ERROR! Expected: %0x Actual: %0x", checkID, expected, actual);
              $finish;
           end
         else
           $display("OK (%0d)... %0x", checkID, expected);
      end
   endtask

   task checkMemWord;
      input [31:0] addr;
      input [15:0] expected, checkID;
      reg [15:0] actual;
      begin
         actual = sram.MEM[addr[20:1]];
         if (expected != actual)
           begin
              $display("*** (%0d) Memory ERROR at addr:%0x! Expected: %0x Actual: %0x",
                       checkID, addr, expected, actual);
              $finish;
           end
         else
           $display("OK (%0d)... %0x", checkID, expected);
      end
   endtask

   task convertAddr;
      input [31:0] byteAddr;
      output [19:0] wordAddr;
      begin
         wordAddr = byteAddr[20:1];
      end
   endtask

   task cleanMem;
        // Inicializa todas posicoes de memoria (facilita verificoes).
        for (i = 0; i < 1<<19; i = i + 1) begin
           sram.MEM[i] = 16'h0000;
        end
   endtask

endmodule
