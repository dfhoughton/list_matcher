require "list_matcher/version"

module List
  class Matcher
    attr_reader :atomic, :backtracking, :bound, :case_insensitive, :trim, :left_bound, :right_bound, :word_test, :normalize_whitespace, :multiline, :name, :vet

    # convenience method for one-off regexen where there's no point in keeping
    # around a pattern generator
    def self.pattern(list, opts={})
      self.new(**opts).pattern list
    end

    # like self.pattern, but returns a regex rather than a string
    def self.rx(list, opts={})
      self.new(**opts).rx list
    end

    # to make a replacement of Regexp.quote that ignores characters that only need quoting inside character classes
    QRX = Regexp.new "([" + ( (1..255).map(&:chr).select{ |c| Regexp.quote(c) != c } - %w(-) ).map{ |c| Regexp.quote c }.join + "])"

    def initialize(
          atomic:               true,
          backtracking:         true,
          bound:                false,
          trim:                 false,
          case_insensitive:     false,
          multiline:            false,
          normalize_whitespace: false,
          symbols:              {},
          name:                 false,
          vet:                  false
        )
      @atomic               = atomic
      @backtracking         = backtracking
      @trim                 = trim || normalize_whitespace
      @case_insensitive     = case_insensitive
      @multiline            = multiline
      @symbols              = deep_dup symbols
      @_bound               = bound
      @bound                = !!bound
      @normalize_whitespace = normalize_whitespace
      @vet                  = vet
      if name
        raise "" unless name.is_a?(String) || name.is_a?(Symbol)
        if Regexp.new "(?<#{name}>.*)"   # stir up any errors that might arise from using this name in a named capture
          @name = name
        end
      end
      if bound == :string
        @word_test   = /./
        @left_bound  = '\A'
        @right_bound = '\z'
      elsif bound == :line
        @word_test   = /./
        @left_bound  = '^'
        @right_bound = '$'
      elsif bound.is_a? Hash
        @word_test   = bound[:test]  || /\w/
        @left_bound  = bound[:left]  || '\b'
        @right_bound = bound[:right] || '\b'
      elsif bound === true || bound == :word
        @word_test   = /\w/
        @left_bound  = '\b'
        @right_bound = '\b'
      elsif !( bound === false )
        raise "unfamiliar value for :bound option: #{bound.inspect}"
      end
      if normalize_whitespace
        @symbols[' '] = { pattern: '\s++' }
      end
      symbols.keys.each do |k|
        raise "symbols variable #{k} is neither a string, a symbol, nor a regex" unless k.is_a?(String) || k.is_a?(Symbol) || k.is_a?(Regexp)
      end
      if vet
        Special.new( self, @symbols, [] ).verify
      end
    end

    # returns a new pattern matcher differing from the original only in the options specified
    def bud(opts={})
      opts = {
        atomic:               @atomic,
        backtracking:         @backtracking,
        bound:                @_bound,
        trim:                 @trim,
        case_insensitive:     @case_insensitive,
        multiline:            @multiline,
        normalize_whitespace: @normalize_whitespace,
        symbols:              @symbols,
        name:                 @name,
        vet:                  @vet && opts[:symbols]
      }.merge opts
      self.class.new(**opts)
    end

    # converst list into a string representing a regex pattern suitable for inclusion in a larger regex
    def pattern( list, opts={} )
      return bud(opts).pattern list unless opts.empty?
      list = list.compact.map(&:to_s).select{ |s| s.length > 0 }
      list.map!(&:strip).select!{ |s| s.length > 0 } if trim
      list.map!{ |s| s.gsub /\s++/, ' ' } if normalize_whitespace
      return nil if list.empty?
      specializer = Special.new self, @symbols, list
      list = specializer.normalize

      root = tree list, specializer
      root.root = true
      root.flatten
      rx = root.convert
      if m = modifiers
        rx = "(?#{m}:#{rx})"
        grouped = true
      end
      if name
        rx = "(?<#{name}>#{rx})"
        grouped = true
      end
      return rx if grouped && backtracking
      if atomic && !root.atomic?
        wrap rx
      else
        rx
      end
    end

    def modifiers
      ( @modifiers ||= if case_insensitive || multiline
        [ ( 'i' if case_insensitive ), ( 'm' if multiline ) ].compact.join
      else
        [nil]
      end )[0]
    end

    # like pattern but it returns a regex instead of a string
    def rx(list, opts={})
      Regexp.new pattern(list, opts)
    end

    def pfx
      @pfx ||= backtracking ? '(?:' : '(?>'
    end

    def qmark
      @qmark ||= backtracking ? '?' : '?+'
    end

    def wrap(s)
      pfx + s + ')'
    end

    def wrap_size
      @wrap_size ||= pfx.length + 1
    end

    def tree(list, symbols)
      if list.size == 1
        leaves = list[0].chars.map do |c|
          symbols.symbols(c) || Leaf.new( self, c )
        end
        if leaves.length == 1
          leaves.first
        else
          Sequence.new self, *leaves
        end
      elsif list.all?{ |w| w.length == 1 }
        chars = list.select{ |w| !symbols.symbols(w) }
        if chars.size > 1
          list -= chars
          c = CharClass.new self, chars
        end
        a = Alternate.new self, symbols, list unless list.empty?
        a.children.unshift c if a && c
        a || c
      elsif c = best_prefix(list)   # found a fixed-width prefix pattern
        if optional = c[1].include?('')
          c[1].reject!{ |w| w == '' }
        end
        c1 = tree c[0], symbols
        c2 = tree c[1], symbols
        c2.optional = optional
        Sequence.new self, c1, c2
      elsif c = best_suffix(list)   # found a fixed-width suffix pattern
        if optional = c[0].include?('')
          c[0].reject!{ |w| w == '' }
        end
        c1 = tree c[0], symbols
        c1.optional = optional
        c2 = tree c[1], symbols
        Sequence.new self, c1, c2
      else
        grouped = list.group_by{ |w| w[0] }
        chars = grouped.select{ |_, w| w.size == 1 && w[0].size == 1 && !symbols.symbols(w[0]) }.map{ |v, _| v }
        if chars.size > 1
          list -= chars
          c = CharClass.new self, chars
        end
        a = Alternate.new self, symbols, list
        a.children.unshift c if c
        a
      end
    end

    def self.quote(s)
      s.gsub(QRX) { |c| Regexp.quote c }
    end

    def quote(s)
      self.class.quote s
    end

    protected

    def deep_dup(o)
      if o.is_a?(Hash)
        Hash[o.map{ |k, v| [ deep_dup(k), deep_dup(v) ] }]
      elsif o.is_a?(Array)
        o.map{ |v| deep_dup v }
      elsif o.nil? || o.is_a?(Symbol)
        o
      else
        o.dup
      end
    end

    def best_prefix(list)
      acceptable = nil
      sizes      = list.map(&:size)
      min        = sizes.reduce 0, :+
      sizes.uniq!
      lim = sizes.count == 1 ? list[0].size - 1 : sizes.min
      (1..lim).each do |l|
        c = {}
        list.each do |w|
          pfx = w[0...l]
          sfx = w[l..-1]
          ( c[pfx] ||= [] ) << sfx
        end
        c = cross_products c
        if c.size == 1
          count = count(c)
          if count < min
            min = count
            acceptable = c[0]
          end
        end
      end
      acceptable
    end

    def best_suffix(list)
      acceptable = nil
      sizes      = list.map(&:size)
      min        = sizes.reduce 0, :+
      sizes.uniq!
      lim = sizes.count == 1 ? list[0].size - 1 : sizes.min
      (1..lim).each do |l|
        c = {}
        list.each do |w|
          i   = w.length - l
          pfx = w[0...i]
          sfx = w[i..-1]
          ( c[sfx] ||= [] ) << pfx
        end
        c = cross_products c
        if c.size == 1
          count = count(c)
          if count < min
            min = count
            acceptable = c[0].reverse
          end
        end
      end
      acceptable
    end

    # discover cross products -- e.g., {this, that} X {cat, dog}
    def cross_products(c)
      c.to_a.group_by{ |_, v| v.sort }.map{ |k,v| [ v.map{ |a| a[0] }.sort, k ] }
    end

    def count(c)
      c = c[0]
      c[0].map(&:size).reduce( 0, :+ ) + c[1].map(&:size).reduce( 0, :+ )
    end

    class Special
      attr_reader :engine
      attr_accessor :specials, :list, :left, :right

      NULL = Regexp.new '(?!)'

      def initialize( engine, specials, list )
        @engine = engine
        @list = list
        max = 0
        list.each do |w|
          w.chars.each{ |c| i = c.ord; max = i if i > max }
        end
        @specials = [].tap do |ar|
          specials.sort do |a, b|
            a = a.first
            b = b.first
            s1 = a.is_a?(String) || a.is_a?(Symbol)
            s2 = b.is_a?(String) || b.is_a?(Symbol)
            if s1 && s2
              b.to_s <=> a.to_s
            elsif s1
              -1
            elsif s2
              1
            else
              s = a.to_s.length - b.to_s.length
              s == 0 ? a.to_s <=> b.to_s : s
            end
          end.each do |var, opts|
            c = ( max += 1 ).chr
            sp = if opts.is_a? Hash
              pat = opts.delete :pattern
              raise "variable #{var} requires a pattern" unless pat || var.is_a?(Regexp)
              pat ||= var.to_s
              SpecialPattern.new engine, c, var, pat, **opts
            elsif opts.is_a? String
              SpecialPattern.new engine, c, var, opts
            elsif var.is_a?(Regexp) && opts.nil?
              SpecialPattern.new engine, c, var, nil
            else
              raise "variable #{var} requires a pattern"
            end
            ar << sp
          end
        end
        if engine.bound
          c = ( max += 1 ).chr
          @left = SpecialPattern.new engine, c, c, engine.left_bound
          @specials << @left
          c = ( max += 1 ).chr
          @right = SpecialPattern.new engine, c, c, engine.right_bound
          @specials << @right
        end
      end

      # confirm that all special patterns are legitimate regexen
      def verify
        specials.each do |s|
          begin
            Regexp.new s.pat
          rescue
            raise SyntaxError.new "the symbol #{s.var} has an ill-formed pattern: #{s.pat}"
          end
        end
      end

      def special_map
        @special_map ||= {}
      end

      def symbols(s)
        special_map[s]
      end

      # reduce the list to a version ready for pattern generation
      def normalize
        rx = if specials.empty?
          NULL
        else
          Regexp.new '(' + specials.map(&:var).map(&:to_s).join('|') + ')'
        end
        l = r = false
        list = self.list.uniq.map do |w|
          parts = w.split rx
          e = parts.size - 1
          (0..e).map do |i|
            p = parts[i]
            if rx === p
              p = specials.detect{ |sp| sp.var === p }
              special_map[p.char] = p
              if engine.bound
                if i == 0 && p.left
                  p = "#{left}#{p}" if t
                  l = true
                end
                if i == e && p.right
                  p = "#{p}#{right}"
                  r = true
                end
              end
            else
              p = p.downcase if engine.case_insensitive
              if engine.bound
                if i == 0 && engine.word_test === p[0]
                  p = "#{left}#{p}"
                  l = true
                end
                if i == e && engine.word_test === p[-1]
                  p = "#{p}#{right}"
                  r = true
                end
              end
            end
            p
          end.join
        end.uniq.sort
        special_map[left.char] = left if l
        special_map[right.char] = right if r
        list
      end
    end

    class Node
      attr_accessor :engine, :optional, :symbols, :root

      def initialize(engine, symbols)
        @engine = engine
        @symbols = symbols
        @children = []
      end

      def flatten
        children.each{ |c| c.flatten }
      end

      def root?
        root
      end

      def bound
        engine.bound
      end

      def optional?
        optional
      end

      def children
        @children ||= []
      end

      def convert
        raise NotImplementedError
      end

      def pfx
        engine.pfx
      end

      def qmark
        engine.qmark
      end

      def finalize(rx)
        if optional?
          rx = wrap rx unless atomic?
          rx += qmark
        end
        rx
      end

      def wrap(s)
        engine.wrap s
      end

      def atomic?
        false
      end

      def quote(s)
        engine.quote s
      end

    end

    class SpecialPattern < Node
      attr_accessor :char, :var, :left, :right, :pat
      def initialize(engine, char, var, pat, atomic: (var.is_a?(Regexp) && pat.nil?), word_left: false, word_right: false)
        super(engine, nil)
        @char = char
        @var = var.is_a?(String) || var.is_a?(Symbol) ? Regexp.new(Regexp.quote(var.to_s)) : var
        @pat = pat || var.to_s
        @atomic = !!atomic
        @left = !!word_left
        @right = !!word_right
      end

      def left?
        @left
      end

      def right?
        @right
      end

      def atomic?
        @atomic
      end

      def to_s
        self.char
      end

      def convert
        rx = @pat
        finalize rx
      end
    end

    class Sequence < Node

      def initialize(engine, *constituents)
        super(engine, nil)
        @children = constituents
      end

      def convert
        rx = condense children.map(&:convert)
        finalize rx
      end

      def flatten
        super
        (0...children.size).to_a.reverse.each do |i|
          c = children[i]
          if c.is_a?(Sequence) && !c.optional?
            children.delete_at i
            children.insert i, *c.children
          end
        end
      end

      # looks for repeating subsequences, as in ababababab, and condenses them to (?>ab){5}
      # condensation is only done when it results in a more compact regex
      def condense_repeats(elements)
        (1..(elements.size/2)).each do |l|            # length of subsequence considered
          (0...l).each do |o|                         # offset from the start of the sequence
            dup_count = []
            (1...(elements.size - o)/l).each do |s|   # the sub-sequence number
              s2 = s * l + o
              s1 = s2 - l
              seq1 = elements[s1...s1 + l]
              seq2 = elements[s2...s2 + l]
              if seq1 == seq2
                s0 = s - 1
                counts = dup_count[s] = dup_count[s0] || [ 1, seq1.join, s1, nil ]
                counts[0] += 1
                counts[3]  = s2 + l
                dup_count[s0] = nil
              end
            end
            dup_count.compact!
            if dup_count.any?
              copy = elements.dup
              changed = false
              dup_count.reverse.each do |repeats, seq, start, finish|
                a  = atomy? seq
                sl = seq.length
                if ( a ? 0 : engine.wrap_size ) + 2 + repeats.to_s.length + sl < sl * repeats
                  changed = true
                  copy[start...finish] = ( a ? seq : wrap(seq) ) + "{#{repeats}}"
                end
              end
              return copy if changed
            end
          end
        end
        elements
      end

      # infer atomic patterns
      def atomy?(s)
        s.size == 1 || /\A(?>\\\w|\[(?>[^\[\]\\]|\\.)++\])\z/ === s
      end

      # iterated repeat condensation
      def condense(elements)
        while elements.size > 1
          condensate = condense_repeats elements
          break if condensate == elements
          elements = condensate
        end
        elements.join
      end
    end

    class CharClass < Node

      attr_accessor :word, :num, :space

      WORD_CHARS    = (1..255).map(&:chr).select{ |c| /\w/ === c }.freeze
      CI_WORD_CHARS = WORD_CHARS.map(&:downcase).uniq.freeze
      NUM_CHARS     = CI_WORD_CHARS.select{ |c| /\d/ === c }.freeze
      SPACE_CHARS   = (1..255).map(&:chr).select{ |c| /\s/ === c }.freeze

      def initialize(engine, children)
        super(engine, nil)
        if engine.case_insensitive
          if ( CI_WORD_CHARS - children ).empty?
            self.word = true
            self.num = false
            children -= CI_WORD_CHARS
          end
        elsif ( WORD_CHARS - children ).empty?
          self.word = true
          self.num = false
          children -= WORD_CHARS
        end
        if num.nil? && ( NUM_CHARS - children ).empty?
          self.num = true
          children -= NUM_CHARS
        end
        if ( SPACE_CHARS - children ).empty?
          self.space = true
          children -= SPACE_CHARS
        end
        @children = children
      end

      def atomic?
        true
      end

      def flatten; end

      def convert
        rx = char_class children
        if optional?
          rx += qmark
        end
        rx
      end

      # takes a list of characters and returns a character class expression matching it
      def char_class(chars)
        mid = if chars.empty?
          ''
        else
          rs = ranges(chars)
          if rs.size == 1 && rs[0][0] == rs[0][1]
            cc_quote rs[0][0].chr
          else
            mid = rs.map do |s, e|
              if s == e
                cc_quote s.chr
              elsif e == s + 1
                "#{ cc_quote s.chr }#{ cc_quote e.chr }"
              else
                "#{ cc_quote s.chr }-#{ cc_quote e.chr }"
              end
            end.join
          end
        end
        mid += '\w' if word
        mid += '\d' if num
        mid += '\s' if space
        if mid.length == 1 || mid =~ /\A\\\w\z/
          mid
        else
          "[#{mid}]"
        end
      end

      def cc_quote(c)
        return Regexp.quote(c) if c =~ /\s/
        case c
        when '[' then '\['
        when ']' then '\]'
        when '\\' then '\\\\'
        when '-' then '\-'
        when '^' then '\^'
        else c
        end
      end

      def ranges(chars)
        chars = chars.map(&:ord).sort
        rs = []
        c  = chars.shift
        r  = [ c, c ]
        while chars.size > 0
          c = chars.shift
          if c == r[1] + 1
            r[1] = c
          else
            rs << r
            r = [ c, c ]
          end
        end
        rs << r
      end
    end

    class Alternate < Node

      def initialize(engine, symbols, list)
        super(engine, nil)
        @children = list.group_by{ |s| s[0] }.values.map{ |ar| engine.tree( ar, symbols ) }
      end

      def convert
        rx = children.map(&:convert).join('|')
        rx = wrap(rx) unless root?
        finalize rx
      end

      def atomic?
        !root?
      end

    end

    class Leaf < Node

      attr_reader :c

      def initialize(engine, c)
        super(engine, nil)
        @c = c
      end

      def atomic?
        true
      end

      def convert
        rx = quote c
        finalize rx
      end
    end

  end
end
