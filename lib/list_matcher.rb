require "list_matcher/version"

module List
  class Matcher
    attr_reader :atomic, :backtracking, :bound, :case_insensitive, :trim

    # convenience method for one-off regexen where there's no point in keeping
    # around a pattern generator
    def self.pattern(list, opts={})
      self.new(**opts).pattern list
    end

    def initialize(
          atomic:           true,
          backtracking:     false,
          bound:            false,
          trim:             false,
          case_insensitive: false
        )
      @atomic           = atomic
      @backtracking     = backtracking
      @trim             = trim
      @case_insensitive = case_insensitive
      @bound            = bound
    end

    def pattern(list)
      list = list.compact.map(&:to_s).select{ |s| s.length > 0 }
      list.map!(&:trim).select!{ |s| s.length > 0 } if trim
      list.map!(&:downcase)                         if case_insensitive
      list = list.uniq.sort
      return nil if list.empty?
      root = tree list, nil
      rx = root.convert
      if case_insensitive
        "(?i:#{rx})"
      elsif atomic
        wrap rx
      else
        rx
      end
    end

    def tree(list, parent)
      root = if list.size == 1
        Leaf.new self, list[0]
      else
        if prefix = find_prefix(list)
          l = prefix.length
          remainder = list.map{ |s| s[l..-1] }.select{ |s| s.length > 0 }
        end
        body = find_body( remainder || list )
        if prefix
          body.optional = prefix.length == list[0].length
          prefix = Leaf.new self, prefix
          s = Sequence.new self, prefix, body
          prefix.parent = s
          body.parent = s
          s
        else
          body
        end
      end
      root.parent = parent
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

    def find_body(list)
      if list.size == 1
        Leaf.new self, list[0]
      else
        if sfx = find_suffix(list)
          l = sfx.length
          list = list.map{ |w| w[0...-l] }
        end
        chars = list.select{ |w| w.length == 1 }
        body = if chars.length > 1
          list -= chars
          if list.empty?
            CharClass.new self, chars
          else
            c = CharClass.new self, chars
            a = list.size == 1 ? Leaf.new( self, list[0] ) : Alternate.new( self, list )
            c.parent = a
            a.children.unshift c
            a
          end
        else
          Alternate.new( self, list )
        end
        if sfx
          sfx = Leaf.new self, sfx
          s = Sequence.new self, body, sfx
          body.parent = s
          sfx.parent = s
          s
        else
          body
        end
      end
    end

    class Node
      attr_accessor :parent, :engine, :optional

      def initialize(n)
        @engine = n
        @children = []
      end

      def root?
        parent.nil?
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

      def char?
        false
      end

      def left_child(n)
        children[0] == n
      end

      def right_child(n)
        children[-1] == n
      end

      def left?
        return @left unless @left.nil?
        @left = if root?
          true
        else
          parent.left_child self
        end
      end
      def right?
        return @right unless @right.nil?
        @right = if root?
          true
        else
          parent.right_child self
        end
      end

      def middle?
        if root?
          false
        else
          !( left? || right? )
        end
      end

      def left_boundary
        '\b'
      end

      def right_boundary
        '\b'
      end

      def word_test
        /\w/
      end

      def pfx
        engine.pfx
      end

      def qmark
        engine.qmark
      end

      def bound
        engine.bound
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
        super(engine)
        @children = constituents
      end

      def convert
        constituents = children.map(&:convert)
        rx = constituents.join('')
        finalize rx
      end

    end

    class CharClass < Node

      def initialize(engine, children)
        super(engine)
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
          end.join ''
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

      def initialize(engine, list)
        super(engine)
        @children = list.group_by{ |s| s[0] }.values.map{ |ar| engine.tree( ar, self ) }
      end

      def left_child(n)
        left?
      end

      def right_child(n)
        right?
      end

      def convert
        rx = children.map(&:convert).join('|')
        rx = wrap rx unless root?
        finalize rx
      end

      def atomic?
        true
      end

    end

    class Leaf < Node

      attr_reader :string

      def initialize(engine, string)
        super(engine)
        @string = string
      end

      def atomic?
        string.length == 1
      end

      def convert
        r = if bound
          t1 = left? && word_test === string[0]
          t2 = right? && word_test === string[-1]
          [ ( left_boundary if t1 ), rx(string), ( right_boundary if t2 ) ].compact.join ''
        else
          rx(string)
        end
        finalize r
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
