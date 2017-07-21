# CHALLENGE: Create a ruby class that takes an array of objects with the properties of name[String] and awesomeness[Integer].
# The class should be capable responding with the following:
#
# The most awesome person
# The average awesomeness of included persons
# A STDOUT list of the 10 most awesome people

require 'rspec'
require 'ffaker'
require './awesomeness'

describe Awesomeness do
  let(:awesome_people) { 11.times.map {instance_double('Person', name:FFaker::Name.name, awesomeness:rand(1..99))} }
  let(:most_awesome_person)  { instance_double('Person', awesomeness: 100, name:FFaker::Name.name, ) }
  let(:least_awesome_person) { instance_double('Person', awesomeness: 0,   name:FFaker::Name.name, ) }

  subject {Awesomeness.new( @subject_args || awesome_people)}

  describe '.new([obj, obj])' do #bp-followup (vs .initialize)
    it 'accepts an array of objects' do
      array_of_objects = awesome_people
      expect(lambda { Awesomeness.new(array_of_objects) }).to_not raise_error
      expect(subject).to contain_exactly(*array_of_objects)
    end

    describe 'argument array items' do
      it 'must respond_to(name) with a string' do
        @subject_args = [instance_double('Person', name:nil, awesomeness:5)]
        expect(-> {subject}).to raise_error(ArgumentError)
      end

      it 'must respond_to(awesomeness) with an integer' do
        @subject_args =  [instance_double('Person', awesomeness:nil, name:'foo')]
        expect(-> {subject}).to raise_error(ArgumentError)
      end

      it 'raises a helpful error for incorrect arguments' do
        @subject_args = instance_double('RandomObj')
        expect(-> {subject}).to raise_error(ArgumentError, 'Requires an array of objects with the properties of name[String] and awesomeness[Integer].' )
      end
    end
  end

  describe '#most_awesome_person' do
    it 'returns a single record' do
      expect(subject.most_awesome_person.inspect).to match /InstanceDouble\(Person\)/
    end

    it 'returns the person object with the highest awesomeness' do
      @subject_args = awesome_people + [most_awesome_person]
      expect(subject.most_awesome_person).to eql(most_awesome_person)
    end
  end

  describe '#average_awesomeness' do
    it 'returns a float' do
      expect(subject.average_awesomeness).to be_a Float
    end

    it 'returns the average awesomeness of included persons' do
      awesomeness = awesome_people.collect(&:awesomeness)
      avg = awesomeness.inject(:+).to_f / awesomeness.length
      expect(subject.average_awesomeness).to eql(avg)
    end
  end

  describe '#ten_most_awesome_people' do
    it 'returns a plain-text list of the most awesome people' do
      allow($stdout).to receive(:write) #trap STDOUT
      expect(subject.ten_most_awesome_people).to be_a String
      expect(subject.ten_most_awesome_people).not_to match(%r"#{subject.min.name}")
      subject.sort.reverse[0...10].each do |leader|
        expect(subject.ten_most_awesome_people).to match(%r"#{leader.name}")
      end
    end

    it 'returns 10 (or fewer) people' do
      allow($stdout).to receive(:write) #trap STDOUT
      expect(subject.ten_most_awesome_people.scan(/Awesomeness$/).length).to eql(10)
      expect(Awesomeness.new([least_awesome_person]).ten_most_awesome_people.scan(/Awesomeness$/).length).to eql(1)
    end

    it 'prints A STDOUT list of the most awesome people' do
      leaders = subject.sort.reverse[0...10]
      expect(-> {subject.ten_most_awesome_people}).to output(leaders.join("\n")+"\n").to_stdout
    end
  end
end
