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

    def tree(list, special)
      root = if list.size == 1
        Leaf.new self, special, list[0]
      else
        if prefix = find_prefix(list)
          l = prefix.length
          remainder = list.map{ |s| s[l..-1] }.select{ |s| s.length > 0 }
        end
        body = find_body( special, remainder || list )
        if prefix
          body.optional = prefix.length == list[0].length
          prefix = Leaf.new self, special, prefix
          Sequence.new self, prefix, body
        else
          body
        end
      end
      root
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

    protected

    def find_prefix(list)
      last_candidate = nil
      (0...list[0].length).each do |l|
        candidate = list[0][0..l]
        (1...list.length).each do |w|
          return last_candidate unless list[w][0..l] == candidate
        end
        last_candidate = candidate
      end
      return last_candidate
    end

    def find_suffix(list)
      (1...list[0].length).each do |l|
        candidate = list[0][l..-1]
        bad = false
        (1...list.length).each do |w|
          if list[w][l..-1] != candidate
            bad = true
            break
          end
        end
        return candidate unless bad
      end
      nil
    end

    def find_body(special, list)
      if list.size == 1
        Leaf.new self, special, list[0]
      else
        if sfx = find_suffix(list)
          l = sfx.length
          list = list.map{ |w| w[0...-l] }
        end
        chars = list.select{ |w| w.length == 1 && !special.special?(w) }
        body = if chars.length > 1
          list -= chars
          if list.empty?
            CharClass.new self, chars
          else
            c = CharClass.new self, chars
            a = list.size == 1 ? Leaf.new( self, special, list[0] ) : Alternate.new( self, special, list )
            a.children.unshift c
            a
          end
        else
          Alternate.new( self, special, list )
        end
        if sfx
          sfx = Leaf.new self, special, sfx
          Sequence.new self, body, sfx
        else
          body
        end
      end
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
        constituents = children.map(&:convert)
        rx = constituents.join
        finalize rx
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
          parts.map{ |p| _convert(p) }.join
        end
      end

      def self.dup_seq(i)
        ( @dup_seq ||= [] )[i] ||= begin
          seq = '.' * i
          rx = Regexp.new "(#{seq})\\1+"
          lambda do |leaf, st|
            if m = rx.match(st)
              repeats = m[0].length / i
              counter = "){#{repeats}}"
              mid = leaf.rx(m.captures[0])
              if mid.length * ( repeats - 1 ) > leaf.pfx.length + counter.length
                pfx = m.pre_match
                sfx = m.post_match
                return leaf.rx(pfx) + leaf.pfx + mid + counter + leaf.rx(sfx)
              end
            end
          end
        end
      end

      def rx(s)
        if s.length < 4
          Regexp.quote s
        else
          lim = ( s.length / 2.0 ).to_i
          (1..lim).to_a.reverse.each do |i|
            m = self.class.dup_seq i
            r = m.( self, s )
            return r if r
          end
          Regexp.quote s
        end
      end
    end

  end
end
