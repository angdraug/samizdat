# -*- encoding: utf-8 -*-
# vim: et sw=2 sts=2 ts=8 tw=0

class Equation
  MATHOPS = [ [:+, '+'], [:-, '–'], [:*, '×'], [:/, ':'] ]

  def initialize(numbers, action)
    @numbers = numbers
    @action  = action
  end

  def to_s
    "#{@numbers[0]}#{@action[1]}#{@numbers[1]}"
  end

  def result
    @numbers[0].send(@action[0], @numbers[1])
  end

  def self.generate
    srand
    numbers = [ 10 + rand(90), 2 + rand(9) ]
    action = MATHOPS[ rand(100) % MATHOPS.size ]
    if action[0] == :/
      if numbers[0] % numbers[1] != 0
        numbers[0] = numbers[0].div(numbers[1]) * numbers[1]
      end
    end
    Equation.new( numbers, action )
  end
end
