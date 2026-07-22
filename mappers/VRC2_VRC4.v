// Mappers #021/#022/#023/#025 - VRC2 / VRC4
// Stripped from Cool2Poor.v for EPM240T100C5N (240 LEs)

module Cool2Poor (
   input m2,
   input romsel,
   input cpu_rw_in,
   input [14:0] cpu_addr_in,
   inout [7:0] cpu_data_in,
   output [26:13] cpu_addr_out,
   output flash_we,
   output flash_oe,
   output sram_ce,
   output sram_we,
   output sram_oe,

   input ppu_rd_in,
   input [13:3] ppu_addr_in,
   output [17:10] ppu_addr_out,
   output ppu_ciram_a10,

   output irq
);
   reg new_dendy = 0;

   assign cpu_addr_out[26:13] = {cpu_base[26:14] | (cpu_addr_mapped[20:14] & ~prg_mask[20:14]), cpu_addr_mapped[13]};
   assign ppu_addr_out[17:10] = {ppu_addr_mapped[17:13] & ~chr_mask[17:13], ppu_addr_mapped[12:10]};

   assign cpu_data_in = cpu_data_out_enabled ? cpu_data_out : 8'bZZZZZZZZ;
   wire flash_ce_w = ~(~romsel | (m2 & map_rom_on_6000 & cpu_addr_in[14] & cpu_addr_in[13]));
   assign flash_oe = ~cpu_rw_in | flash_ce_w;

   assign flash_we = cpu_rw_in | flash_ce_w | ~prg_write_enabled;
   wire sram_ce_w = ~(cpu_addr_in[14] & cpu_addr_in[13] & m2 & romsel & sram_enabled & ~map_rom_on_6000);
   assign sram_ce = sram_ce_w | cpu_data_out_enabled;
   assign sram_we = cpu_rw_in | sram_ce_w;
   assign sram_oe = ~cpu_rw_in | sram_ce_w;

reg [26:14] cpu_base = 0;
reg [20:14] prg_mask = 7'b1111000;
reg [18:13] chr_mask = 0;
reg [2:0] prg_mode = 0;
reg map_rom_on_6000 = 0;
reg [7:0] prg_bank_6000 = 0;
reg [7:0] prg_bank_a = 0;
reg [7:0] prg_bank_b = 1;
reg [7:0] prg_bank_c = 8'b11111110;
reg [7:0] prg_bank_d = 8'b11111111;
reg [2:0] chr_mode = 0;
reg [8:0] chr_bank_a = 0;
reg [8:0] chr_bank_b = 1;
reg [8:0] chr_bank_c = 2;
reg [8:0] chr_bank_d = 3;
reg [8:0] chr_bank_e = 4;
reg [8:0] chr_bank_f = 5;
reg [8:0] chr_bank_g = 6;
reg [8:0] chr_bank_h = 7;
reg [5:0] mapper = 0;
reg [2:0] flags = 0;
reg sram_enabled = 0;
reg chr_write_enabled = 0;
reg prg_write_enabled = 0;
reg [1:0] mirroring = 0;
reg lockout = 0;
reg writed;

wire ppu_latch0 = 1'b0;  // stub - MMC2/4 not in this config
wire ppu_latch1 = 1'b0;  // stub - MMC2/4 not in this config
wire mapper_163_latch = 1'b0;  // stub - Nanjing #163 not in this config
// for VRC4, CPU-based interrupts
reg [7:0] vrc4_irq_value = 0;   // counter itself (upcounting)
reg [2:0] vrc4_irq_control = 0; // IRQ settings
reg [7:0] vrc4_irq_latch = 0;   // stores counter reload latch value
reg [6:0] vrc4_irq_prescaler = 0;   // prescaler counter for VRC4
reg [1:0] vrc4_irq_prescaler_counter = 0; // prescaler cicles counter for VRC4
reg vrc4_irq_out = 0;           // stores 1 when IRQ is triggered

