require "list_matcher/version"
require 'set'

module List
  class Matcher
    attr_reader :atomic, :backtracking, :bound, :case_insensitive, :trim

    # convenience method for one-off regexen where there's no point in keeping
    # around a pattern generator
    def self.pattern(list, opts={})
      self.new(**opts).pattern list
    end

    def self.unused_chars(list, n=1)
      used = Set.new
      list.compact.map(&:to_s).each do |w|
        w.chars.each{ |c| used << c }
      end
      s = 40
      available = []
      while available.length < n
        c = s.chr
        unless used.include? c
          available << c
        end
        s += 1
      end
      available
    end

    W = Regexp.new '\w'

    def initialize(
          atomic:           true,
          backtracking:     false,
          bound:            false,
          trim:             false,
          case_insensitive: false,
          special:          {}
        )
      @atomic           = atomic
      @backtracking     = backtracking
      @trim             = trim
      @case_insensitive = case_insensitive
      @special          = special.dup
      @bound            = !!bound
      if bound.is_a? Hash
        @word_test   = bound[:test]  || W
        @left_bound  = bound[:left]  || '\b'
        @right_bound = bound[:right] || '\b'
      elsif bound
        @word_test   = W
        @left_bound  = '\b'
        @right_bound = '\b'
      end
      raise "special keys must be characters" if @special.keys.any?{ |k| !( k.is_a?(String) && k.length == 1 ) }
    end

    def pattern(list)
      list = list.compact.map(&:to_s).select{ |s| s.length > 0 }
      list.map!(&:trim).select!{ |s| s.length > 0 } if trim
      list.map!(&:downcase)                         if case_insensitive
      list = list.uniq.sort
      return nil if list.empty?
      
      specials = init_specials list
      if bound
        list = list.map do |w|
          if @word_test === w[0]
            w = specials.left + w
          end
          if @word_test === w[-1]
            w += specials.right
          end
          w
        end
      end
      root = tree list, specials
      root.root = true
      root.flatten
      rx = root.convert
      if case_insensitive
        "(?i:#{rx})"
      elsif atomic && !root.atomic?
        wrap rx
      else
        rx
      end
    end

    def init_specials(list)
      special = @special.dup
      if bound
        l, r = self.class.unused_chars list + @special.keys, 2
        special[l] = @left_bound
        special[r] = @right_bound
      end
      Special.new special, l, r
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

    def tree(list, special)
      if list.size == 1
        Leaf.new self, special, list[0]
      elsif list.all?{ |w| w.length == 1 }
        chars = list.select{ |w| !special.special?(w) }
        if chars.size > 1
          list -= chars
          c = CharClass.new self, chars
        end
        a = Alternate.new self, special, list unless list.empty?
        a.children.unshift c if a && c
        a || c
      elsif c = best_prefix(list)   # found a fixed-width prefix pattern
        if optional = c[1].include?('')
          c[1].reject!{ |w| w == '' }
        end
        c1 = tree c[0], special
        c2 = tree c[1], special
        c2.optional = optional
        Sequence.new self, c1, c2
      elsif c = best_suffix(list)   # found a fixed-width suffix pattern
        if optional = c[0].include?('')
          c[0].reject!{ |w| w == '' }
        end
        c1 = tree c[0], special
        c1.optional = optional
        c2 = tree c[1], special
        Sequence.new self, c1, c2
      else
        grouped = list.group_by{ |w| w[0] }
        chars = grouped.select{ |_, w| w.size == 1 && w[0].size == 1 && !special.special?(w[0]) }.map{ |v, _| v }
        if chars.size > 1
          list -= chars
          c = CharClass.new self, chars
        end
        a = Alternate.new self, special, list
        a.children.unshift c if c
        a
      end
    end

    protected

    def best_prefix(list)
      acceptable = nil
      (1..list.map(&:size).min).each do |l|
        c = {}
        list.each do |w|
          pfx = w[0...l]
          sfx = w[l..-1]
          ( c[pfx] ||= [] ) << sfx
        end
        c = c.to_a.group_by{ |_, v| v }.map{|k,v| [ v.map{|a| a[0] }, k ] }
        if c.size == 1
          acceptable = c[0]
        else
          return acceptable
        end
      end
      acceptable
    end

    def best_suffix(list)
      acceptable = nil
      (1..list.map(&:size).min).each do |l|
        c = {}
        list.each do |w|
          i = w.length - l
          pfx = w[0...i]
          sfx = w[i..-1]
          ( c[sfx] ||= [] ) << pfx
        end
        c = c.to_a.group_by{ |_, v| v }.map{|k,v| [ v.map{|a| a[0] }, k ] }
        if c.size == 1
          acceptable = c[0].reverse
        else
          return acceptable
        end
      end
      acceptable
    end

    class Special
      attr_accessor :special_pattern, :specials, :left, :right

      NULL = Regexp.new '(?!)'

      def initialize(special, left, right)
        @specials = special
        @left = left
        @right = right
        if special.empty?
          @special_pattern = NULL
        else
          @special_pattern = Regexp.new "([#{ Regexp.quote special.keys.sort.join }])"
        end
      end

      def special?(s)
        s.length == 1 && special_pattern === s
      end
    end

    class Node
      attr_accessor :engine, :optional, :special, :root

      def initialize(engine, special)
        @engine = engine
        @special = special
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
                if engine.wrap_size + 2 + repeats.to_s.length + seq.length < seq.length * repeats
                  changed = true
                  copy[start...finish] = wrap(seq) +"{#{repeats}}"
                end
              end
              return copy if changed
            end
          end
        end
        elements
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

      def pfx
        engine.pfx
      end

      def qmark
        engine.qmark
      end

      def need_group?
        optional? || !atomic?
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
          if c.is_a? Sequence
            children.delete_at i
            children.insert i, *c.children
          end
        end
      end
    end

    class CharClass < Node

      def initialize(engine, children)
        super(engine, nil)
        @children = children
      end

      def atomic?
        true
      end

      def flatten; end

      def convert
        rx = if bound && !middle?
          word_chars = children.select{ |c| word_test === c }
          non_word = children - word_chars
          if word_chars.any?
            word_chars = char_class word_chars
            if left?
              word_chars = left_boundary + word_chars
            end
            if right?
              word_chars += right_boundary
            end
          end
          if non_word.any?
            non_word = char_class non_word
          end
          if word_chars && non_word
            wrap word_chars + '|' + non_word
          elsif word_chars
            if need_group?
              wrap word_chars
            else
              word_chars
            end
          else
            non_word
          end
        else
          char_class children
        end
        if optional?
          rx += qmark
        end
        rx
      end

      # takes a list of characters and returns a character class expression matching it
      def char_class(chars)
        rs = ranges(chars)
        if rs.size == 1 && rs[0][0] == rs[0][1]
          Regexp.quote rs[0][0].chr
        else
          mid = rs.map do |s, e|
            if s == e
              Regexp.quote s.chr
            elsif e == s + 1
              "#{ Regexp.quote s.chr }#{ Regexp.quote e.chr }"
            else
              "#{ Regexp.quote s.chr }-#{ Regexp.quote e.chr }"
            end
          end.join
          clean_specials mid
        end
      end

      def clean_specials(s)
        if engine.case_insensitive
          s.gsub! /0-9_a-z/, '\w'
        else
          s.gsub! /0-9A-Z_a-z/, '\w'
        end
        s.gsub! /\t-\r /, '\s'
        s.gsub! /0-9/, '\d'
        if s =~ /^\\\w$/
          s
        else
          "[#{s}]"
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

      def initialize(engine, special, list)
        super(engine, nil)
        @children = list.group_by{ |s| s[0] }.values.map{ |ar| engine.tree( ar, special ) }
      end

      def convert
        rx = children.map(&:convert).join('|')
        finalize wrap(rx)
      end

      def atomic?
        true
      end

    end

    class Leaf < Node

      attr_reader :string

      def initialize(engine, special, string)
        super(engine, special)
        @string = string
      end

      def special?(s)
        special.special? s
      end

      def convert_special(c)
        special.specials[c]
      end

      def atomic?
        string.length == 1
      end

      def convert
        _convert string
      end

      def _convert(s)
        return convert_special(s) if special?(s)
        parts = s.split special.special_pattern
        if parts.length == 1
          finalize rx(parts[0])
        else
          condense parts.map{ |p| _convert(p) }
        end
      end

      def rx(s)
        if s.length < 5
          Regexp.quote s
        else
          condense s.chars.map{ |c| Regexp.quote c }
        end
      end
    end

  end
end
