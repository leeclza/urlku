module Urlku
  # Dependency-free QR Code encoder (ISO/IEC 18004), byte mode, error
  # correction level M. Ported from Project Nayuki's reference algorithm
  # (MIT). Supports versions 1–40; short URLs typically fit in version 2–5.
  class QrCode
    MIN_VERSION = 1
    MAX_VERSION = 40

    # Level M tables, indexed by version (index 0 unused).
    ECC_CODEWORDS_PER_BLOCK = [
      -1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
      26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28,
    ]
    NUM_ERROR_CORRECTION_BLOCKS = [
      -1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
      17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49,
    ]
    # Format bits for level M.
    ECL_FORMAT_BITS = 0

    PENALTY_N1 =  3
    PENALTY_N2 =  3
    PENALTY_N3 = 40
    PENALTY_N4 = 10

    getter version : Int32
    getter size : Int32
    getter mask : Int32

    # Encodes `text` as UTF-8 bytes. Raises ArgumentError if it does not fit.
    def self.encode(text : String) : QrCode
      data = text.to_slice
      version = (MIN_VERSION..MAX_VERSION).find do |v|
        needed = 4 + char_count_bits(v) + data.size * 8
        needed <= num_data_codewords(v) * 8
      end
      raise ArgumentError.new("Data too long for a QR code") if version.nil?

      bits = [] of Bool
      append_bits(bits, 0x4, 4) # byte mode
      append_bits(bits, data.size, char_count_bits(version))
      data.each { |b| append_bits(bits, b.to_i, 8) }

      capacity = num_data_codewords(version) * 8
      append_bits(bits, 0, Math.min(4, capacity - bits.size)) # terminator
      append_bits(bits, 0, (8 - bits.size % 8) % 8)           # byte align
      pad = 0xEC
      while bits.size < capacity
        append_bits(bits, pad, 8)
        pad ^= 0xEC ^ 0x11
      end

      codewords = Array(Int32).new(bits.size // 8, 0)
      bits.each_with_index { |bit, i| codewords[i >> 3] |= (1 << (7 - (i & 7))) if bit }

      new(version, codewords)
    end

    def initialize(@version : Int32, data_codewords : Array(Int32))
      @size = @version * 4 + 17
      @modules = Array(Array(Bool)).new(@size) { Array(Bool).new(@size, false) }
      @is_function = Array(Array(Bool)).new(@size) { Array(Bool).new(@size, false) }

      draw_function_patterns
      draw_codewords(add_ecc_and_interleave(data_codewords))

      best_mask = 0
      best_penalty = Int32::MAX
      8.times do |m|
        apply_mask(m)
        draw_format_bits(m)
        penalty = penalty_score
        if penalty < best_penalty
          best_mask = m
          best_penalty = penalty
        end
        apply_mask(m) # XOR again to undo
      end

      @mask = best_mask
      apply_mask(@mask)
      draw_format_bits(@mask)
    end

    # True if the module at (x, y) is dark.
    def dark?(x : Int32, y : Int32) : Bool
      x >= 0 && x < @size && y >= 0 && y < @size && @modules[y][x]
    end

    # Renders a crisp, scalable SVG with a quiet zone of `border` modules.
    def to_svg(border : Int32 = 4, dark : String = "#0f172a", light : String = "#ffffff") : String
      total = @size + border * 2
      String.build do |io|
        io << %(<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 #{total} #{total}" shape-rendering="crispEdges">)
        io << %(<rect width="100%" height="100%" fill="#{light}"/>)
        io << %(<path fill="#{dark}" d=")
        @size.times do |y|
          @size.times do |x|
            io << "M" << (x + border) << "," << (y + border) << "h1v1h-1z" if @modules[y][x]
          end
        end
        io << %("/></svg>)
      end
    end

    # ---- Function patterns ----

    private def draw_function_patterns : Nil
      @size.times do |i|
        set_function(6, i, i.even?)
        set_function(i, 6, i.even?)
      end

      draw_finder(3, 3)
      draw_finder(@size - 4, 3)
      draw_finder(3, @size - 4)

      positions = alignment_positions
      last = positions.size - 1
      positions.each_with_index do |px, i|
        positions.each_with_index do |py, j|
          next if (i == 0 && j == 0) || (i == 0 && j == last) || (i == last && j == 0)
          draw_alignment(px, py)
        end
      end

      draw_format_bits(0) # placeholder, overwritten after masking
      draw_version
    end

    private def draw_finder(x : Int32, y : Int32) : Nil
      (-4..4).each do |dy|
        (-4..4).each do |dx|
          dist = Math.max(dx.abs, dy.abs)
          xx = x + dx
          yy = y + dy
          set_function(xx, yy, dist != 2 && dist != 4) if xx >= 0 && xx < @size && yy >= 0 && yy < @size
        end
      end
    end

    private def draw_alignment(x : Int32, y : Int32) : Nil
      (-2..2).each do |dy|
        (-2..2).each do |dx|
          set_function(x + dx, y + dy, Math.max(dx.abs, dy.abs) != 1)
        end
      end
    end

    private def draw_format_bits(mask : Int32) : Nil
      data = (ECL_FORMAT_BITS << 3) | mask
      rem = data
      10.times { rem = (rem << 1) ^ ((rem >> 9) * 0x537) }
      bits = ((data << 10) | rem) ^ 0x5412

      (0..5).each { |i| set_function(8, i, bit?(bits, i)) }
      set_function(8, 7, bit?(bits, 6))
      set_function(8, 8, bit?(bits, 7))
      set_function(7, 8, bit?(bits, 8))
      (9...15).each { |i| set_function(14 - i, 8, bit?(bits, i)) }

      (0...8).each { |i| set_function(@size - 1 - i, 8, bit?(bits, i)) }
      (8...15).each { |i| set_function(8, @size - 15 + i, bit?(bits, i)) }
      set_function(8, @size - 8, true) # dark module
    end

    private def draw_version : Nil
      return if @version < 7
      rem = @version
      12.times { rem = (rem << 1) ^ ((rem >> 11) * 0x1F25) }
      bits = (@version << 12) | rem

      18.times do |i|
        dark = bit?(bits, i)
        a = @size - 11 + i % 3
        b = i // 3
        set_function(a, b, dark)
        set_function(b, a, dark)
      end
    end

    private def alignment_positions : Array(Int32)
      return [] of Int32 if @version == 1
      num_align = @version // 7 + 2
      step = (@version * 8 + num_align * 3 + 5) // (num_align * 4 - 4) * 2
      result = Array(Int32).new(num_align, 0)
      result[0] = 6
      pos = @size - 7
      (num_align - 1).times do |i|
        result[num_align - 1 - i] = pos
        pos -= step
      end
      result
    end

    private def set_function(x : Int32, y : Int32, dark : Bool) : Nil
      @modules[y][x] = dark
      @is_function[y][x] = true
    end

    # ---- Codewords ----

    private def add_ecc_and_interleave(data : Array(Int32)) : Array(Int32)
      num_blocks = NUM_ERROR_CORRECTION_BLOCKS[@version]
      block_ecc_len = ECC_CODEWORDS_PER_BLOCK[@version]
      raw_codewords = QrCode.num_raw_data_modules(@version) // 8
      num_short_blocks = num_blocks - raw_codewords % num_blocks
      short_block_len = raw_codewords // num_blocks

      divisor = QrCode.rs_divisor(block_ecc_len)
      blocks = [] of Array(Int32)
      k = 0
      num_blocks.times do |i|
        len = short_block_len - block_ecc_len + (i < num_short_blocks ? 0 : 1)
        dat = data[k, len]
        k += len
        ecc = QrCode.rs_remainder(dat, divisor)
        dat << 0 if i < num_short_blocks
        blocks << dat + ecc
      end

      result = [] of Int32
      blocks[0].size.times do |i|
        blocks.each_with_index do |block, j|
          result << block[i] if i != short_block_len - block_ecc_len || j >= num_short_blocks
        end
      end
      result
    end

    private def draw_codewords(data : Array(Int32)) : Nil
      i = 0
      right = @size - 1
      while right >= 1
        right = 5 if right == 6
        @size.times do |vert|
          2.times do |j|
            x = right - j
            upward = ((right + 1) & 2) == 0
            y = upward ? @size - 1 - vert : vert
            if !@is_function[y][x] && i < data.size * 8
              @modules[y][x] = bit?(data[i >> 3], 7 - (i & 7))
              i += 1
            end
          end
        end
        right -= 2
      end
    end

    private def apply_mask(mask : Int32) : Nil
      @size.times do |y|
        @size.times do |x|
          invert = case mask
                   when 0 then (x + y) % 2 == 0
                   when 1 then y % 2 == 0
                   when 2 then x % 3 == 0
                   when 3 then (x + y) % 3 == 0
                   when 4 then (x // 3 + y // 2) % 2 == 0
                   when 5 then x * y % 2 + x * y % 3 == 0
                   when 6 then (x * y % 2 + x * y % 3) % 2 == 0
                   else        ((x + y) % 2 + x * y % 3) % 2 == 0
                   end
          @modules[y][x] = !@modules[y][x] if invert && !@is_function[y][x]
        end
      end
    end

    # ---- Mask penalty (rules N1–N4) ----

    FINDER_LIKE_A = [true, false, true, true, true, false, true, false, false, false, false]
    FINDER_LIKE_B = [false, false, false, false, true, false, true, true, true, false, true]

    private def penalty_score : Int32
      result = 0

      # N1 (runs of same color) + N3 (finder-like patterns), rows and columns.
      @size.times do |i|
        row = Array(Bool).new(@size) { |x| @modules[i][x] }
        col = Array(Bool).new(@size) { |y| @modules[y][i] }
        result += line_penalty(row) + line_penalty(col)
      end

      # N2: 2x2 blocks of the same color.
      (@size - 1).times do |y|
        (@size - 1).times do |x|
          c = @modules[y][x]
          result += PENALTY_N2 if c == @modules[y][x + 1] && c == @modules[y + 1][x] && c == @modules[y + 1][x + 1]
        end
      end

      # N4: dark/light balance.
      dark = @modules.sum(&.count(&.itself))
      total = @size * @size
      k = ((dark * 20 - total * 10).abs + total - 1) // total - 1
      result += Math.max(k, 0) * PENALTY_N4
      result
    end

    private def line_penalty(line : Array(Bool)) : Int32
      result = 0
      run = 1
      (1...line.size).each do |i|
        if line[i] == line[i - 1]
          run += 1
        else
          result += PENALTY_N1 + (run - 5) if run >= 5
          run = 1
        end
      end
      result += PENALTY_N1 + (run - 5) if run >= 5

      (0..line.size - 11).each do |i|
        window = line[i, 11]
        result += PENALTY_N3 if window == FINDER_LIKE_A || window == FINDER_LIKE_B
      end
      result
    end

    # ---- Static helpers ----

    def self.num_raw_data_modules(ver : Int32) : Int32
      result = (16 * ver + 128) * ver + 64
      if ver >= 2
        num_align = ver // 7 + 2
        result -= (25 * num_align - 10) * num_align - 55
        result -= 36 if ver >= 7
      end
      result
    end

    def self.num_data_codewords(ver : Int32) : Int32
      num_raw_data_modules(ver) // 8 - ECC_CODEWORDS_PER_BLOCK[ver] * NUM_ERROR_CORRECTION_BLOCKS[ver]
    end

    def self.char_count_bits(ver : Int32) : Int32
      ver <= 9 ? 8 : 16
    end

    def self.append_bits(buffer : Array(Bool), value : Int32, length : Int32) : Nil
      (length - 1).downto(0) { |i| buffer << (((value >> i) & 1) != 0) }
    end

    def self.rs_divisor(degree : Int32) : Array(Int32)
      result = Array(Int32).new(degree, 0)
      result[degree - 1] = 1
      root = 1
      degree.times do
        degree.times do |j|
          result[j] = gf_multiply(result[j], root)
          result[j] ^= result[j + 1] if j + 1 < degree
        end
        root = gf_multiply(root, 0x02)
      end
      result
    end

    def self.rs_remainder(data : Array(Int32), divisor : Array(Int32)) : Array(Int32)
      result = Array(Int32).new(divisor.size, 0)
      data.each do |b|
        factor = b ^ result.shift
        result << 0
        divisor.each_with_index { |coef, i| result[i] ^= gf_multiply(coef, factor) }
      end
      result
    end

    def self.gf_multiply(x : Int32, y : Int32) : Int32
      z = 0
      7.downto(0) do |i|
        z = (z << 1) ^ ((z >> 7) * 0x11D)
        z ^= ((y >> i) & 1) * x
      end
      z
    end

    private def bit?(value : Int32, i : Int32) : Bool
      ((value >> i) & 1) != 0
    end
  end
end
