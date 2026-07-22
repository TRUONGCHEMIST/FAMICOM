// Combo: MMC3(004) + MMC1(001)  ~230+ LEs, may need AGGRESSIVE AREA opt
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
reg [2:0] mmc3_internal = 0;

reg [5:0] mmc1_load_register = 0;

// for MMC3 scanline-based interrupts, counts A12 rises after long A12 falls
reg mmc3_irq_enabled = 0;           // register to enable/disable counter
reg [7:0] mmc3_irq_latch = 0;       // stores counter reload latch value
reg [7:0] mmc3_irq_counter = 0;     // counter itself (downcounting)
reg [1:0] a12_low_time = 0;         // counts how long A12 is low
reg mmc3_irq_reload = 0;            // flag to reload counter from latch
reg mmc3_irq_reload_clear = 0;      // flag to clear reload flag
reg mmc3_irq_ready = 0;             // stores 1 when IRQ is ready (enabled and non-zero)
reg mmc3_irq_out = 0;               // stores 1 when IRQ is triggered
// scanline counter, counts dummy PPU reads, detects v-blank automatically
reg [3:0] ppu_rd_hi_time = 0;       // counts how long there is no reads from PPU to detect v-blank
reg [1:0] ppu_nt_read_count;        // nametable read counter
reg [7:0] scanline = 0;             // current scanline
reg new_screen = 0;                 // stores 1 when v-blank detected ("in frame" flag)

