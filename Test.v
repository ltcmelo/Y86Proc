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
   reg [19:0] i, j, k, Byte_Addr, DE2_Addr;


   initial #100000000 $finish;

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
        // --- Test 1 -------------------------------------------------------//
        // IRMOVL.
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h30f4;
        sram.MEM[20'h1] = 16'h1122;
        sram.MEM[20'h2] = 16'h3344;
        sram.MEM[20'h3] = 16'h0001;
        #200
        checkReg(ESP, 32'h44332211, 0);


        // --- Test 2 -------------------------------------------------------//
        // PUSH sequence.
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
        checkMemByAddr(32'h200 - 4, 16'h1020, 14); // Lembre que a pilha cresce para enderecos menores,
        checkMemByAddr(32'h200 - 2, 16'h3040, 15); // logo 0x10203040 esta de "volta" como original.
        checkMemByAddr(32'h200 - 8, 16'h1122, 16);
        checkMemByAddr(32'h200 - 6, 16'h3344, 17);


        // --- Test 3 -------------------------------------------------------//
        // CALL (destino desalinhado - instr de 5 bytes).
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[20'h0] = 16'h8011; // CALL
        sram.MEM[20'h1] = 16'h2233;
        sram.MEM[20'h2] = 16'h4401;


        // --- Test 4 -------------------------------------------------------//
        // Store.
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
        checkMemByAddr(32'h200, 16'h1234, 31);      // Na "volta" a memoria temos novamente o
        checkMemByAddr(32'h200 + 2, 16'h5678, 32);  // valor original 0x12345678.


        // --- Test 5 -------------------------------------------------------//
        // Load.
        cleanMem;
        // Popula algumas posicoes de memoria para usar no teste.
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


        // --- Test 6 -------------------------------------------------------//
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


        // --- Test 7 -------------------------------------------------------//
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


        // --- Test 8 -------------------------------------------------------//
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


        // --- Test TP final (secao A) --------------------------------------//
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
        checkMemByAddr(32'h300 - 4, 16'h1100, 102);
        checkMemByAddr(32'h300 - 4 + 2, 16'h0, 103);


        // --- Test TP final (secao B) --------------------------------------//
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
        checkMemByAddr(32'h300 - 4, 16'h1100, 202);
        checkMemByAddr(32'h300 - 4 + 2, 16'h0, 203);


        // --- Test TP final (secao C) --------------------------------------//
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
        checkMemByAddr(32'h300 - 100, 16'h2b00, 304);
        checkMemByAddr(32'h300 - 100 + 2, 16'h0, 305);
        checkMemByAddr(32'h300 - 4, 16'h1100, 302);
        checkMemByAddr(32'h300 - 4 + 2, 16'h0, 303);


        // --- Test TP final (secao D) --------------------------------------//
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
        checkMemByAddr(32'h300 - 100, 16'h2b00, 404);
        checkMemByAddr(32'h300 - 100 + 2, 16'h0, 405);
        checkMemByAddr(32'h300 - 4, 16'h1100, 406);
        checkMemByAddr(32'h300 - 4 + 2, 16'h0, 407);


        // --- Test TP final (secao E) --------------------------------------//
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
        sram.MEM[20'h19] = 16'h4455;  // *** com 0x22334455 apenas para fins de teste.
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
        checkMemByAddr(32'h300 - 4, 16'h1100, 502);
        checkMemByAddr(32'h300 - 4 + 2, 16'h0, 503);
        checkMemByAddr(32'h300 - 8 - 12, 16'h2233, 503); // -12(%EBP)
        checkMemByAddr(32'h300 - 8 - 12 + 2, 16'h4455, 503);
        checkMemByAddr(32'h300 - 8 - 20, 16'h2233, 504); // -20(%EBP)
        checkMemByAddr(32'h300 - 8 - 20 + 2, 16'h4455, 505);
        checkMemByAddr(32'h300 - 8 - 24, 16'h2233, 506); // -24(%EBP)
        checkMemByAddr(32'h300 - 8 - 24 + 2, 16'h4455, 507);
        checkMemByAddr(32'h300 - 8 - 28, 16'h2233, 508); // -28(%EBP)
        checkMemByAddr(32'h300 - 8 - 28 + 2, 16'h4455, 509);
        checkMemByAddr(32'h300 - 8 - 32, 16'h2233, 510); // -32(%EBP)
        checkMemByAddr(32'h300 - 8 - 32 + 2, 16'h4455, 511);
        checkMemByAddr(32'h300 - 8 - 36, 16'h2233, 512); // -36(%EBP)
        checkMemByAddr(32'h300 - 8 - 36 + 2, 16'h4455, 513);
        checkMemByAddr(32'h300 - 8 - 40, 16'h2233, 513); // -40(%EBP)
        checkMemByAddr(32'h300 - 8 - 40 + 2, 16'h4455, 513);
        checkMemByAddr(32'h300 - 8 - 44, 16'h2b00, 514); // -44(%EBP) mas agora moveu EAX
        checkMemByAddr(32'h300 - 8 - 44 + 2, 16'h0, 515);
        checkReg(EAX, 16'h2b, 516);


        // --- Test TP final (secao F) --------------------------------------//
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
        sram.MEM[20'h19] = 16'h0000;  // *** com 5 apenas para fins de teste.
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


        // --- Test TP final (secao G) --------------------------------------//
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
        sram.MEM[20'h36] = 16'h0900;  // *** ATENCAO: Deve ser 4001 (esta 9 apenas para teste)
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
            //$display("MEM:%0x prox. %0x", i, i+2);
            checkMemByAddr(Byte_Addr, 16'h6688, 707);
            checkMemByAddr(Byte_Addr + 2, 16'h7799, 708);
            Byte_Addr = Byte_Addr + 4;
        end


        // --- Test Fig. 4.7 (from the book) --------------------------------//
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


        // --- Test immediate ALU operations --------------------------------//
        // IADDL.
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[0] = 16'h30f4;
        sram.MEM[1] = 16'h0d00;
        sram.MEM[2] = 16'h0000;
        sram.MEM[3] = 16'hc0f4;
        sram.MEM[4] = 16'hc000;
        sram.MEM[5] = 16'h0000;
        sram.MEM[6] = 16'h0001;
        #1000
        checkReg(ESP, 32'h000000cd, 900);


        // --- Test simple array write --------------------------------------//
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[0] = 16'h30f4;
        sram.MEM[1] = 16'h000f;
        sram.MEM[2] = 16'h0000;
        sram.MEM[3] = 16'h30f5;
        sram.MEM[4] = 16'h000f;
        sram.MEM[5] = 16'h0000;
        sram.MEM[6] = 16'h8024;
        sram.MEM[7] = 16'h0000;
        sram.MEM[8] = 16'h0000;
        sram.MEM[9] = 16'h0000;
        sram.MEM[10] = 16'haaaa;
        sram.MEM[11] = 16'haaaa;
        sram.MEM[12] = 16'hbbbb;
        sram.MEM[13] = 16'hbbbb;
        sram.MEM[14] = 16'hcccc;
        sram.MEM[15] = 16'hcccc;
        sram.MEM[16] = 16'hdddd;
        sram.MEM[17] = 16'hdddd;
        sram.MEM[18] = 16'ha05f;
        sram.MEM[19] = 16'h2045;
        sram.MEM[20] = 16'h30f2;
        sram.MEM[21] = 16'h4433;
        sram.MEM[22] = 16'h2211;
        sram.MEM[23] = 16'h30f0;
        sram.MEM[24] = 16'h1400;
        sram.MEM[25] = 16'h0000;
        sram.MEM[26] = 16'h4020;
        sram.MEM[27] = 16'h0800;
        sram.MEM[28] = 16'h0000;
        sram.MEM[29] = 16'h30f1;
        sram.MEM[30] = 16'h0100;
        sram.MEM[31] = 16'h0000;
        sram.MEM[32] = 16'hb05f;
        #10000
        //printMemByDE2Index(0, 20);
        checkMemByDE2Index(11, 16'haaaa, 1000);
        checkMemByDE2Index(11, 16'haaaa, 1001);
        checkMemByDE2Index(12, 16'hbbbb, 1002);
        checkMemByDE2Index(13, 16'hbbbb, 1003);
        checkMemByDE2Index(14, 16'h4433, 1004);
        checkMemByDE2Index(15, 16'h2211, 1005);
        checkMemByDE2Index(16, 16'hdddd, 1006);
        checkMemByDE2Index(17, 16'hdddd, 1007);


        // --- Test simple array read ---------------------------------------//
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        sram.MEM[0] = 16'h30f4;
        sram.MEM[1] = 16'h000f;
        sram.MEM[2] = 16'h0000;
        sram.MEM[3] = 16'h30f5;
        sram.MEM[4] = 16'h000f;
        sram.MEM[5] = 16'h0000;
        sram.MEM[6] = 16'h8024;
        sram.MEM[7] = 16'h0000;
        sram.MEM[8] = 16'h0000;
        sram.MEM[10] = 16'haaaa;
        sram.MEM[11] = 16'haaaa;
        sram.MEM[12] = 16'hbbbb;
        sram.MEM[13] = 16'hbbbb;
        sram.MEM[14] = 16'hcccc;
        sram.MEM[15] = 16'hcccc;
        sram.MEM[16] = 16'hdddd;
        sram.MEM[17] = 16'hdddd;
        sram.MEM[18] = 16'ha05f;
        sram.MEM[19] = 16'h2045;
        sram.MEM[20] = 16'hc1f4;
        sram.MEM[21] = 16'h0400;
        sram.MEM[22] = 16'h0000;
        sram.MEM[23] = 16'h30f0;
        sram.MEM[24] = 16'h1400;
        sram.MEM[25] = 16'h0000;
        sram.MEM[26] = 16'h5020;
        sram.MEM[27] = 16'h0800;
        sram.MEM[28] = 16'h0000;
        sram.MEM[29] = 16'h4025;
        sram.MEM[30] = 16'hfcff;
        sram.MEM[31] = 16'hffff;
        sram.MEM[32] = 16'h30f0;
        sram.MEM[33] = 16'h0100;
        sram.MEM[34] = 16'h0000;
        sram.MEM[35] = 16'hc0f4;
        sram.MEM[36] = 16'h0400;
        sram.MEM[37] = 16'h0000;
        sram.MEM[38] = 16'hb05f;
        sram.MEM[39] = 16'h0001;
        sram.MEM[32'hf00 - 12] = 16'h8888;     // Marker ("old" value)
        sram.MEM[32'hf00 - 12 + 2] = 16'h8888; // Low part of the marker.
        #10000
        //printMemByAddr(32'hf00 - 12, 32'hf00 + 4);
        checkMemByAddr(32'hf00 - 12 + 2, 16'hcccc, 1400); // Value read low
        checkMemByAddr(32'hf00 - 12, 16'hcccc, 1401);     // Value read hi


        // --- Test Bubblesort 10 elements ----------------------------------//
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        //  0x0000:              |     .pos 0
        //                       |
        //  0x0000:              | Init:
        //  0x0000:30f4000f0000  |     irmovl Stack, %esp
        sram.MEM[0] = 16'h30f4;
        sram.MEM[1] = 16'h000f;
        sram.MEM[2] = 16'h0000;
        //  0x0006:30f5000f0000  |     irmovl Stack, %ebp
        sram.MEM[3] = 16'h30f5;
        sram.MEM[4] = 16'h000f;
        sram.MEM[5] = 16'h0000;
        //  0x000c:803c000000    |     call Main
        sram.MEM[6] = 16'h803c;
        sram.MEM[7] = 16'h0000;
        //  0x0011:10            |     halt
        sram.MEM[8] = 16'h0010;
        //                       |
        //  0x0014:              |     .align 4
        //  0x0014:              | Array:
        //  0x0014:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[10] = 16'hd204;
        sram.MEM[11] = 16'h0000;
        //  0x0018:2e160000      |     .long	5678                    ##
        sram.MEM[12] = 16'h2e16;
        sram.MEM[13] = 16'h0000;
        //  0x001c:00000000      |     .long	0                       ## 0x0
        sram.MEM[14] = 16'h0000;
        sram.MEM[15] = 16'h0000;
        //  0x0020:00000000      |     .long	0                       ## 0x0
        sram.MEM[16] = 16'h0000;
        sram.MEM[17] = 16'h0000;
        //  0x0024:00000000      |     .long	0                       ## 0x0
        sram.MEM[18] = 16'h0000;
        sram.MEM[19] = 16'h0000;
        //  0x0028:00000000      |     .long	0                       ## 0x0
        sram.MEM[20] = 16'h0000;
        sram.MEM[21] = 16'h0000;
        //  0x002c:00000000      |     .long	0                       ## 0x0
        sram.MEM[22] = 16'h0000;
        sram.MEM[23] = 16'h0000;
        //  0x0030:00000000      |     .long	0                       ## 0x0
        sram.MEM[24] = 16'h0000;
        sram.MEM[25] = 16'h0000;
        //  0x0034:00000000      |     .long	0                       ## 0x0
        sram.MEM[26] = 16'h0000;
        sram.MEM[27] = 16'h0000;
        //  0x0038:00000000      |     .long	0                       ## 0x0
        sram.MEM[28] = 16'h0000;
        sram.MEM[29] = 16'h0000;
        //                       |
        //  0x003c:              | Main:
        //  0x003c:a05f          |     pushl	%ebp
        sram.MEM[30] = 16'ha05f;
        //  0x003e:2045          |     rrmovl	%esp, %ebp
        sram.MEM[31] = 16'h2045;
        //  0x0040:c1f40c000000  |     isubl	$12, %esp
        sram.MEM[32] = 16'hc1f4;
        sram.MEM[33] = 16'h0c00;
        sram.MEM[34] = 16'h0000;
        //                       |
        //  0x0046:30f000000000  |     irmovl $0, %eax
        sram.MEM[35] = 16'h30f0;
        sram.MEM[36] = 16'h0000;
        sram.MEM[37] = 16'h0000;
        //  0x004c:4005fcffffff  |     rmmovl %eax, -4(%ebp) # inicializa i, j
        sram.MEM[38] = 16'h4005;
        sram.MEM[39] = 16'hfcff;
        sram.MEM[40] = 16'hffff;
        //  0x0052:4005f8ffffff  |     rmmovl %eax, -8(%ebp)
        sram.MEM[41] = 16'h4005;
        sram.MEM[42] = 16'hf8ff;
        sram.MEM[43] = 16'hffff;
        //                       |
        //  0x0058:              | LBB0_1:                                 ## inicializa array
        //  0x0058:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[44] = 16'h5005;
        sram.MEM[45] = 16'hfcff;
        sram.MEM[46] = 16'hffff;
        //  0x005e:c1f00a000000  |     isubl $10, %eax
        sram.MEM[47] = 16'hc1f0;
        sram.MEM[48] = 16'h0a00;
        sram.MEM[49] = 16'h0000;
        //  0x0064:759a000000    |     jge LBB0_4
        sram.MEM[50] = 16'h759a;
        sram.MEM[51] = 16'h0000;
        //                       |
        //                       | ## BB#2:                                ## attribui valores em ordem decrescente
        //  0x0069:30f00a000000  |     irmovl $10, %eax
        sram.MEM[52] = 16'h0030;
        sram.MEM[53] = 16'hf00a;
        sram.MEM[54] = 16'h0000;
        //  0x006f:5015fcffffff  |     mrmovl -4(%ebp), %ecx
        sram.MEM[55] = 16'h0050;
        sram.MEM[56] = 16'h15fc;
        sram.MEM[57] = 16'hffff;
        //  0x0075:6110          |     subl %ecx, %eax
        sram.MEM[58] = 16'hff61;
        //  0x0077:c4f104000000  |     imull $4, %ecx # 4 bytes por posicao
        sram.MEM[59] = 16'h10c4;
        sram.MEM[60] = 16'hf104;
        sram.MEM[61] = 16'h0000;
        //  0x007d:400114000000  |     rmmovl %eax, Array(%ecx)
        sram.MEM[62] = 16'h0040;
        sram.MEM[63] = 16'h0114;
        sram.MEM[64] = 16'h0000;
        //                       |
        //                       | ## BB#3:                                ## proxima iteracao de inicializacao
        //  0x0083:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[65] = 16'h0050;
        sram.MEM[66] = 16'h05fc;
        sram.MEM[67] = 16'hffff;
        //  0x0089:c0f001000000  |     iaddl $1, %eax
        sram.MEM[68] = 16'hffc0;
        sram.MEM[69] = 16'hf001;
        sram.MEM[70] = 16'h0000;
        //  0x008f:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[71] = 16'h0040;
        sram.MEM[72] = 16'h05fc;
        sram.MEM[73] = 16'hffff;
        //  0x0095:7058000000    |     jmp LBB0_1
        sram.MEM[74] = 16'hff70;
        sram.MEM[75] = 16'h5800;
        sram.MEM[76] = 16'h0000;
        //                       |
        //                       |
        //  0x009a:              | LBB0_4:
        //  0x009a:30f209000000  |     irmovl $9, %edx
        sram.MEM[77] = 16'h30f2;
        sram.MEM[78] = 16'h0900;
        sram.MEM[79] = 16'h0000;
        //  0x00a0:4025f4ffffff  |     rmmovl %edx, -12(%ebp)
        sram.MEM[80] = 16'h4025;
        sram.MEM[81] = 16'hf4ff;
        sram.MEM[82] = 16'hffff;
        //                       |
        //  0x00a6:              | LBB0_5:                                 ## while (top>0)
        //  0x00a6:5025f4ffffff  |     mrmovl -12(%ebp), %edx
        sram.MEM[83] = 16'h5025;
        sram.MEM[84] = 16'hf4ff;
        sram.MEM[85] = 16'hffff;
        //  0x00ac:c1f200000000  |     isubl $0, %edx
        sram.MEM[86] = 16'hc1f2;
        sram.MEM[87] = 16'h0000;
        sram.MEM[88] = 16'h0000;
        //  0x00b2:716d010000    |     jle LBB0_12
        sram.MEM[89] = 16'h716d;
        sram.MEM[90] = 16'h0100;
        //                       |
        //                       | ## BB#6:                                ## i = 0
        //  0x00b7:30f000000000  |     irmovl $0, %eax
        sram.MEM[91] = 16'h0030;
        sram.MEM[92] = 16'hf000;
        sram.MEM[93] = 16'h0000;
        //  0x00bd:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[94] = 16'h0040;
        sram.MEM[95] = 16'h05fc;
        sram.MEM[96] = 16'hffff;
        //                       |
        //  0x00c3:              | LBB0_7:                                 ## while (i < top)
        //  0x00c3:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[97] = 16'hff50;
        sram.MEM[98] = 16'h05fc;
        sram.MEM[99] = 16'hffff;
        //  0x00c9:2002          |     rrmovl %eax, %edx
        sram.MEM[100] = 16'hff20;
        //  0x00cb:5015f4ffffff  |     mrmovl -12(%ebp), %ecx
        sram.MEM[101] = 16'h0250;
        sram.MEM[102] = 16'h15f4;
        sram.MEM[103] = 16'hffff;
        //  0x00d1:6112          |     subl %ecx, %edx
        sram.MEM[104] = 16'hff61;
        //  0x00d3:7556010000    |     jge	LBB0_11
        sram.MEM[105] = 16'h1275;
        sram.MEM[106] = 16'h5601;
        sram.MEM[107] = 16'h0000;
        //                       |
        //                       | ## BB#8:                                ## if (sortlist[i] > sortlist[i+1])
        //  0x00d8:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[108] = 16'h5005;
        sram.MEM[109] = 16'hfcff;
        sram.MEM[110] = 16'hffff;
        //  0x00de:c4f004000000  |     imull $4, %eax  # 4 bytes por posicao
        sram.MEM[111] = 16'hc4f0;
        sram.MEM[112] = 16'h0400;
        sram.MEM[113] = 16'h0000;
        //  0x00e4:502014000000  |     mrmovl Array(%eax), %edx  # sortlist[i]
        sram.MEM[114] = 16'h5020;
        sram.MEM[115] = 16'h1400;
        sram.MEM[116] = 16'h0000;
        //  0x00ea:c0f004000000  |     iaddl $4, %eax  # posicao i+1
        sram.MEM[117] = 16'hc0f0;
        sram.MEM[118] = 16'h0400;
        sram.MEM[119] = 16'h0000;
        //  0x00f0:501014000000  |     mrmovl Array(%eax), %ecx  # sortlist[i+1]
        sram.MEM[120] = 16'h5010;
        sram.MEM[121] = 16'h1400;
        sram.MEM[122] = 16'h0000;
        //  0x00f6:6112          |     subl %ecx, %edx
        sram.MEM[123] = 16'h6112;
        //  0x00f8:713f010000    |     jle	LBB0_10
        sram.MEM[124] = 16'h713f;
        sram.MEM[125] = 16'h0100;
        //                       |
        //                       |
        //                       | ## BB#9:
        //                       |     #j = sortlist[i]
        //  0x00fd:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[126] = 16'h0050;
        sram.MEM[127] = 16'h05fc;
        sram.MEM[128] = 16'hffff;
        //  0x0103:c4f004000000  |     imull $4, %eax  # 4 bytes por posicao
        sram.MEM[129] = 16'hffc4;
        sram.MEM[130] = 16'hf004;
        sram.MEM[131] = 16'h0000;
        //  0x0109:502014000000  |     mrmovl Array(%eax), %edx   # sortlist[i]
        sram.MEM[132] = 16'h0050;
        sram.MEM[133] = 16'h2014;
        sram.MEM[134] = 16'h0000;
        //  0x010f:4025f8ffffff  |     rmmovl %edx, -8(%ebp)  # j = sortlist[i]
        sram.MEM[135] = 16'h0040;
        sram.MEM[136] = 16'h25f8;
        sram.MEM[137] = 16'hffff;
        //                       |
        //                       |     #sortlist[i] = sortlist[i+1]
        //  0x0115:5015fcffffff  |     mrmovl -4(%ebp), %ecx
        sram.MEM[138] = 16'hff50;
        sram.MEM[139] = 16'h15fc;
        sram.MEM[140] = 16'hffff;
        //  0x011b:c0f101000000  |     iaddl $1, %ecx
        sram.MEM[141] = 16'hffc0;
        sram.MEM[142] = 16'hf101;
        sram.MEM[143] = 16'h0000;
        //  0x0121:c4f104000000  |     imull $4, %ecx  # 4 bytes por posicao
        sram.MEM[144] = 16'h00c4;
        sram.MEM[145] = 16'hf104;
        sram.MEM[146] = 16'h0000;
        //  0x0127:502114000000  |     mrmovl Array(%ecx), %edx
        sram.MEM[147] = 16'h0050;
        sram.MEM[148] = 16'h2114;
        sram.MEM[149] = 16'h0000;
        //  0x012d:402014000000  |     rmmovl %edx, Array(%eax) # sortlist[i] ja esta em Array(%eax)
        sram.MEM[150] = 16'h0040;
        sram.MEM[151] = 16'h2014;
        sram.MEM[152] = 16'h0000;
        //                       |
        //                       |     #sortlist[i+1] = j
        //  0x0133:5005f8ffffff  |     mrmovl -8(%ebp), %eax
        sram.MEM[153] = 16'h0050;
        sram.MEM[154] = 16'h05f8;
        sram.MEM[155] = 16'hffff;
        //  0x0139:400114000000  |     rmmovl %eax, Array(%ecx)
        sram.MEM[156] = 16'hff40;
        sram.MEM[157] = 16'h0114;
        sram.MEM[158] = 16'h0000;
        //                       |
        //  0x013f:              | LBB0_10:                                ## i = i + 1
        //  0x013f:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[159] = 16'h0050;
        sram.MEM[160] = 16'h05fc;
        sram.MEM[161] = 16'hffff;
        //  0x0145:c0f001000000  |     iaddl $1, %eax
        sram.MEM[162] = 16'hffc0;
        sram.MEM[163] = 16'hf001;
        sram.MEM[164] = 16'h0000;
        //  0x014b:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[165] = 16'h0040;
        sram.MEM[166] = 16'h05fc;
        sram.MEM[167] = 16'hffff;
        //  0x0151:70c3000000    |     jmp LBB0_7
        sram.MEM[168] = 16'hff70;
        sram.MEM[169] = 16'hc300;
        sram.MEM[170] = 16'h0000;
        //                       |
        //  0x0156:              | LBB0_11:                                ## in Loop: Header=BB0_5 Depth=1
        //  0x0156:5005f4ffffff  |     mrmovl -12(%ebp), %eax
        sram.MEM[171] = 16'h5005;
        sram.MEM[172] = 16'hf4ff;
        sram.MEM[173] = 16'hffff;
        //  0x015c:c1f001000000  |     isubl $1, %eax
        sram.MEM[174] = 16'hc1f0;
        sram.MEM[175] = 16'h0100;
        sram.MEM[176] = 16'h0000;
        //  0x0162:4005f4ffffff  |     rmmovl %eax, -12(%ebp)
        sram.MEM[177] = 16'h4005;
        sram.MEM[178] = 16'hf4ff;
        sram.MEM[179] = 16'hffff;
        //  0x0168:70a6000000    |     jmp	LBB0_5
        sram.MEM[180] = 16'h70a6;
        sram.MEM[181] = 16'h0000;
        //                       |
        //  0x016d:              | LBB0_12:
        //  0x016d:30f000000000  |     irmovl	$0, %eax
        sram.MEM[182] = 16'h0030;
        sram.MEM[183] = 16'hf000;
        sram.MEM[184] = 16'h0000;
        //  0x0173:c0f40c000000  |     iaddl	$12, %esp
        sram.MEM[185] = 16'h00c0;
        sram.MEM[186] = 16'hf40c;
        sram.MEM[187] = 16'h0000;
        //  0x0179:b05f          |     popl	%ebp
        sram.MEM[188] = 16'h00b0;
        //  0x017b:90            |     ret
        sram.MEM[189] = 16'h5f90;
        //                       |
        //  0x0f00:              |     .pos 0xF00
        //  0x0f00:              | Stack:
        #200000
        printMemByDE2Index(10, 30);
        // Little-endian values in memory...
        checkMemByDE2Index(10, 16'h0100, 1800);
        checkMemByDE2Index(11, 16'h0000, 1801);
        checkMemByDE2Index(12, 16'h0200, 1802);
        checkMemByDE2Index(13, 16'h0000, 1803);
        checkMemByDE2Index(14, 16'h0300, 1804);
        checkMemByDE2Index(15, 16'h0000, 1805);
        checkMemByDE2Index(16, 16'h0400, 1806);
        checkMemByDE2Index(17, 16'h0000, 1807);
        checkMemByDE2Index(18, 16'h0500, 1808);
        checkMemByDE2Index(19, 16'h0000, 1809);
        checkMemByDE2Index(20, 16'h0600, 1810);
        checkMemByDE2Index(21, 16'h0000, 1811);
        checkMemByDE2Index(22, 16'h0700, 1812);
        checkMemByDE2Index(23, 16'h0000, 1813);
        checkMemByDE2Index(24, 16'h0800, 1814);
        checkMemByDE2Index(25, 16'h0000, 1815);
        checkMemByDE2Index(26, 16'h0900, 1816);
        checkMemByDE2Index(27, 16'h0000, 1817);
        checkMemByDE2Index(28, 16'h0a00, 1818);
        checkMemByDE2Index(29, 16'h0000, 1819);


        // --- Test Bubblesort 10 elements INFINITE loop ------------------------//
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        //  0x0000:              |     .pos 0
        //                       |
        //  0x0000:              | Init:
        //  0x0000:30f4000f0000  |     irmovl Stack, %esp
        sram.MEM[0] = 16'h30f4;
        sram.MEM[1] = 16'h000f;
        sram.MEM[2] = 16'h0000;
        //  0x0006:30f5000f0000  |     irmovl Stack, %ebp
        sram.MEM[3] = 16'h30f5;
        sram.MEM[4] = 16'h000f;
        sram.MEM[5] = 16'h0000;
        //  0x000c:803c000000    |     call Main
        sram.MEM[6] = 16'h803c;
        sram.MEM[7] = 16'h0000;
        //  0x0011:10            |     halt
        sram.MEM[8] = 16'h0010;
        //                       |
        //  0x0014:              |     .align 4
        //  0x0014:              | Array:
        //  0x0014:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[10] = 16'hd204;
        sram.MEM[11] = 16'h0000;
        //  0x0018:2e160000      |     .long	5678                    ##
        sram.MEM[12] = 16'h2e16;
        sram.MEM[13] = 16'h0000;
        //  0x001c:00000000      |     .long	0                       ## 0x0
        sram.MEM[14] = 16'h0000;
        sram.MEM[15] = 16'h0000;
        //  0x0020:00000000      |     .long	0                       ## 0x0
        sram.MEM[16] = 16'h0000;
        sram.MEM[17] = 16'h0000;
        //  0x0024:00000000      |     .long	0                       ## 0x0
        sram.MEM[18] = 16'h0000;
        sram.MEM[19] = 16'h0000;
        //  0x0028:00000000      |     .long	0                       ## 0x0
        sram.MEM[20] = 16'h0000;
        sram.MEM[21] = 16'h0000;
        //  0x002c:00000000      |     .long	0                       ## 0x0
        sram.MEM[22] = 16'h0000;
        sram.MEM[23] = 16'h0000;
        //  0x0030:00000000      |     .long	0                       ## 0x0
        sram.MEM[24] = 16'h0000;
        sram.MEM[25] = 16'h0000;
        //  0x0034:00000000      |     .long	0                       ## 0x0
        sram.MEM[26] = 16'h0000;
        sram.MEM[27] = 16'h0000;
        //  0x0038:00000000      |     .long	0                       ## 0x0
        sram.MEM[28] = 16'h0000;
        sram.MEM[29] = 16'h0000;
        //                       |
        //  0x003c:              | Main:
        //  0x003c:a05f          |     pushl	%ebp
        sram.MEM[30] = 16'ha05f;
        //  0x003e:2045          |     rrmovl	%esp, %ebp
        sram.MEM[31] = 16'h2045;
        //  0x0040:c1f40c000000  |     isubl	$12, %esp
        sram.MEM[32] = 16'hc1f4;
        sram.MEM[33] = 16'h0c00;
        sram.MEM[34] = 16'h0000;
        //                       |
        //  0x0046:              | LBB0_0:
        //  0x0046:30f000000000  |     irmovl $0, %eax
        sram.MEM[35] = 16'h30f0;
        sram.MEM[36] = 16'h0000;
        sram.MEM[37] = 16'h0000;
        //  0x004c:4005fcffffff  |     rmmovl %eax, -4(%ebp) # inicializa i, j
        sram.MEM[38] = 16'h4005;
        sram.MEM[39] = 16'hfcff;
        sram.MEM[40] = 16'hffff;
        //  0x0052:4005f8ffffff  |     rmmovl %eax, -8(%ebp)
        sram.MEM[41] = 16'h4005;
        sram.MEM[42] = 16'hf8ff;
        sram.MEM[43] = 16'hffff;
        //                       |
        //  0x0058:              | LBB0_1:                                 ## inicializa array
        //  0x0058:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[44] = 16'h5005;
        sram.MEM[45] = 16'hfcff;
        sram.MEM[46] = 16'hffff;
        //  0x005e:c1f00a000000  |     isubl $10, %eax
        sram.MEM[47] = 16'hc1f0;
        sram.MEM[48] = 16'h0a00;
        sram.MEM[49] = 16'h0000;
        //  0x0064:759a000000    |     jge LBB0_4
        sram.MEM[50] = 16'h759a;
        sram.MEM[51] = 16'h0000;
        //                       |
        //                       | ## BB#2:                                ## attribui valores em ordem decrescente
        //  0x0069:30f00a000000  |     irmovl $10, %eax
        sram.MEM[52] = 16'h0030;
        sram.MEM[53] = 16'hf00a;
        sram.MEM[54] = 16'h0000;
        //  0x006f:5015fcffffff  |     mrmovl -4(%ebp), %ecx
        sram.MEM[55] = 16'h0050;
        sram.MEM[56] = 16'h15fc;
        sram.MEM[57] = 16'hffff;
        //  0x0075:6110          |     subl %ecx, %eax
        sram.MEM[58] = 16'hff61;
        //  0x0077:c4f104000000  |     imull $4, %ecx # 4 bytes por posicao
        sram.MEM[59] = 16'h10c4;
        sram.MEM[60] = 16'hf104;
        sram.MEM[61] = 16'h0000;
        //  0x007d:400114000000  |     rmmovl %eax, Array(%ecx)
        sram.MEM[62] = 16'h0040;
        sram.MEM[63] = 16'h0114;
        sram.MEM[64] = 16'h0000;
        //                       |
        //                       | ## BB#3:                                ## proxima iteracao de inicializacao
        //  0x0083:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[65] = 16'h0050;
        sram.MEM[66] = 16'h05fc;
        sram.MEM[67] = 16'hffff;
        //  0x0089:c0f001000000  |     iaddl $1, %eax
        sram.MEM[68] = 16'hffc0;
        sram.MEM[69] = 16'hf001;
        sram.MEM[70] = 16'h0000;
        //  0x008f:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[71] = 16'h0040;
        sram.MEM[72] = 16'h05fc;
        sram.MEM[73] = 16'hffff;
        //  0x0095:7058000000    |     jmp LBB0_1
        sram.MEM[74] = 16'hff70;
        sram.MEM[75] = 16'h5800;
        sram.MEM[76] = 16'h0000;
        //                       |
        //                       |
        //  0x009a:              | LBB0_4:
        //  0x009a:30f209000000  |     irmovl $9, %edx
        sram.MEM[77] = 16'h30f2;
        sram.MEM[78] = 16'h0900;
        sram.MEM[79] = 16'h0000;
        //  0x00a0:4025f4ffffff  |     rmmovl %edx, -12(%ebp)
        sram.MEM[80] = 16'h4025;
        sram.MEM[81] = 16'hf4ff;
        sram.MEM[82] = 16'hffff;
        //                       |
        //  0x00a6:              | LBB0_5:                                 ## while (top>0)
        //  0x00a6:5025f4ffffff  |     mrmovl -12(%ebp), %edx
        sram.MEM[83] = 16'h5025;
        sram.MEM[84] = 16'hf4ff;
        sram.MEM[85] = 16'hffff;
        //  0x00ac:c1f200000000  |     isubl $0, %edx
        sram.MEM[86] = 16'hc1f2;
        sram.MEM[87] = 16'h0000;
        sram.MEM[88] = 16'h0000;
        //  0x00b2:7146000000    |     jle LBB0_0
        sram.MEM[89] = 16'h7146;
        sram.MEM[90] = 16'h0000;
        //                       |
        //                       | ## BB#6:                                ## i = 0
        //  0x00b7:30f000000000  |     irmovl $0, %eax
        sram.MEM[91] = 16'h0030;
        sram.MEM[92] = 16'hf000;
        sram.MEM[93] = 16'h0000;
        //  0x00bd:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[94] = 16'h0040;
        sram.MEM[95] = 16'h05fc;
        sram.MEM[96] = 16'hffff;
        //                       |
        //  0x00c3:              | LBB0_7:                                 ## while (i < top)
        //  0x00c3:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[97] = 16'hff50;
        sram.MEM[98] = 16'h05fc;
        sram.MEM[99] = 16'hffff;
        //  0x00c9:2002          |     rrmovl %eax, %edx
        sram.MEM[100] = 16'hff20;
        //  0x00cb:5015f4ffffff  |     mrmovl -12(%ebp), %ecx
        sram.MEM[101] = 16'h0250;
        sram.MEM[102] = 16'h15f4;
        sram.MEM[103] = 16'hffff;
        //  0x00d1:6112          |     subl %ecx, %edx
        sram.MEM[104] = 16'hff61;
        //  0x00d3:7556010000    |     jge	LBB0_11
        sram.MEM[105] = 16'h1275;
        sram.MEM[106] = 16'h5601;
        sram.MEM[107] = 16'h0000;
        //                       |
        //                       | ## BB#8:                                ## if (sortlist[i] > sortlist[i+1])
        //  0x00d8:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[108] = 16'h5005;
        sram.MEM[109] = 16'hfcff;
        sram.MEM[110] = 16'hffff;
        //  0x00de:c4f004000000  |     imull $4, %eax  # 4 bytes por posicao
        sram.MEM[111] = 16'hc4f0;
        sram.MEM[112] = 16'h0400;
        sram.MEM[113] = 16'h0000;
        //  0x00e4:502014000000  |     mrmovl Array(%eax), %edx  # sortlist[i]
        sram.MEM[114] = 16'h5020;
        sram.MEM[115] = 16'h1400;
        sram.MEM[116] = 16'h0000;
        //  0x00ea:c0f004000000  |     iaddl $4, %eax  # posicao i+1
        sram.MEM[117] = 16'hc0f0;
        sram.MEM[118] = 16'h0400;
        sram.MEM[119] = 16'h0000;
        //  0x00f0:501014000000  |     mrmovl Array(%eax), %ecx  # sortlist[i+1]
        sram.MEM[120] = 16'h5010;
        sram.MEM[121] = 16'h1400;
        sram.MEM[122] = 16'h0000;
        //  0x00f6:6112          |     subl %ecx, %edx
        sram.MEM[123] = 16'h6112;
        //  0x00f8:713f010000    |     jle	LBB0_10
        sram.MEM[124] = 16'h713f;
        sram.MEM[125] = 16'h0100;
        //                       |
        //                       |
        //                       | ## BB#9:
        //                       |     #j = sortlist[i]
        //  0x00fd:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[126] = 16'h0050;
        sram.MEM[127] = 16'h05fc;
        sram.MEM[128] = 16'hffff;
        //  0x0103:c4f004000000  |     imull $4, %eax  # 4 bytes por posicao
        sram.MEM[129] = 16'hffc4;
        sram.MEM[130] = 16'hf004;
        sram.MEM[131] = 16'h0000;
        //  0x0109:502014000000  |     mrmovl Array(%eax), %edx   # sortlist[i]
        sram.MEM[132] = 16'h0050;
        sram.MEM[133] = 16'h2014;
        sram.MEM[134] = 16'h0000;
        //  0x010f:4025f8ffffff  |     rmmovl %edx, -8(%ebp)  # j = sortlist[i]
        sram.MEM[135] = 16'h0040;
        sram.MEM[136] = 16'h25f8;
        sram.MEM[137] = 16'hffff;
        //                       |
        //                       |     #sortlist[i] = sortlist[i+1]
        //  0x0115:5015fcffffff  |     mrmovl -4(%ebp), %ecx
        sram.MEM[138] = 16'hff50;
        sram.MEM[139] = 16'h15fc;
        sram.MEM[140] = 16'hffff;
        //  0x011b:c0f101000000  |     iaddl $1, %ecx
        sram.MEM[141] = 16'hffc0;
        sram.MEM[142] = 16'hf101;
        sram.MEM[143] = 16'h0000;
        //  0x0121:c4f104000000  |     imull $4, %ecx  # 4 bytes por posicao
        sram.MEM[144] = 16'h00c4;
        sram.MEM[145] = 16'hf104;
        sram.MEM[146] = 16'h0000;
        //  0x0127:502114000000  |     mrmovl Array(%ecx), %edx
        sram.MEM[147] = 16'h0050;
        sram.MEM[148] = 16'h2114;
        sram.MEM[149] = 16'h0000;
        //  0x012d:402014000000  |     rmmovl %edx, Array(%eax) # sortlist[i] ja esta em Array(%eax)
        sram.MEM[150] = 16'h0040;
        sram.MEM[151] = 16'h2014;
        sram.MEM[152] = 16'h0000;
        //                       |
        //                       |     #sortlist[i+1] = j
        //  0x0133:5005f8ffffff  |     mrmovl -8(%ebp), %eax
        sram.MEM[153] = 16'h0050;
        sram.MEM[154] = 16'h05f8;
        sram.MEM[155] = 16'hffff;
        //  0x0139:400114000000  |     rmmovl %eax, Array(%ecx)
        sram.MEM[156] = 16'hff40;
        sram.MEM[157] = 16'h0114;
        sram.MEM[158] = 16'h0000;
        //                       |
        //  0x013f:              | LBB0_10:                                ## i = i + 1
        //  0x013f:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[159] = 16'h0050;
        sram.MEM[160] = 16'h05fc;
        sram.MEM[161] = 16'hffff;
        //  0x0145:c0f001000000  |     iaddl $1, %eax
        sram.MEM[162] = 16'hffc0;
        sram.MEM[163] = 16'hf001;
        sram.MEM[164] = 16'h0000;
        //  0x014b:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[165] = 16'h0040;
        sram.MEM[166] = 16'h05fc;
        sram.MEM[167] = 16'hffff;
        //  0x0151:70c3000000    |     jmp LBB0_7
        sram.MEM[168] = 16'hff70;
        sram.MEM[169] = 16'hc300;
        sram.MEM[170] = 16'h0000;
        //                       |
        //  0x0156:              | LBB0_11:                                ## in Loop: Header=BB0_5 Depth=1
        //  0x0156:5005f4ffffff  |     mrmovl -12(%ebp), %eax
        sram.MEM[171] = 16'h5005;
        sram.MEM[172] = 16'hf4ff;
        sram.MEM[173] = 16'hffff;
        //  0x015c:c1f001000000  |     isubl $1, %eax
        sram.MEM[174] = 16'hc1f0;
        sram.MEM[175] = 16'h0100;
        sram.MEM[176] = 16'h0000;
        //  0x0162:4005f4ffffff  |     rmmovl %eax, -12(%ebp)
        sram.MEM[177] = 16'h4005;
        sram.MEM[178] = 16'hf4ff;
        sram.MEM[179] = 16'hffff;
        //  0x0168:70a6000000    |     jmp	LBB0_5
        sram.MEM[180] = 16'h70a6;
        sram.MEM[181] = 16'h0000;
        //                       |
        //  0x016d:              | LBB0_12:
        //  0x016d:30f000000000  |     irmovl	$0, %eax
        sram.MEM[182] = 16'h0030;
        sram.MEM[183] = 16'hf000;
        sram.MEM[184] = 16'h0000;
        //  0x0173:c0f40c000000  |     iaddl	$12, %esp
        sram.MEM[185] = 16'h00c0;
        sram.MEM[186] = 16'hf40c;
        sram.MEM[187] = 16'h0000;
        //  0x0179:b05f          |     popl	%ebp
        sram.MEM[188] = 16'h00b0;
        //  0x017b:90            |     ret
        sram.MEM[189] = 16'h5f90;
        for (k = 0; k < 30; k = k + 1) begin
            #5000
            printMemByDE2Index(10, 30);
            $display("");
        end


        // --- Teste Bubblesort 100 elements --------------------------------//
        cleanMem;
        #10 Mode = 2'h1;
        #10 Mode = 2'h0; // Reset
        //  0x0000:              |     .pos 0
        //                       |
        //  0x0000:              | Init:
        //  0x0000:30f4000f0000  |     irmovl Stack, %esp
        sram.MEM[0] = 16'h30f4;
        sram.MEM[1] = 16'h000f;
        sram.MEM[2] = 16'h0000;
        //  0x0006:30f5000f0000  |     irmovl Stack, %ebp
        sram.MEM[3] = 16'h30f5;
        sram.MEM[4] = 16'h000f;
        sram.MEM[5] = 16'h0000;
        //  0x000c:80a4010000    |     call Main
        sram.MEM[6] = 16'h80a4;
        sram.MEM[7] = 16'h0100;
        //  0x0011:10            |     halt
        sram.MEM[8] = 16'h0010;
        //                       |
        //  0x0014:              |     .align 4
        //  0x0014:              | Array:
        //  0x0014:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[10] = 16'hd204;
        sram.MEM[11] = 16'h0000;
        //  0x0018:2e160000      |     .long	5678                    ##
        sram.MEM[12] = 16'h2e16;
        sram.MEM[13] = 16'h0000;
        //  0x001c:00000000      |     .long	0                       ## 0x0
        sram.MEM[14] = 16'h0000;
        sram.MEM[15] = 16'h0000;
        //  0x0020:00000000      |     .long	0                       ## 0x0
        sram.MEM[16] = 16'h0000;
        sram.MEM[17] = 16'h0000;
        //  0x0024:00000000      |     .long	0                       ## 0x0
        sram.MEM[18] = 16'h0000;
        sram.MEM[19] = 16'h0000;
        //  0x0028:00000000      |     .long	0                       ## 0x0
        sram.MEM[20] = 16'h0000;
        sram.MEM[21] = 16'h0000;
        //  0x002c:00000000      |     .long	0                       ## 0x0
        sram.MEM[22] = 16'h0000;
        sram.MEM[23] = 16'h0000;
        //  0x0030:00000000      |     .long	0                       ## 0x0
        sram.MEM[24] = 16'h0000;
        sram.MEM[25] = 16'h0000;
        //  0x0034:00000000      |     .long	0                       ## 0x0
        sram.MEM[26] = 16'h0000;
        sram.MEM[27] = 16'h0000;
        //  0x0038:00000000      |     .long	0                       ## 0x0
        sram.MEM[28] = 16'h0000;
        sram.MEM[29] = 16'h0000;
        //  0x003c:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[30] = 16'hd204;
        sram.MEM[31] = 16'h0000;
        //  0x0040:2e160000      |     .long	5678                    ##
        sram.MEM[32] = 16'h2e16;
        sram.MEM[33] = 16'h0000;
        //  0x0044:00000000      |     .long	0                       ## 0x0
        sram.MEM[34] = 16'h0000;
        sram.MEM[35] = 16'h0000;
        //  0x0048:00000000      |     .long	0                       ## 0x0
        sram.MEM[36] = 16'h0000;
        sram.MEM[37] = 16'h0000;
        //  0x004c:00000000      |     .long	0                       ## 0x0
        sram.MEM[38] = 16'h0000;
        sram.MEM[39] = 16'h0000;
        //  0x0050:00000000      |     .long	0                       ## 0x0
        sram.MEM[40] = 16'h0000;
        sram.MEM[41] = 16'h0000;
        //  0x0054:00000000      |     .long	0                       ## 0x0
        sram.MEM[42] = 16'h0000;
        sram.MEM[43] = 16'h0000;
        //  0x0058:00000000      |     .long	0                       ## 0x0
        sram.MEM[44] = 16'h0000;
        sram.MEM[45] = 16'h0000;
        //  0x005c:00000000      |     .long	0                       ## 0x0
        sram.MEM[46] = 16'h0000;
        sram.MEM[47] = 16'h0000;
        //  0x0060:00000000      |     .long	0                       ## 0x0
        sram.MEM[48] = 16'h0000;
        sram.MEM[49] = 16'h0000;
        //  0x0064:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[50] = 16'hd204;
        sram.MEM[51] = 16'h0000;
        //  0x0068:2e160000      |     .long	5678                    ##
        sram.MEM[52] = 16'h2e16;
        sram.MEM[53] = 16'h0000;
        //  0x006c:00000000      |     .long	0                       ## 0x0
        sram.MEM[54] = 16'h0000;
        sram.MEM[55] = 16'h0000;
        //  0x0070:00000000      |     .long	0                       ## 0x0
        sram.MEM[56] = 16'h0000;
        sram.MEM[57] = 16'h0000;
        //  0x0074:00000000      |     .long	0                       ## 0x0
        sram.MEM[58] = 16'h0000;
        sram.MEM[59] = 16'h0000;
        //  0x0078:00000000      |     .long	0                       ## 0x0
        sram.MEM[60] = 16'h0000;
        sram.MEM[61] = 16'h0000;
        //  0x007c:00000000      |     .long	0                       ## 0x0
        sram.MEM[62] = 16'h0000;
        sram.MEM[63] = 16'h0000;
        //  0x0080:00000000      |     .long	0                       ## 0x0
        sram.MEM[64] = 16'h0000;
        sram.MEM[65] = 16'h0000;
        //  0x0084:00000000      |     .long	0                       ## 0x0
        sram.MEM[66] = 16'h0000;
        sram.MEM[67] = 16'h0000;
        //  0x0088:00000000      |     .long	0                       ## 0x0
        sram.MEM[68] = 16'h0000;
        sram.MEM[69] = 16'h0000;
        //  0x008c:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[70] = 16'hd204;
        sram.MEM[71] = 16'h0000;
        //  0x0090:2e160000      |     .long	5678                    ##
        sram.MEM[72] = 16'h2e16;
        sram.MEM[73] = 16'h0000;
        //  0x0094:00000000      |     .long	0                       ## 0x0
        sram.MEM[74] = 16'h0000;
        sram.MEM[75] = 16'h0000;
        //  0x0098:00000000      |     .long	0                       ## 0x0
        sram.MEM[76] = 16'h0000;
        sram.MEM[77] = 16'h0000;
        //  0x009c:00000000      |     .long	0                       ## 0x0
        sram.MEM[78] = 16'h0000;
        sram.MEM[79] = 16'h0000;
        //  0x00a0:00000000      |     .long	0                       ## 0x0
        sram.MEM[80] = 16'h0000;
        sram.MEM[81] = 16'h0000;
        //  0x00a4:00000000      |     .long	0                       ## 0x0
        sram.MEM[82] = 16'h0000;
        sram.MEM[83] = 16'h0000;
        //  0x00a8:00000000      |     .long	0                       ## 0x0
        sram.MEM[84] = 16'h0000;
        sram.MEM[85] = 16'h0000;
        //  0x00ac:00000000      |     .long	0                       ## 0x0
        sram.MEM[86] = 16'h0000;
        sram.MEM[87] = 16'h0000;
        //  0x00b0:00000000      |     .long	0                       ## 0x0
        sram.MEM[88] = 16'h0000;
        sram.MEM[89] = 16'h0000;
        //  0x00b4:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[90] = 16'hd204;
        sram.MEM[91] = 16'h0000;
        //  0x00b8:2e160000      |     .long	5678                    ##
        sram.MEM[92] = 16'h2e16;
        sram.MEM[93] = 16'h0000;
        //  0x00bc:00000000      |     .long	0                       ## 0x0
        sram.MEM[94] = 16'h0000;
        sram.MEM[95] = 16'h0000;
        //  0x00c0:00000000      |     .long	0                       ## 0x0
        sram.MEM[96] = 16'h0000;
        sram.MEM[97] = 16'h0000;
        //  0x00c4:00000000      |     .long	0                       ## 0x0
        sram.MEM[98] = 16'h0000;
        sram.MEM[99] = 16'h0000;
        //  0x00c8:00000000      |     .long	0                       ## 0x0
        sram.MEM[100] = 16'h0000;
        sram.MEM[101] = 16'h0000;
        //  0x00cc:00000000      |     .long	0                       ## 0x0
        sram.MEM[102] = 16'h0000;
        sram.MEM[103] = 16'h0000;
        //  0x00d0:00000000      |     .long	0                       ## 0x0
        sram.MEM[104] = 16'h0000;
        sram.MEM[105] = 16'h0000;
        //  0x00d4:00000000      |     .long	0                       ## 0x0
        sram.MEM[106] = 16'h0000;
        sram.MEM[107] = 16'h0000;
        //  0x00d8:00000000      |     .long	0                       ## 0x0
        sram.MEM[108] = 16'h0000;
        sram.MEM[109] = 16'h0000;
        //  0x00dc:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[110] = 16'hd204;
        sram.MEM[111] = 16'h0000;
        //  0x00e0:2e160000      |     .long	5678                    ##
        sram.MEM[112] = 16'h2e16;
        sram.MEM[113] = 16'h0000;
        //  0x00e4:00000000      |     .long	0                       ## 0x0
        sram.MEM[114] = 16'h0000;
        sram.MEM[115] = 16'h0000;
        //  0x00e8:00000000      |     .long	0                       ## 0x0
        sram.MEM[116] = 16'h0000;
        sram.MEM[117] = 16'h0000;
        //  0x00ec:00000000      |     .long	0                       ## 0x0
        sram.MEM[118] = 16'h0000;
        sram.MEM[119] = 16'h0000;
        //  0x00f0:00000000      |     .long	0                       ## 0x0
        sram.MEM[120] = 16'h0000;
        sram.MEM[121] = 16'h0000;
        //  0x00f4:00000000      |     .long	0                       ## 0x0
        sram.MEM[122] = 16'h0000;
        sram.MEM[123] = 16'h0000;
        //  0x00f8:00000000      |     .long	0                       ## 0x0
        sram.MEM[124] = 16'h0000;
        sram.MEM[125] = 16'h0000;
        //  0x00fc:00000000      |     .long	0                       ## 0x0
        sram.MEM[126] = 16'h0000;
        sram.MEM[127] = 16'h0000;
        //  0x0100:00000000      |     .long	0                       ## 0x0
        sram.MEM[128] = 16'h0000;
        sram.MEM[129] = 16'h0000;
        //  0x0104:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[130] = 16'hd204;
        sram.MEM[131] = 16'h0000;
        //  0x0108:2e160000      |     .long	5678                    ##
        sram.MEM[132] = 16'h2e16;
        sram.MEM[133] = 16'h0000;
        //  0x010c:00000000      |     .long	0                       ## 0x0
        sram.MEM[134] = 16'h0000;
        sram.MEM[135] = 16'h0000;
        //  0x0110:00000000      |     .long	0                       ## 0x0
        sram.MEM[136] = 16'h0000;
        sram.MEM[137] = 16'h0000;
        //  0x0114:00000000      |     .long	0                       ## 0x0
        sram.MEM[138] = 16'h0000;
        sram.MEM[139] = 16'h0000;
        //  0x0118:00000000      |     .long	0                       ## 0x0
        sram.MEM[140] = 16'h0000;
        sram.MEM[141] = 16'h0000;
        //  0x011c:00000000      |     .long	0                       ## 0x0
        sram.MEM[142] = 16'h0000;
        sram.MEM[143] = 16'h0000;
        //  0x0120:00000000      |     .long	0                       ## 0x0
        sram.MEM[144] = 16'h0000;
        sram.MEM[145] = 16'h0000;
        //  0x0124:00000000      |     .long	0                       ## 0x0
        sram.MEM[146] = 16'h0000;
        sram.MEM[147] = 16'h0000;
        //  0x0128:00000000      |     .long	0                       ## 0x0
        sram.MEM[148] = 16'h0000;
        sram.MEM[149] = 16'h0000;
        //  0x012c:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[150] = 16'hd204;
        sram.MEM[151] = 16'h0000;
        //  0x0130:2e160000      |     .long	5678                    ##
        sram.MEM[152] = 16'h2e16;
        sram.MEM[153] = 16'h0000;
        //  0x0134:00000000      |     .long	0                       ## 0x0
        sram.MEM[154] = 16'h0000;
        sram.MEM[155] = 16'h0000;
        //  0x0138:00000000      |     .long	0                       ## 0x0
        sram.MEM[156] = 16'h0000;
        sram.MEM[157] = 16'h0000;
        //  0x013c:00000000      |     .long	0                       ## 0x0
        sram.MEM[158] = 16'h0000;
        sram.MEM[159] = 16'h0000;
        //  0x0140:00000000      |     .long	0                       ## 0x0
        sram.MEM[160] = 16'h0000;
        sram.MEM[161] = 16'h0000;
        //  0x0144:00000000      |     .long	0                       ## 0x0
        sram.MEM[162] = 16'h0000;
        sram.MEM[163] = 16'h0000;
        //  0x0148:00000000      |     .long	0                       ## 0x0
        sram.MEM[164] = 16'h0000;
        sram.MEM[165] = 16'h0000;
        //  0x014c:00000000      |     .long	0                       ## 0x0
        sram.MEM[166] = 16'h0000;
        sram.MEM[167] = 16'h0000;
        //  0x0150:00000000      |     .long	0                       ## 0x0
        sram.MEM[168] = 16'h0000;
        sram.MEM[169] = 16'h0000;
        //  0x0154:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[170] = 16'hd204;
        sram.MEM[171] = 16'h0000;
        //  0x0158:2e160000      |     .long	5678                    ##
        sram.MEM[172] = 16'h2e16;
        sram.MEM[173] = 16'h0000;
        //  0x015c:00000000      |     .long	0                       ## 0x0
        sram.MEM[174] = 16'h0000;
        sram.MEM[175] = 16'h0000;
        //  0x0160:00000000      |     .long	0                       ## 0x0
        sram.MEM[176] = 16'h0000;
        sram.MEM[177] = 16'h0000;
        //  0x0164:00000000      |     .long	0                       ## 0x0
        sram.MEM[178] = 16'h0000;
        sram.MEM[179] = 16'h0000;
        //  0x0168:00000000      |     .long	0                       ## 0x0
        sram.MEM[180] = 16'h0000;
        sram.MEM[181] = 16'h0000;
        //  0x016c:00000000      |     .long	0                       ## 0x0
        sram.MEM[182] = 16'h0000;
        sram.MEM[183] = 16'h0000;
        //  0x0170:00000000      |     .long	0                       ## 0x0
        sram.MEM[184] = 16'h0000;
        sram.MEM[185] = 16'h0000;
        //  0x0174:00000000      |     .long	0                       ## 0x0
        sram.MEM[186] = 16'h0000;
        sram.MEM[187] = 16'h0000;
        //  0x0178:00000000      |     .long	0                       ## 0x0
        sram.MEM[188] = 16'h0000;
        sram.MEM[189] = 16'h0000;
        //  0x017c:d2040000      |     .long	1234                    ## 0x4d2
        sram.MEM[190] = 16'hd204;
        sram.MEM[191] = 16'h0000;
        //  0x0180:2e160000      |     .long	5678                    ##
        sram.MEM[192] = 16'h2e16;
        sram.MEM[193] = 16'h0000;
        //  0x0184:00000000      |     .long	0                       ## 0x0
        sram.MEM[194] = 16'h0000;
        sram.MEM[195] = 16'h0000;
        //  0x0188:00000000      |     .long	0                       ## 0x0
        sram.MEM[196] = 16'h0000;
        sram.MEM[197] = 16'h0000;
        //  0x018c:00000000      |     .long	0                       ## 0x0
        sram.MEM[198] = 16'h0000;
        sram.MEM[199] = 16'h0000;
        //  0x0190:00000000      |     .long	0                       ## 0x0
        sram.MEM[200] = 16'h0000;
        sram.MEM[201] = 16'h0000;
        //  0x0194:00000000      |     .long	0                       ## 0x0
        sram.MEM[202] = 16'h0000;
        sram.MEM[203] = 16'h0000;
        //  0x0198:00000000      |     .long	0                       ## 0x0
        sram.MEM[204] = 16'h0000;
        sram.MEM[205] = 16'h0000;
        //  0x019c:00000000      |     .long	0                       ## 0x0
        sram.MEM[206] = 16'h0000;
        sram.MEM[207] = 16'h0000;
        //  0x01a0:00000000      |     .long	0                       ## 0x0
        sram.MEM[208] = 16'h0000;
        sram.MEM[209] = 16'h0000;
        //                       |
        //  0x01a4:              | Main:
        //  0x01a4:a05f          |     pushl	%ebp
        sram.MEM[210] = 16'ha05f;
        //  0x01a6:2045          |     rrmovl	%esp, %ebp
        sram.MEM[211] = 16'h2045;
        //  0x01a8:c1f40c000000  |     isubl	$12, %esp
        sram.MEM[212] = 16'hc1f4;
        sram.MEM[213] = 16'h0c00;
        sram.MEM[214] = 16'h0000;
        //                       |
        //  0x01ae:30f000000000  |     irmovl $0, %eax
        sram.MEM[215] = 16'h30f0;
        sram.MEM[216] = 16'h0000;
        sram.MEM[217] = 16'h0000;
        //  0x01b4:4005fcffffff  |     rmmovl %eax, -4(%ebp) # inicializa i, j
        sram.MEM[218] = 16'h4005;
        sram.MEM[219] = 16'hfcff;
        sram.MEM[220] = 16'hffff;
        //  0x01ba:4005f8ffffff  |     rmmovl %eax, -8(%ebp)
        sram.MEM[221] = 16'h4005;
        sram.MEM[222] = 16'hf8ff;
        sram.MEM[223] = 16'hffff;
        //                       |
        //  0x01c0:              | LBB0_1:                                 ## inicializa array
        //  0x01c0:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[224] = 16'h5005;
        sram.MEM[225] = 16'hfcff;
        sram.MEM[226] = 16'hffff;
        //  0x01c6:c1f064000000  |     isubl $100, %eax
        sram.MEM[227] = 16'hc1f0;
        sram.MEM[228] = 16'h6400;
        sram.MEM[229] = 16'h0000;
        //  0x01cc:7502020000    |     jge LBB0_4
        sram.MEM[230] = 16'h7502;
        sram.MEM[231] = 16'h0200;
        //                       |
        //                       | ## BB#2:                                ## attribui valores em ordem decrescente
        //  0x01d1:30f064000000  |     irmovl $100, %eax
        sram.MEM[232] = 16'h0030;
        sram.MEM[233] = 16'hf064;
        sram.MEM[234] = 16'h0000;
        //  0x01d7:5015fcffffff  |     mrmovl -4(%ebp), %ecx
        sram.MEM[235] = 16'h0050;
        sram.MEM[236] = 16'h15fc;
        sram.MEM[237] = 16'hffff;
        //  0x01dd:6110          |     subl %ecx, %eax
        sram.MEM[238] = 16'hff61;
        //  0x01df:c4f104000000  |     imull $4, %ecx # 4 bytes por posicao
        sram.MEM[239] = 16'h10c4;
        sram.MEM[240] = 16'hf104;
        sram.MEM[241] = 16'h0000;
        //  0x01e5:400114000000  |     rmmovl %eax, Array(%ecx)
        sram.MEM[242] = 16'h0040;
        sram.MEM[243] = 16'h0114;
        sram.MEM[244] = 16'h0000;
        //                       |
        //                       | ## BB#3:                                ## proxima iteracao de inicializacao
        //  0x01eb:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[245] = 16'h0050;
        sram.MEM[246] = 16'h05fc;
        sram.MEM[247] = 16'hffff;
        //  0x01f1:c0f001000000  |     iaddl $1, %eax
        sram.MEM[248] = 16'hffc0;
        sram.MEM[249] = 16'hf001;
        sram.MEM[250] = 16'h0000;
        //  0x01f7:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[251] = 16'h0040;
        sram.MEM[252] = 16'h05fc;
        sram.MEM[253] = 16'hffff;
        //  0x01fd:70c0010000    |     jmp LBB0_1
        sram.MEM[254] = 16'hff70;
        sram.MEM[255] = 16'hc001;
        sram.MEM[256] = 16'h0000;
        //                       |
        //                       |
        //  0x0202:              | LBB0_4:
        //  0x0202:30f263000000  |     irmovl $99, %edx
        sram.MEM[257] = 16'h30f2;
        sram.MEM[258] = 16'h6300;
        sram.MEM[259] = 16'h0000;
        //  0x0208:4025f4ffffff  |     rmmovl %edx, -12(%ebp)
        sram.MEM[260] = 16'h4025;
        sram.MEM[261] = 16'hf4ff;
        sram.MEM[262] = 16'hffff;
        //                       |
        //  0x020e:              | LBB0_5:                                 ## while (top>0)
        //  0x020e:5025f4ffffff  |     mrmovl -12(%ebp), %edx
        sram.MEM[263] = 16'h5025;
        sram.MEM[264] = 16'hf4ff;
        sram.MEM[265] = 16'hffff;
        //  0x0214:c1f200000000  |     isubl $0, %edx
        sram.MEM[266] = 16'hc1f2;
        sram.MEM[267] = 16'h0000;
        sram.MEM[268] = 16'h0000;
        //  0x021a:71d5020000    |     jle LBB0_12
        sram.MEM[269] = 16'h71d5;
        sram.MEM[270] = 16'h0200;
        //                       |
        //                       | ## BB#6:                                ## i = 0
        //  0x021f:30f000000000  |     irmovl $0, %eax
        sram.MEM[271] = 16'h0030;
        sram.MEM[272] = 16'hf000;
        sram.MEM[273] = 16'h0000;
        //  0x0225:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[274] = 16'h0040;
        sram.MEM[275] = 16'h05fc;
        sram.MEM[276] = 16'hffff;
        //                       |
        //  0x022b:              | LBB0_7:                                 ## while (i < top)
        //  0x022b:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[277] = 16'hff50;
        sram.MEM[278] = 16'h05fc;
        sram.MEM[279] = 16'hffff;
        //  0x0231:2002          |     rrmovl %eax, %edx
        sram.MEM[280] = 16'hff20;
        //  0x0233:5015f4ffffff  |     mrmovl -12(%ebp), %ecx
        sram.MEM[281] = 16'h0250;
        sram.MEM[282] = 16'h15f4;
        sram.MEM[283] = 16'hffff;
        //  0x0239:6112          |     subl %ecx, %edx
        sram.MEM[284] = 16'hff61;
        //  0x023b:75be020000    |     jge	LBB0_11
        sram.MEM[285] = 16'h1275;
        sram.MEM[286] = 16'hbe02;
        sram.MEM[287] = 16'h0000;
        //                       |
        //                       | ## BB#8:                                ## if (sortlist[i] > sortlist[i+1])
        //  0x0240:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[288] = 16'h5005;
        sram.MEM[289] = 16'hfcff;
        sram.MEM[290] = 16'hffff;
        //  0x0246:c4f004000000  |     imull $4, %eax  # 4 bytes por posicao
        sram.MEM[291] = 16'hc4f0;
        sram.MEM[292] = 16'h0400;
        sram.MEM[293] = 16'h0000;
        //  0x024c:502014000000  |     mrmovl Array(%eax), %edx  # sortlist[i]
        sram.MEM[294] = 16'h5020;
        sram.MEM[295] = 16'h1400;
        sram.MEM[296] = 16'h0000;
        //  0x0252:c0f004000000  |     iaddl $4, %eax  # posicao i+1
        sram.MEM[297] = 16'hc0f0;
        sram.MEM[298] = 16'h0400;
        sram.MEM[299] = 16'h0000;
        //  0x0258:501014000000  |     mrmovl Array(%eax), %ecx  # sortlist[i+1]
        sram.MEM[300] = 16'h5010;
        sram.MEM[301] = 16'h1400;
        sram.MEM[302] = 16'h0000;
        //  0x025e:6112          |     subl %ecx, %edx
        sram.MEM[303] = 16'h6112;
        //  0x0260:71a7020000    |     jle	LBB0_10
        sram.MEM[304] = 16'h71a7;
        sram.MEM[305] = 16'h0200;
        //                       |
        //                       |
        //                       | ## BB#9:
        //                       |     #j = sortlist[i]
        //  0x0265:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[306] = 16'h0050;
        sram.MEM[307] = 16'h05fc;
        sram.MEM[308] = 16'hffff;
        //  0x026b:c4f004000000  |     imull $4, %eax  # 4 bytes por posicao
        sram.MEM[309] = 16'hffc4;
        sram.MEM[310] = 16'hf004;
        sram.MEM[311] = 16'h0000;
        //  0x0271:502014000000  |     mrmovl Array(%eax), %edx   # sortlist[i]
        sram.MEM[312] = 16'h0050;
        sram.MEM[313] = 16'h2014;
        sram.MEM[314] = 16'h0000;
        //  0x0277:4025f8ffffff  |     rmmovl %edx, -8(%ebp)  # j = sortlist[i]
        sram.MEM[315] = 16'h0040;
        sram.MEM[316] = 16'h25f8;
        sram.MEM[317] = 16'hffff;
        //                       |
        //                       |     #sortlist[i] = sortlist[i+1]
        //  0x027d:5015fcffffff  |     mrmovl -4(%ebp), %ecx
        sram.MEM[318] = 16'hff50;
        sram.MEM[319] = 16'h15fc;
        sram.MEM[320] = 16'hffff;
        //  0x0283:c0f101000000  |     iaddl $1, %ecx
        sram.MEM[321] = 16'hffc0;
        sram.MEM[322] = 16'hf101;
        sram.MEM[323] = 16'h0000;
        //  0x0289:c4f104000000  |     imull $4, %ecx  # 4 bytes por posicao
        sram.MEM[324] = 16'h00c4;
        sram.MEM[325] = 16'hf104;
        sram.MEM[326] = 16'h0000;
        //  0x028f:502114000000  |     mrmovl Array(%ecx), %edx
        sram.MEM[327] = 16'h0050;
        sram.MEM[328] = 16'h2114;
        sram.MEM[329] = 16'h0000;
        //  0x0295:402014000000  |     rmmovl %edx, Array(%eax) # sortlist[i] ja esta em Array(%eax)
        sram.MEM[330] = 16'h0040;
        sram.MEM[331] = 16'h2014;
        sram.MEM[332] = 16'h0000;
        //                       |
        //                       |     #sortlist[i+1] = j
        //  0x029b:5005f8ffffff  |     mrmovl -8(%ebp), %eax
        sram.MEM[333] = 16'h0050;
        sram.MEM[334] = 16'h05f8;
        sram.MEM[335] = 16'hffff;
        //  0x02a1:400114000000  |     rmmovl %eax, Array(%ecx)
        sram.MEM[336] = 16'hff40;
        sram.MEM[337] = 16'h0114;
        sram.MEM[338] = 16'h0000;
        //                       |
        //  0x02a7:              | LBB0_10:                                ## i = i + 1
        //  0x02a7:5005fcffffff  |     mrmovl -4(%ebp), %eax
        sram.MEM[339] = 16'h0050;
        sram.MEM[340] = 16'h05fc;
        sram.MEM[341] = 16'hffff;
        //  0x02ad:c0f001000000  |     iaddl $1, %eax
        sram.MEM[342] = 16'hffc0;
        sram.MEM[343] = 16'hf001;
        sram.MEM[344] = 16'h0000;
        //  0x02b3:4005fcffffff  |     rmmovl %eax, -4(%ebp)
        sram.MEM[345] = 16'h0040;
        sram.MEM[346] = 16'h05fc;
        sram.MEM[347] = 16'hffff;
        //  0x02b9:702b020000    |     jmp LBB0_7
        sram.MEM[348] = 16'hff70;
        sram.MEM[349] = 16'h2b02;
        sram.MEM[350] = 16'h0000;
        //                       |
        //  0x02be:              | LBB0_11:                                ## in Loop: Header=BB0_5 Depth=1
        //  0x02be:5005f4ffffff  |     mrmovl -12(%ebp), %eax
        sram.MEM[351] = 16'h5005;
        sram.MEM[352] = 16'hf4ff;
        sram.MEM[353] = 16'hffff;
        //  0x02c4:c1f001000000  |     isubl $1, %eax
        sram.MEM[354] = 16'hc1f0;
        sram.MEM[355] = 16'h0100;
        sram.MEM[356] = 16'h0000;
        //  0x02ca:4005f4ffffff  |     rmmovl %eax, -12(%ebp)
        sram.MEM[357] = 16'h4005;
        sram.MEM[358] = 16'hf4ff;
        sram.MEM[359] = 16'hffff;
        //  0x02d0:700e020000    |     jmp	LBB0_5
        sram.MEM[360] = 16'h700e;
        sram.MEM[361] = 16'h0200;
        //                       |
        //  0x02d5:              | LBB0_12:
        //  0x02d5:30f000000000  |     irmovl	$0, %eax
        sram.MEM[362] = 16'h0030;
        sram.MEM[363] = 16'hf000;
        sram.MEM[364] = 16'h0000;
        //  0x02db:c0f40c000000  |     iaddl	$12, %esp
        sram.MEM[365] = 16'h00c0;
        sram.MEM[366] = 16'hf40c;
        sram.MEM[367] = 16'h0000;
        //  0x02e1:b05f          |     popl	%ebp
        sram.MEM[368] = 16'h00b0;
        //  0x02e3:90            |     ret
        sram.MEM[369] = 16'h5f90;
        $display("Skipping 100 elements bubblesort test (takes too long)... ");
        //#7000000
        //checkSortedMemByDE2Index(10, 210, 1900);



        $display("!!! Tests finished successfully!!!");
        $finish;
     end


   Proc core(Mode, CLOCK_50, Status,
             SRAM_ADDR, SRAM_DQ, SRAM_WE_N, SRAM_OE_N, SRAM_UB_N, SRAM_LB_N, SRAM_CE_N,
             EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI);
   SRAM sram(SRAM_ADDR[20:1], SRAM_DQ, ~SRAM_WE_N, ~SRAM_OE_N, SRAM_UB_N, SRAM_LB_N, SRAM_CE_N);

   task printRegs;
      begin
         $display("%%eax: 0x%x %0d", EAX, EAX);
         $display("%%ecx: 0x%x %0d", ECX, ECX);
         $display("%%edx: 0x%x %0d", EDX, EDX);
         $display("%%ebx: 0x%x %0d", EBX, EBX);
         $display("%%esp: 0x%x %0d", ESP, ESP);
         $display("%%ebp: 0x%x %0d", EBP, EBP);
         $display("%%esi: 0x%x %0d", ESI, ESI);
         $display("%%edi: 0x%x %0d", EDI, EDI);
         $display("stack top: 0x%x%x", sram.MEM[ESP[20:1]], sram.MEM[ESP[20:1]+1]);
         $display("frame top: 0x%x%x", sram.MEM[EBP[20:1]], sram.MEM[EBP[20:1]+1]);
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

   task checkMemByDE2Index;
      input [19:0] index;
      input [15:0] expected, checkID;
      reg [15:0] actual;
      begin
         actual = sram.MEM[index];
         if (expected != actual)
           begin
              $display("*** (%0d) Memory ERROR at addr:%0x! Expected: %0x Actual: %0x",
                       checkID, index, expected, actual);
              $finish;
           end
         else
           $display("OK (%0d)... %0x", checkID, expected);
      end
   endtask

   task checkMemByAddr;
      input [31:0] addr;
      input [15:0] expected, checkID;
      begin
         checkMemByDE2Index(addr[20:1], expected, checkID);
      end
   endtask

   task checkSortedMemByDE2Index;
       input [19:0] first;
       input [19:0] last;
       input [31:0] checkID;
       reg [15:0] valA, valB;
       reg [31:0] val, expected;

       begin
          expected = 0;
          for (i = first; (i + 1) < last; i = i + 2) begin
             expected = expected + 1;
             valA = sram.MEM[i];
             valB = sram.MEM[i + 1];
             val = {valB[7:0], valB[15:8], valA[7:0], valA[15:8]};
             if (val != expected)
                begin
                   $display("Memory NOT sorted at index [%0d, %0d], expected 0x%0x but got 0x%0x",
                            i, i + 1, expected, val);
                   $finish;
                end
          end
          $display("OK (%0d) memory sorted", checkID);
       end
   endtask

   task printMemByDE2Index;
       input [19:0] first;
       input [19:0] last;
       reg [15:0] valA, valB;
       reg [31:0] val;
       begin
          for (i = first; (i + 1) < last; i = i + 2) begin
             valA = sram.MEM[i];
             valB = sram.MEM[i + 1];
             val = {valB[7:0], valB[15:8], valA[7:0], valA[15:8]};
             $display("Val {%0d,%0d}: 0x%0x %0d", i, i + 1, val, val);
          end
       end
   endtask

   task printMemByAddr;
       input [31:0] first, last;
       begin
          printMemByDE2Index(first[20:1], last[20:1]);
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
