require 'bundler/setup'
unless ENV['CI']
  require 'simplecov'
  SimpleCov.start
end
Bundler.require
require 'minitest/autorun'
require 'minitest/mock'

class TestApplication
  def call(_env)
    [200, { 'Content-Type' => 'text/plain' }, [%(
        <html>
          <body>
            <h1>Here are people and animals</h1>
            <div data-people>
              <div data-person class='active' data-rank="1" data-uuid="e94bb2d3-71d2-4efb-abd4-ebc0cb58d19f">
                <h2 data-name>Alice</h2>
                <p data-last-name>Cooper</p>
                <p data-bio>Alice is fun</p>
                <p data-fav-color>Blue</p>
                <p data-age>23</p>
              </div>
              <div data-person' data-rank="3" data-uuid="05bf319e-8d6a-43c2-be37-2dad8ddbe5af">
                <h2 data-name>Bob</h2>
                <p data-last-name>Marley</p>
                <p data-bio>Bob is smart</p>
                <p data-fav-color>Red</p>
                <p data-age>52</p>
              </div>
              <div data-person' data-rank="2" data-uuid="4abcdeff-1d36-44a9-a05e-8fc57564d2c4">
                <h2 data-name>Charlie</h2>
                <p data-last-name>Murphy</p>
                <p data-bio>Charlie is wild</p>
                <p data-fav-color>Red</p>
              </div>
              <div data-person' data-rank="7" data-blocked data-uuid="2afccde0-5d13-41c7-ab01-7f37fb2fe3ee">
                <h2 data-name>Donna</h2>
                <p data-last-name>Summer</p>
                <p data-bio>Donna is quiet</p>
              </div>
            </div>
            <div data-animals></div>
            <div data-receipts>
              <div data-receipt id='receipt-72' data-store='ACME'></div>
            </div>
          </body>
        </html>
    )]]
  end
end

Capybara.app = TestApplication.new

class DominoTest < MiniTest::Unit::TestCase
  include Capybara::DSL
  module Dom
    class Person < Domino
      selector '[data-people] [data-person]'
      attribute :name
      attribute :last_name
      attribute :biography, '[data-bio]'
      attribute :favorite_color, '[data-fav-color]'
      attribute :age, &:to_i
      attribute :rank, '&[data-rank]', &:to_i
      attribute :active, '&.active'
      attribute :uuid, '&[data-uuid]'
      attribute(:blocked, '&[data-blocked]') { |a| !a.nil? }
    end

    class Animal < Domino
      selector '[data-animals] [data-animal]'
      attribute :name
    end

    class Car < Domino
      selector '[data-cars] [data-car]'
    end

    class NoSelector < Domino
    end

    class Receipt < Domino
      selector '[data-receipts] [data-receipt]'
    end
  end

  def setup
    visit '/'
  end

  def test_enumerable
    assert_equal 4, Dom::Person.count
    assert_equal 0, Dom::Animal.count
    assert_equal 0, Dom::Car.count

    assert_equal 4, Dom::Person.all.size

    red_people = Dom::Person.select { |p| p.favorite_color == 'Red' }
    assert_equal 2, red_people.count

    assert_equal(
      %w[Donna Alice Bob Charlie],
      Dom::Person.sort do |a, b|
        a.favorite_color.to_s <=> b.favorite_color.to_s
      end.map(&:name)
    )
  end

  def test_no_selector
    assert_raises Domino::Error do
      Dom::NoSelector.first
    end
  end

  def test_no_id
    assert_nil Dom::Person.first.id
  end

  def test_id
    assert_equal '#receipt-72', Dom::Receipt.first.id
  end

  def test_find_by_attribute_string
    assert_equal 'Alice', Dom::Person.find_by_biography('Alice is fun').name
  end

  def test_default_selector
    assert_equal 'Cooper', Dom::Person.find_by_name('Alice').last_name
  end

  def test_find_by_attribute_regex
    assert_equal 'Charlie', Dom::Person.find_by_biography(/wild/).name
  end

  def test_find_by_data_combinator_attribute_regex
    assert_equal 'Charlie', Dom::Person.find_by_uuid(/abcdef/).name
  end

  def test_node_properties
    assert_equal 'ACME', Dom::Receipt.first.node['data-store']
  end

  def test_attributes
    assert_equal({ name: 'Alice', last_name: 'Cooper', biography: 'Alice is fun', favorite_color: 'Blue', age: 23, rank: 1, active: true, uuid: 'e94bb2d3-71d2-4efb-abd4-ebc0cb58d19f', blocked: false }, Dom::Person.first.attributes)
  end

  def test_callback
    assert_equal 23, Dom::Person.find_by_name('Alice').age
  end

  def test_find_bang
    assert_equal '#receipt-72', Dom::Receipt.find!.id
  end

  def test_find_bang_without_match
    assert_raises Capybara::ElementNotFound do
      Dom::Animal.find!
    end
  end

  def test_find_bang_without_selector
    assert_raises Domino::Error do
      Dom::NoSelector.find!
    end
  end

  def test_find_by
    assert_equal 'Alice', Dom::Person.find_by(biography: 'Alice is fun').name
  end

  def test_find_by_with_multiple_attributes
    assert_equal 'Alice', Dom::Person.find_by(biography: 'Alice is fun', age: 23, favorite_color: 'Blue', rank: 1).name
  end

  def test_find_by_without_match
    assert_nil Dom::Person.find_by(foo: 'bar')
  end

  def test_find_by_without_selector
    assert_raises Domino::Error do
      Dom::NoSelector.find_by(foo: 'bar')
    end
  end

  def test_find_by_class_combinator_attribute
    assert_equal 'Alice', Dom::Person.find_by(active: true).name
  end

  def test_find_by_data_key_combinator_attribute
    assert_equal 'Donna', Dom::Person.find_by(blocked: true).name
  end

  def test_find_by_data_combinator_attribute
    assert_equal 'Charlie', Dom::Person.find_by(rank: 2).name
  end

  def test_find_by_bang
    assert_equal 'Alice', Dom::Person.find_by!(biography: 'Alice is fun').name
  end

  def test_find_by_bang_with_multiple_attributes
    assert_equal 'Alice', Dom::Person.find_by!(biography: 'Alice is fun', age: 23, favorite_color: 'Blue', rank: 1).name
  end

  def test_find_by_bang_without_selector
    assert_raises Domino::Error do
      Dom::NoSelector.find_by(foo: 'bar')
    end
  end

  def test_find_by_bang_without_match
    assert_raises Capybara::ElementNotFound do
      Dom::Person.find_by!(foo: 'bar')
    end
  end

  def test_where_with_single_attribute
    assert_equal %w[Bob Charlie], Dom::Person.where(favorite_color: 'Red').map(&:name)
  end

  def test_where_with_multiple_attributes
    assert_equal %w[Alice], Dom::Person.where(age: 23, favorite_color: 'Blue').map(&:name)
  end

  def test_where_with_class_combinator_attribute
    assert_equal %w[Bob Charlie Donna], Dom::Person.where(active: false).map(&:name)
  end

  def test_where_with_data_key_combinator_attribute
    assert_equal %w[Donna], Dom::Person.where(blocked: true).map(&:name)
  end

  def test_where_without_match
    assert_equal [], Dom::Person.where(favorite_color: 'Yellow')
  end

  def test_where_without_selector
    assert_raises Domino::Error do
      Dom::NoSelector.where(foo: 'bar')
    end
  end
end
