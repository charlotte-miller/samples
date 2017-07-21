# CHALLENGE: Create a ruby class that takes an array of objects with the properties of name[String] and awesomeness[Integer].
# The class should be capable responding with the following:
#
# The most awesome person
# The average awesomeness of included persons
# A STDOUT list of the 10 most awesome people

class Awesomeness < Array

  def initialize(people_array)
    is_valid = people_array.respond_to?(:all?) && people_array.all? do |person|
      person.respond_to?(:name) \
      && person.name.is_a?(String) \
      && person.respond_to?(:awesomeness) \
      && person.awesomeness.is_a?(Integer)
    end
    raise ArgumentError.new("Requires an array of objects with the properties of name[String] and awesomeness[Integer].") unless is_valid

    # Make comparable & printable
    people_array.each do |person|
      def person.<=> other
        awesomeness <=> other.awesomeness
      end

      def person.to_s
        "#{name} with #{awesomeness} Awesomeness"
      end
    end

    super #Array
  end

  alias_method :most_awesome_person, :max

  def average_awesomeness
    awesome_sum.to_f / size
  end

  def ten_most_awesome_people
    awesome_leaders = sort.reverse[0...10].join("\n")
    puts awesome_leaders
    awesome_leaders
  end

private
  def awesome_sum
    collect(&:awesomeness).inject(:+)
  end

end