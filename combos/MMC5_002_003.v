// Combo: MMC5/CV3(005) + UxROM(002) + CNROM(003)  ~215 LEs est.
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

localparam UxROM_BITSIZE = 3;  // 3=256KB standard; change to 4 for 512KB hacks
wire ppu_latch0 = 1'b0;  // stub - MMC2/4 not in this config
wire ppu_latch1 = 1'b0;  // stub - MMC2/4 not in this config
wire mapper_163_latch = 1'b0;  // stub - Nanjing #163 not in this config
wire shift_chr_right = 1'b0;  // stub - VRC2/4 not in this config
wire shift_chr_left  = 1'b0;  // stub - VRC2/4 not in this config
// for MMC5 scanline-based interrupts, counts dummy PPU reads
reg mmc5_irq_enabled = 0;           // register to enable/disable counter
reg [7:0] mmc5_irq_line = 0;        // scanline on which IRQ will be triggered
reg mmc5_irq_ack = 0;               // flag to acknowledge IRQ
reg mmc5_irq_out = 0;               // stores 1 when IRQ is triggered

// Scanline counter
reg [3:0] ppu_rd_hi_time = 0;
reg [1:0] ppu_nt_read_count;
reg [7:0] scanline = 0;
reg new_screen = 0;
reg new_screen_clear = 0;

assign irq = (
   mmc5_irq_out) ? 1'b0 : 1'bZ;

wire cpu_data_out_enabled;
wire [7:0] cpu_data_out;
assign {cpu_data_out_enabled, cpu_data_out} =
   (cpu_rw_in && m2) ?
   (
      romsel ?
      (
         ((mapper == 0) && (cpu_addr_in[14:12] == 3'b101)) ? {8'b10000000, new_dendy} :
         (mapper == 6'b001111) && (cpu_addr_in[14:0] == 15'h5204) ? {1'b1, mmc5_irq_out, ~new_screen, 6'b000000} :
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

         if (1 && (mapper == 6'b001111))
         begin
            // just workaround for Castlevania 3, not real MMC5
            case (cpu_addr_in[14:0])
               15'h5105: begin // mirroring
                  // 0xFF enables four-screen on full MMC5; ignored here in this minimal workaround.
                  if (cpu_data_in != 8'hFF)
                  begin
                     case ({cpu_data_in[4], cpu_data_in[2]})
                        2'b00: mirroring <= 2'b10;
                        2'b01: mirroring <= 2'b00;
                        2'b10: mirroring <= 2'b01;
                        2'b11: mirroring <= 2'b11;
                     endcase
                  end
               end
               15'h5115: begin
                  prg_bank_a[4:0] <= {cpu_data_in[4:1], 1'b0};
                  prg_bank_b[4:0] <= {cpu_data_in[4:1], 1'b1};
               end
               15'h5116: prg_bank_c[4:0] <= cpu_data_in[4:0];
               15'h5117: prg_bank_d[4:0] <= cpu_data_in[4:0];
               15'h5120: chr_bank_a[7:0] <= cpu_data_in[7:0];
               15'h5121: chr_bank_b[7:0] <= cpu_data_in[7:0];
               15'h5122: chr_bank_c[7:0] <= cpu_data_in[7:0];
               15'h5123: chr_bank_d[7:0] <= cpu_data_in[7:0];
               15'h5128: chr_bank_e[7:0] <= cpu_data_in[7:0];
               15'h5129: chr_bank_f[7:0] <= cpu_data_in[7:0];
               15'h512A: chr_bank_g[7:0] <= cpu_data_in[7:0];
               15'h512B: chr_bank_h[7:0] <= cpu_data_in[7:0];
               15'h5203: begin
                  mmc5_irq_ack <= 1;
                  mmc5_irq_line[7:0] <= cpu_data_in[7:0];
               end
               15'h5204: begin
                  mmc5_irq_ack <= 1;
                  mmc5_irq_enabled <= cpu_data_in[7];
               end
            endcase
         end

      end else begin // $8000-$FFFF

         if (1 && (mapper == 6'b000001))
         begin
            if (!1 | ~flags[0] | (cpu_addr_in[14:12] != 3'b001))
            begin
               prg_bank_a[UxROM_BITSIZE+1:1] <= cpu_data_in[UxROM_BITSIZE:0];
               // Mapper #30 - UNROM 512
               if (0 && flags[1])
               begin
                  // One screen mirroring select, CHR RAM bank
                  mirroring[1:0] <= {1'b1, cpu_data_in[7]};
                  chr_bank_a[1:0] <= cpu_data_in[6:5];
               end
            end else begin // CodeMasters, blah. Mirroring control used only by Fire Hawk
               mirroring[1:0] <= {1'b1, cpu_data_in[4]};
            end
         end

         // Mapper #3 - CNROM
         if (1 && (mapper == 6'b000010))
         begin
            chr_bank_a[7:3] <= cpu_data_in[4:0];

      end // romsel
   end // write

   // for MMC5
   if (1 && (mapper == 6'b001111))
   begin
      if (romsel && (cpu_addr_in[14:0] == 15'h5204)) // write or read
         mmc5_irq_ack <= 1;
      if (mmc5_irq_ack && ~mmc5_irq_out)
         mmc5_irq_ack <= 0;
   end

end

// V-blank detector
always @ (negedge m2, negedge ppu_rd_in)
begin
   if (~ppu_rd_in)
   begin
      ppu_rd_hi_time <= 0;
      if (new_screen_clear) new_screen <= 0;
   end else if (ppu_rd_hi_time < 4'b1111)
   begin
      // Counting how long there is no PPU reads
      ppu_rd_hi_time <= ppu_rd_hi_time + 1'b1;
   end else begin
      // Too long, v-blank detected
      new_screen <= 1;
   end
end

// Scanline counter
always @ (negedge ppu_rd_in)
begin
   if (1 && (mapper == 6'b001111) && mmc5_irq_ack) mmc5_irq_out = 0;
   if (~new_screen && new_screen_clear) new_screen_clear = 0;
   if (new_screen & ~new_screen_clear)
   begin
      scanline = 0;
      new_screen_clear <= 1;
   end else
   if (ppu_addr_in[13:12] == 2'b10)
   begin
      if (ppu_nt_read_count < 3)
      begin
         ppu_nt_read_count <= ppu_nt_read_count + 1'b1;
      end else begin
         scanline = scanline + 1'b1;
         if (1 && (mapper == 6'b001111) && mmc5_irq_enabled && (scanline == mmc5_irq_line + 1'b1))
            mmc5_irq_out <= 1;
      end
   end else begin
      ppu_nt_read_count <= 0;
   end
end

endmodule
