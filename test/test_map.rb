require File.expand_path(File.dirname(__FILE__) + '/helper')

class TestHazelcastMap < Test::Unit::TestCase

  java_import 'com.hazelcast.query.SqlPredicate'

  def test_same_object
    hash = CLIENT.map :test_same_object
    map  = CLIENT.map :test_same_object
    hash.clear
    assert_equal hash.name, map.name
    hash[:a] = 1
    assert_equal hash[:a], map[:a]
  end

  def test_string_keys
    hash = CLIENT.map :test_string_keys
    hash.clear

    hash[:a] = 1
    assert_equal hash['a'], 1
    assert_equal hash[:a], 1

    hash['b'] = 2
    assert_equal hash[:b], 2

    hash[Date.new(2010, 3, 18)] = 3
    assert_equal hash['2010-03-18'], 3

    hash[4] = 4
    assert_equal hash['4'], 4
    assert_equal hash[4], 4
  end

  def test_predicates
    map = CLIENT.map :test_predicates

    predicate = map.prepare_predicate 'active = false AND (age = 45 OR name = \'Joe Mategna\')'
    assert_kind_of Java::ComHazelcastQuery::SqlPredicate, predicate
    assert_equal '(active=false AND (age=45 OR name=Joe Mategna))', predicate.to_s

    predicate = map.prepare_predicate :quantity => 3
    assert_kind_of Java::ComHazelcastQuery::SqlPredicate, predicate
    assert_equal 'quantity=3', predicate.to_s

    predicate = map.prepare_predicate :country => 'Unites States of America'
    assert_kind_of Java::ComHazelcastQuery::SqlPredicate, predicate
    assert_equal 'country=Unites States of America', predicate.to_s
  end

  def test_class_entry_added
    map = CLIENT.map :test_class_entry_added
    Notices.clear; map.clear
    map.add_entry_listener TestEventListener.new('test_class_entry_added'), true

    assert_equal Notices.size, 0
    k, v   = 'a1', 'b2'
    map[k] = v
    sleep 1.5
    assert_equal Notices.size, 4
    assert_equal Notices.all, [
      '[test_class_entry_added] added : a1 : b2',
      '[test_class_entry_added] removed : a1 : b2',
      '[test_class_entry_added] updated : a1 : b2',
      '[test_class_entry_added] evicted : a1 : b2',
    ]
  end

  def test_class_entry_removed
    map = CLIENT.map :test_class_entry_removed
    Notices.clear; map.clear
    map.add_entry_listener TestEventListener.new('test_class_entry_removed'), true

    assert_equal Notices.size, 0
    k, v   = 'a1', 'b2'
    map[k] = v
    map.remove k
    sleep 0.25
    assert_equal Notices.size, 7
    assert_equal Notices.all, [
      '[test_class_entry_removed] added : a1 : b2',
      '[test_class_entry_removed] removed : a1 : b2',
      '[test_class_entry_removed] updated : a1 : b2',
      '[test_class_entry_removed] evicted : a1 : b2',
      '[test_class_entry_removed] removed : a1 : ',
      '[test_class_entry_removed] updated : a1 : ',
      '[test_class_entry_removed] evicted : a1 : ',
    ]
  end

  def test_class_entry_updated
    map = CLIENT.map :test_class_entry_updated
    Notices.clear; map.clear
    map.add_entry_listener TestEventListener.new('test_class_entry_updated'), true

    assert_equal Notices.size, 0
    k, v   = 'a1', 'b2'
    map[k] = 'b1'
    map[k] = v
    sleep 0.5
    assert_equal Notices.size, 6
    assert_equal Notices.all, [
      '[test_class_entry_updated] added : a1 : b1',
      '[test_class_entry_updated] removed : a1 : b1',
      '[test_class_entry_updated] updated : a1 : b1',
      '[test_class_entry_updated] evicted : a1 : b1',
      '[test_class_entry_updated] updated : a1 : b2',
      '[test_class_entry_updated] evicted : a1 : b2',
    ]
  end

  def test_class_entry_evicted
    map = CLIENT.map :test_class_entry_evicted
    Notices.clear; map.clear
    map.add_entry_listener TestEventListener.new('test_class_entry_evicted'), true

    assert_equal Notices.size, 0
    k, v   = 'a1', 'b2'
    map[k] = v
    map.evict k
    sleep 0.25
    assert_equal Notices.size, 5
    assert_equal Notices.all, [
      '[test_class_entry_evicted] added : a1 : b2',
      '[test_class_entry_evicted] removed : a1 : b2',
      '[test_class_entry_evicted] updated : a1 : b2',
      '[test_class_entry_evicted] evicted : a1 : b2',
      '[test_class_entry_evicted] evicted : a1 : ',
    ]
  end

  # ===================================================================
  # DEPRECATION NOTICE
  # -------------------------------------------------------------------
  # Deprecating this functionality in favor of actual listener classes

  def test_entry_added
    map = CLIENT.map :test_entry_added
    Notices.clear; map.clear
    map.on_entry_added do |event|
      Notices << "added : #{event.key} : #{event.value}"
    end

    assert_equal Notices.size, 0
    k, v   = 'a1', 'b2'
    map[k] = v
    sleep 1.5

    assert_equal Notices.size, 1
    assert_equal Notices.all, [
      'added : a1 : b2'
    ]
  end

  def test_entry_removed
    map = CLIENT.map :test_entry_removed
    Notices.clear; map.clear
    map.on_entry_removed do |event|
      Notices << "removed : #{event.key} : #{event.value}"
    end

    assert_equal Notices.size, 0
    k, v   = 'a1', 'b2'
    map[k] = v
    map.remove k
    sleep 0.25

    assert_equal Notices.size, 2
    assert_equal Notices.all, [
      'removed : a1 : b2',
      'removed : a1 : ',
    ]
  end

  def test_entry_updated
    map = CLIENT.map :test_entry_updated
    Notices.clear; map.clear
    map.on_entry_updated do |event|
      Notices << "updated : #{event.key} : #{event.value}"
    end

    assert_equal Notices.size, 0
    k, v   = 'a1', 'b2'
    map[k] = 'b0'
    map[k] = 'b1'
    map[k] = v
    sleep 0.5

    assert_equal Notices.size, 3
    assert_equal Notices.all, [
      'updated : a1 : b0',
      'updated : a1 : b1',
      'updated : a1 : b2',
    ]
  end

  def test_entry_evicted
    map = CLIENT.map :test_entry_evicted
    Notices.clear; map.clear
    map.on_entry_evicted do |event|
      Notices << "evicted : #{event.key} : #{event.value}"
    end

    assert_equal Notices.size, 0
    k, v   = 'a1', 'b2'
    map[k] = v
    map.evict k
    sleep 0.25

    assert_equal Notices.size, 2
    assert_equal Notices.all, [
      'evicted : a1 : b2',
      'evicted : a1 : ',
    ]
  end

end
