require 'list_matcher'

m = List::Matcher.new atomic: false, bound: true

year      = m.pattern( (1901..2000).to_a, name: :year )
mday      = m.pattern( (1..31).to_a, name: :mday )
weekdays  = %w( Monday Tuesday Wednesday Thursday Friday Saturday Sunday )
weekdays += weekdays.map{ |w| w[0...3] }
wday      = m.pattern weekdays, case_insensitive: true, name: :wday
months    = %w( January February March April May June July August September October November December )
months   += months.map{ |w| w[0...3] }
mo        = m.pattern months, case_insensitive: true, name: :mo

date_20th_century = m.rx(
  [
    'wday, mo mday',
    'wday, mo mday year',
    'mo mday, year',
    'mo year',
    'wday',
    'year',
    'mday mo',
    'mo mday',
    'mo mday year'
  ],
  normalize_whitespace: true,
  atomic: true,
  special: {
    year: year,
    mday: mday,
    wday: wday,
    mo:   mo
  }
)

[
  'Friday',
  'August 27',
  'May 6, 1969',
  'Jan 1 2000',
  'this is not actually a date'
].each do |candidate|
  if m = date_20th_century.match(candidate)
    puts "candidate: #{candidate}; year: #{m[:year]}; month: #{m[:mo]}; weekday: #{m[:wday]}; day of the month: #{m[:mday]}"
  else
    puts "#{candidate} does not look like a plausible date in the 20th century"
  end
end