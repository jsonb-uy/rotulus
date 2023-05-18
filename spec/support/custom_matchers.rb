module CustomMatchers
  class MatchSql
    def initialize(expected)
      @expected = expected
    end

    def matches?(target)
      @target = target.to_s

      flatten(@target) == flatten(expected)
    end

    def failure_message
      "expected SQL \n#{target}\nto match\n#{expected}"
    end

    def failure_message_when_negated
      "expected SQL \n#{target}\nnot to match\n#{expected}"
    end

    private

    attr_reader :expected, :target

    def flatten(sql)
      s = sql.delete("\n").squish!
      s.gsub!('( ', '(')
      s.gsub!(' )', ')')
      s
    end
  end

  # Matches page tables(page#as_table) to test pagination behavior.
  # This supports wildcard matching via '{anything}' to avoid hardcoding
  # dynamic data(e.g. record ids) in the expected table. Also supports boolean
  # value placeholder '{true}' and '{false}' to avoid failures
  # whenever the underlying DB(e.g. SQLite) changes how boolean data is presented.
  class MatchTable
    def initialize(expected)
      @expected = expected.gsub!(/^\s*/, '')
    end

    def matches?(target)
      @target = target.to_s

      flatten(target).match(expected_regex)
    end

    def failure_message
      "expected Page \n#{target}\nto match\n#{expected}"
    end

    def failure_message_when_negated
      "expected Page \n#{target}\nnot to match\n#{expected}"
    end

    private

    attr_reader :expected, :target

    def expected_regex
      expected_pattern = Regexp.escape(flatten(expected))
      expected_pattern.gsub!('\{anything\}', '\S*')
      expected_pattern.gsub!('\{false\}', '[fF0]|(false)')
      expected_pattern.gsub!('\{true\}', '[tT1]|(true)')

      Regexp.new(expected_pattern)
    end

    def flatten(table)
      t = table.dup.squish!
      t.gsub!(/\+\-+\+/, '')    # remove dividers
      t.gsub!(/^\s*/, '')       # remove indentation spaces at the beginning of each line
      t.gsub!(/\s*\|\s*/, '|')  # remove column space paddings
      t
    end
  end

  def match_sql(expected)
    MatchSql.new(expected)
  end

  def match_table(expected)
    MatchTable.new(expected)
  end
end