wire shift_chr_right = 1 && 1 && (mapper == 6'b011000) && flags[1];
wire shift_chr_left = 0;
wire vrc_2b_hi =
   (!flags[0] && !flags[2]) ?
      (cpu_addr_in[7] | cpu_addr_in[2]) // mapper #21
   : (flags[0] && !flags[2]) ?
      (cpu_addr_in[0]) // mapper #22
   : (!flags[0] && flags[2]) ?
      (cpu_addr_in[5] | cpu_addr_in[3] | cpu_addr_in[1]) // mapper #23
   : (cpu_addr_in[2] | cpu_addr_in[0]); // mapper #25
wire vrc_2b_low =
   (!flags[0] && !flags[2]) ?
      (cpu_addr_in[6] | cpu_addr_in[1]) // mapper #21
   : (flags[0] && !flags[2]) ?
      (cpu_addr_in[1]) // mapper #22
   : (!flags[0] && flags[2]) ?
      (cpu_addr_in[4] | cpu_addr_in[2] | cpu_addr_in[0]) // mapper #23
   : (cpu_addr_in[3] | cpu_addr_in[1]); // mapper #25

assign irq = (
   vrc4_irq_out) ? 1'b0 : 1'bZ;

wire cpu_data_out_enabled;
wire [7:0] cpu_data_out;
assign {cpu_data_out_enabled, cpu_data_out} =
   (cpu_rw_in && m2) ?
   (
      romsel ?
      (
         ((mapper == 0) && (cpu_addr_in[14:12] == 3'b101)) ? {8'b10000000, new_dendy} :
         9'b0
      ) : 9'b0
   ) : 9'b0;

assign ppu_ciram_a10 = (0 & (mapper == 6'b010100) & flags[0]) ? ppu_addr_mapped[17] :
   (mirroring[1] ? mirroring[0] : (mirroring[0] ? ppu_addr_in[11] : ppu_addr_in[10]));

wire [20:13] cpu_addr_mapped = (map_rom_on_6000 & romsel & m2) ? prg_bank_6000 :
(
   prg_mode[2] ? (
      prg_mode[1] ? (
         prg_mode[0] ? (
            // 111 - 0x8000(A)
            {prg_bank_a[7:2], cpu_addr_in[14:13]}
         ) : (
            // 110 - 0x8000(B)
            {prg_bank_b[7:2], cpu_addr_in[14:13]}
         )
      ) : ( // prg_mode[1]
         prg_mode[0] ? (
            // 101 - 0x2000(C)+0x2000(B)+0x2000(A)+0x2000(D)
            cpu_addr_in[14] ? (cpu_addr_in[13] ? prg_bank_d : prg_bank_a) : (cpu_addr_in[13] ? prg_bank_b : prg_bank_c)
         ) : ( // prg_mode[0]
            // 100 - 0x2000(A)+0x2000(B)+0x2000(C)+0x2000(D)
            cpu_addr_in[14] ? (cpu_addr_in[13] ? prg_bank_d : prg_bank_c) : (cpu_addr_in[13] ? prg_bank_b : prg_bank_a)
         )
      )
   ) : ( // prg_mode[2]
      prg_mode[0] ? (
         // 0x1 - 0x4000(C) + 0x4000 (A)
         {(cpu_addr_in[14] ? prg_bank_a[7:1] : prg_bank_c[7:1]), cpu_addr_in[13]}
      ) : ( // prg_mode[0]
         // 0x0 - 0x4000(A) + 0x4000 (С)
         {(cpu_addr_in[14] ? prg_bank_c[7:1] : prg_bank_a[7:1]), cpu_addr_in[13]}
      )
   )
);

wire [18:10] ppu_addr_mapped = (
   chr_mode[2] ? (
      chr_mode[1] ? (
         chr_mode[0] ? (
            // 111 - 0x400(A)+0x400(B)+0x400(C)+0x400(D)+0x400(E)+0x400(F)+0x400(G)+0x400(H)
            ppu_addr_in[12] ?
               (ppu_addr_in[11] ? (ppu_addr_in[10] ? chr_bank_h : chr_bank_g) :
               (ppu_addr_in[10] ? chr_bank_f : chr_bank_e)) : (ppu_addr_in[11] ? (ppu_addr_in[10] ? chr_bank_d : chr_bank_c) : (ppu_addr_in[10] ? chr_bank_b : chr_bank_a))
         ) : ( // chr_mode[0]
            // 110 - 0x800(A)+0x800(C)+0x800(E)+0x800(G)
            {(ppu_addr_in[12] ?
               (ppu_addr_in[11] ? chr_bank_g[8:1] : chr_bank_e[8:1]) :
               (ppu_addr_in[11] ? chr_bank_c[8:1] : chr_bank_a[8:1])), ppu_addr_in[10]}
         )
      ) : ( // chr_mode[1]
         // 100 - 0x1000(A) + 0x1000(E)
         // 101 - 0x1000(A/B) + 0x1000(E/F) - MMC2 and MMC4
      {(ppu_addr_in[12] ?
            (((0) && chr_mode[0] && ppu_latch1) ? chr_bank_f[8:2] : chr_bank_e[8:2]) :
            (((0) && chr_mode[0] && ppu_latch0) ? chr_bank_b[8:2] : chr_bank_a[8:2])),
         ppu_addr_in[11:10]}
      )
   ) : ( // chr_mode[2]
      chr_mode[1] ? (
         // 010 - 0x800(A)+0x800(C)+0x400(E)+0x400(F)+0x400(G)+0x400(H)
         // 011 - 0x400(E)+0x400(F)+0x400(G)+0x400(H)+0x800(A)+0x800(С)
      (ppu_addr_in[12]^chr_mode[0]) ?
            (ppu_addr_in[11] ?
               (ppu_addr_in[10] ? chr_bank_h : chr_bank_g) :
               (ppu_addr_in[10] ? chr_bank_f : chr_bank_e)
            ) : (
               ppu_addr_in[11] ? {chr_bank_c[8:1],ppu_addr_in[10]} : {chr_bank_a[8:1],ppu_addr_in[10]}
            )
      ) : ( // chr_mode[1]
         (0 && chr_mode[0]) ? (
            // 001 - Mapper #163 special
            {mapper_163_latch, ppu_addr_in[11:10]}
         ) : (
            // 000 - 0x2000(A)
            {chr_bank_a[8:3], ppu_addr_in[12:10]}
         )
      )
   )
) >> shift_chr_right << shift_chr_left;

always @ (negedge m2)
begin

   // IRQ for VRC4
   if (1 & 1 & (vrc4_irq_control[1]))
   begin
      reg carry;
      // Cycle mode without prescaler is not used by any games? It's missed in fceux source code.
      /*
      if (vrc4_irq_control[2]) // cycle mode
      begin
         {carry, vrc4_irq_value[7:0]} = vrc4_irq_value[7:0] + 1'b1; // just count IRQ value
         if (carry)
         begin
            vrc4_irq_out = 1;
            vrc4_irq_value[7:0] = vrc4_irq_latch[7:0];
         end
      end else
      */
      begin // scanline mode
         vrc4_irq_prescaler = vrc4_irq_prescaler + 1'b1; // count prescaler
         if ((vrc4_irq_prescaler_counter[1] == 0 && vrc4_irq_prescaler == 114)
            || (vrc4_irq_prescaler_counter[1] == 1 && vrc4_irq_prescaler == 113)) // 114, 114, 113
         begin
            vrc4_irq_prescaler = 0;
            vrc4_irq_prescaler_counter = vrc4_irq_prescaler_counter + 1'b1;
            if (vrc4_irq_prescaler_counter == 2'b11) vrc4_irq_prescaler_counter = 2'b00;
            {carry, vrc4_irq_value[7:0]} = vrc4_irq_value[7:0] + 1'b1;
            if (carry)
            begin
               vrc4_irq_out = 1;
               vrc4_irq_value[7:0] = vrc4_irq_latch[7:0];
            end
         end
      end
   end

   if (cpu_rw_in == 1) // read
   begin
      writed <= 0;
   end else if (cpu_rw_in == 0 && !writed) // write
   begin
      writed <= 1;
      if (romsel) // $0000-$7FFF
      begin
         if ((cpu_addr_in[14:12] == 3'b101) && (lockout == 0)) // $5000-5FFF & lockout is off
         begin
            case (cpu_addr_in[2:0])
               3'b000: // $5xx0
                  {cpu_base[26:22]} <= cpu_data_in[4:0];                 // CPU base address A26-A22
               3'b001: // $5xx1
                  cpu_base[21:14] <= cpu_data_in[7:0];                   // CPU base address A21-A14
               3'b010: // $5xx2
                  {chr_mask[18], prg_mask[20:14]} <= cpu_data_in[7:0];   // CHR mask A18, CPU mask A20-A14
               3'b011: // $5xx3
                  {prg_mode[2:0], chr_bank_a[7:3]} <= cpu_data_in[7:0];  // PRG mode, direct chr_bank_a access
               3'b100: // $5xx4
                  {chr_mode[2:0], chr_mask[17:13]} <= cpu_data_in[7:0];  // CHR mode, CHR mask A17-A13
               3'b101: // $5xx5
                  {chr_bank_a[8], prg_bank_a[5:1]} <= cpu_data_in[7:2]; // direct prg_bank_a access, current SRAM page 0-3
               3'b110: // $5xx6
                  {flags[2:0], mapper[4:0]} <= cpu_data_in[7:0];         // some flags, mapper
               3'b111: // $5xx7
                  // some other parameters
                  begin
                     {lockout, mapper[5], mirroring[1:0], prg_write_enabled, chr_write_enabled, sram_enabled} <= {cpu_data_in[7:6], cpu_data_in[4:0]};
                     // some unusual init stuff
                     if (0 && mapper == 6'b010001) prg_bank_b <= 8'b11111101;
                     if (0 && (mapper == 6'b010111)) map_rom_on_6000 <= 1;
                     if (0 && mapper == 6'b001110) prg_bank_b <= 1;
                  end
            endcase

      end else begin // $8000-$FFFF

         // Mapper #23 - VRC2/4
         /*
         flag0 - switches A0 and A1 lines. 0=A0,A1 like VRC2b (mapper #23), 1=A1,A0 like VRC2a(#22), VRC2c(#25)
         flag1 - divides CHR bank select by two (mapper #22, VRC2a)
         */
         if (1 && (mapper == 6'b011000))
         begin
            case ({cpu_addr_in[14:12], vrc_2b_hi, vrc_2b_low})
               5'b00000,
               5'b00001,
               5'b00010,
               5'b00011: prg_bank_a[4:0] <= cpu_data_in[4:0];  // $8000-$8003, PRG0
               5'b00100,
               5'b00101: // VRC2-using games are usually well-behaved and only write 0 or 1 to this register,
                         // but Wai Wai World in one instance writes $FF instead
                         if (cpu_data_in != 8'b11111111) mirroring <= cpu_data_in[1:0]; // $9000-$9001, mirroring
               5'b00110,
               5'b00111: prg_mode[0] <= cpu_data_in[1]; // $9002-$9004, PRG swap
               5'b01000,
               5'b01001,
               5'b01010,
               5'b01011: prg_bank_b[4:0] <= cpu_data_in[4:0];  // $A000-$A003, PRG1
               5'b01100: chr_bank_a[3:0] <= cpu_data_in[3:0];  // $B000, CHR0 low
               5'b01101: chr_bank_a[7:4] <= cpu_data_in[3:0];  // $B001, CHR0 hi
               5'b01110: chr_bank_b[3:0] <= cpu_data_in[3:0];  // $B002, CHR1 low
               5'b01111: chr_bank_b[7:4] <= cpu_data_in[3:0];  // $B003, CHR1 hi
               5'b10000: chr_bank_c[3:0] <= cpu_data_in[3:0];  // $C000, CHR2 low
               5'b10001: chr_bank_c[7:4] <= cpu_data_in[3:0];  // $C001, CHR2 hi
               5'b10010: chr_bank_d[3:0] <= cpu_data_in[3:0];  // $C002, CHR3 low
               5'b10011: chr_bank_d[7:4] <= cpu_data_in[3:0];  // $C003, CHR3 hi
               5'b10100: chr_bank_e[3:0] <= cpu_data_in[3:0];  // $D000, CHR4 low
               5'b10101: chr_bank_e[7:4] <= cpu_data_in[3:0];  // $D001, CHR4 hi
               5'b10110: chr_bank_f[3:0] <= cpu_data_in[3:0];  // $D002, CHR5 low
               5'b10111: chr_bank_f[7:4] <= cpu_data_in[3:0];  // $D003, CHR5 hi
               5'b11000: chr_bank_g[3:0] <= cpu_data_in[3:0];  // $E000, CHR6 low
               5'b11001: chr_bank_g[7:4] <= cpu_data_in[3:0];  // $E001, CHR6 hi
               5'b11010: chr_bank_h[3:0] <= cpu_data_in[3:0];  // $E002, CHR7 low
               5'b11011: chr_bank_h[7:4] <= cpu_data_in[3:0];  // $E003, CHR7 hi
            endcase
            if (1)
            begin
               if (cpu_addr_in[14:12] == 3'b111)
               begin
                  case ({vrc_2b_hi, vrc_2b_low})
                     2'b00: vrc4_irq_latch[3:0] <= cpu_data_in[3:0];  // IRQ latch low
                     2'b01: vrc4_irq_latch[7:4] <= cpu_data_in[3:0];  // IRQ latch hi
                     2'b10: begin // IRQ control
                        vrc4_irq_out <= 0; // ack
                        vrc4_irq_control[2:0] = cpu_data_in[2:0]; // mode, enabled, enabled after ack
                        if (vrc4_irq_control[1]) begin // if E is set
                           vrc4_irq_prescaler_counter[1:0] <= 2'b00; // reset prescaler
                           vrc4_irq_prescaler[6:0] <= 7'b0000000;
                           vrc4_irq_value[7:0] <= vrc4_irq_latch[7:0]; // reload with latch
                        end
                     end
                     2'b11: begin // IRQ ack
                        vrc4_irq_out <= 0;
                        vrc4_irq_control[1] <= vrc4_irq_control[0];
                     end
                  endcase
               end
            end
         end

      end // romsel
   end // write

end

endmodule