assign irq = (
   mmc3_irq_out) ? 1'b0 : 1'bZ;

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
         {cpu_addr_in[14] ? prg_bank_a[7:1] : prg_bank_c[7:1], cpu_addr_in[13]}
      ) : ( // prg_mode[0]
         // 0x0 - 0x4000(A) + 0x4000 (С)
         {cpu_addr_in[14] ? prg_bank_c[7:1] : prg_bank_a[7:1], cpu_addr_in[13]}
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
            {ppu_addr_in[12] ?
               (ppu_addr_in[11] ? chr_bank_g[8:1] : chr_bank_e[8:1]) :
               (ppu_addr_in[11] ? chr_bank_c[8:1] : chr_bank_a[8:1]), ppu_addr_in[10]}
         )
      ) : ( // chr_mode[1]
         // 100 - 0x1000(A) + 0x1000(E)
         // 101 - 0x1000(A/B) + 0x1000(E/F) - MMC2 and MMC4
      {ppu_addr_in[12] ?
            (((0) && chr_mode[0] && ppu_latch1) ? chr_bank_f[8:2] : chr_bank_e[8:2]) :
            (((0) && chr_mode[0] && ppu_latch0) ? chr_bank_b[8:2] : chr_bank_a[8:2]),
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

         // Mapper #4 - MMC3/MMC6
         /*
         flag0 - TxSROM
         flag1 - mapper #189
         flag2 - mapper #206 (disable most features)
         */
         if (1 && (mapper == 6'b010100))
         begin
            case ({cpu_addr_in[14:13], cpu_addr_in[0]})
               3'b000: begin // $8000-$9FFE, even
                  mmc3_internal[2:0] <= cpu_data_in[2:0];
                  if ((!0 | ~flags[1]) & (!0 | ~flags[2])) // disabled for mappers #189 & #206
                  begin
                     if (cpu_data_in[6])
                        prg_mode <= 3'b101;
                     else
                        prg_mode <= 3'b100;
                  end
                  if (!0 | ~flags[2]) // disabled for mapper #206
                  begin
                     if (cpu_data_in[7])
                        chr_mode <= 3'b011;
                     else
                        chr_mode <= 3'b010;
                  end
               end
               3'b001: begin // $8001-$9FFF, odd
                  case (mmc3_internal[2:0])
                     3'b000: chr_bank_a[7:0] <= cpu_data_in[7:0];
                     3'b001: chr_bank_c[7:0] <= cpu_data_in[7:0];
                     3'b010: chr_bank_e[7:0] <= cpu_data_in[7:0];
                     3'b011: chr_bank_f[7:0] <= cpu_data_in[7:0];
                     3'b100: chr_bank_g[7:0] <= cpu_data_in[7:0];
                     3'b101: chr_bank_h[7:0] <= cpu_data_in[7:0];
                     3'b110: if (!0 | ~flags[1]) prg_bank_a[(MMC3_BITSIZE-1):0] <= cpu_data_in[(MMC3_BITSIZE-1):0];
                     3'b111: if (!0 | ~flags[1]) prg_bank_b[(MMC3_BITSIZE-1):0] <= cpu_data_in[(MMC3_BITSIZE-1):0];
                  endcase
               end
               3'b010: if (!0 | ~flags[2]) // disabled for mapper #206
                           mirroring <= {1'b0, cpu_data_in[0]}; // $A000-$BFFE, even (mirroring)
               3'b011: ; // RAM protect... no
               3'b100: mmc3_irq_latch <= cpu_data_in; // $C000-$DFFE, even (IRQ latch)
               3'b101: mmc3_irq_reload <= 1; // $C001-$DFFF, odd
               3'b110: mmc3_irq_enabled <= 0; // $E000-$FFFE, even
               3'b111: if (!0 | ~flags[2]) // disabled for mapper #206
                           mmc3_irq_enabled <= 1; // $E001-$FFFF, odd
            endcase
         end

         // Mapper #1 - MMC1
         /*
         flag0 - 16KB of PRG RAM (SOROM)
         */
         if (1 && (mapper == 6'b010000))
         begin
            if (cpu_data_in[7] == 1) // reset
            begin
               mmc1_load_register[5:0] = 6'b100000;
               prg_mode <= 3'b000;   // 0x4000 (A) + fixed last (C)
               prg_bank_c[4:0] <= 5'b11110;
            end else begin
               mmc1_load_register[5:0] = {cpu_data_in[0], mmc1_load_register[5:1]};
               if (mmc1_load_register[0] == 1)
               begin
                  case (cpu_addr_in[14:13])
                     2'b00: begin // $8000-$9FFF
                        if (mmc1_load_register[4:3] == 2'b11)
                        begin
                           prg_mode = 3'b000;   // 0x4000 (A) + fixed last (C)
                           prg_bank_c[4:1] = 4'b1111;
                        end else if (mmc1_load_register[4:3] == 2'b10)
                        begin
                           prg_mode = 3'b001;   // fixed first (C) + 0x4000 (A)
                           prg_bank_c[4:1] = 4'b0000;
                        end else
                           prg_mode = 3'b111;   // 0x8000 (A)
                        if (mmc1_load_register[5])
                           chr_mode = 3'b100;
                        else
                           chr_mode = 3'b000;
                        mirroring[1:0] = mmc1_load_register[2:1] ^ 2'b10;
                     end
                     2'b01: begin // $A000-$BFFF
                        chr_bank_a[6:2] = mmc1_load_register[5:1];
//                        if (flags[0]) // 16KB of PRG RAM
//                        begin
//                           sram_page = {1'b1, ~mmc1_load_register[4]}; // PRG RAM page #2 is "battery" backed
//                        end
                        prg_bank_a[5] = mmc1_load_register[5]; // for SUROM, 512k PRG support
                        prg_bank_c[5] = mmc1_load_register[5]; // for SUROM, 512k PRG support
                     end
                     2'b10: chr_bank_e[6:2] = mmc1_load_register[5:1]; // $C000-$DFFF
                     2'b11: begin
                        prg_bank_a[4:1] = mmc1_load_register[4:1]; // $E000-$FFFF
                        sram_enabled = ~mmc1_load_register[5];
                     end
                  endcase
                  mmc1_load_register[5:0] = 6'b100000;
               end
            end
         end

      end // romsel
   end // write

   // for MMC3
   if (!mmc3_irq_enabled)
   begin
      // ack
      mmc3_irq_ready <= 0;
      mmc3_irq_out <= 0;
   end else if (mmc3_irq_enabled && (mmc3_irq_counter != 0))
   begin
      // Fire scanline IRQ if counter is zero
      // BUT doesn't fire it when it's zero end reenabled
      mmc3_irq_ready <= 1;
   end else if (mmc3_irq_ready && (mmc3_irq_counter == 0))
   begin
      mmc3_irq_out <= 1;
   end

end

// IRQ counter
always @ (posedge ppu_addr_in[12])
begin
   // new scanline
   if (a12_low_time == 3)
   begin
      // for MMC3
      if ((mmc3_irq_reload && !mmc3_irq_reload_clear) || (mmc3_irq_counter == 0))
      begin
         mmc3_irq_counter <= mmc3_irq_latch;
         if (mmc3_irq_reload) mmc3_irq_reload_clear <= 1;
      end else begin
         mmc3_irq_counter <= mmc3_irq_counter - 1'b1;
      end
   end
   if (!mmc3_irq_reload) mmc3_irq_reload_clear <= 0;

   // for mapper #90
   if (0 & 0)
   begin
      if (mapper90_irq_out_clear) mapper90_irq_pending = 0;
      if (mapper90_irq_reload && !mapper90_irq_reload_clear)
      begin
         mapper90_irq_counter = mapper90_irq_latch;
         mapper90_irq_reload_clear <= 1;
      end else if (!mapper90_irq_reload)
      begin
         mapper90_irq_reload_clear <= 0;
      end

      if (mapper90_irq_enabled)
      begin
         reg carry;
         {carry, mapper90_irq_counter} = mapper90_irq_counter - 1'b1;
         mapper90_irq_pending = mapper90_irq_pending | carry;
      end
   end


// A12 must be low for 3 rises of M2
always @ (posedge m2, posedge ppu_addr_in[12])
begin
   if (ppu_addr_in[12])
      a12_low_time <= 0;
   else if (a12_low_time < 3)
      a12_low_time <= a12_low_time + 1'b1;
end

endmodule
