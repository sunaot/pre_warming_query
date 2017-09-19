require "test_helper"

class Client
  def query(q, opts = {}); end
  def escape(str); end
end

class PreWarmingQueryTest < Minitest::Test
  def test_primary_key_queries
    g = PreWarmingQuery::Generator.new(Client.new, 'your_database')
    g.definitions = definitions_of('PRI')
    assert_equal [
      'select sum(c1) from t1;', # INT
      'select sum(c1) from t1;', # DECIMAL
      'select sum(length(c1)) from t1;', # CHAR
      'select sum(length(c1)) from t1;', # TEXT
      'select sum(unix_timestamp(c1)) from t1;', # DATE
      'select sum(unix_timestamp(c1)) from t1;'  # TIME
    ], g.queries
  end

  def test_multi_key_queries
    g = PreWarmingQuery::Generator.new(Client.new, 'your_database')
    g.definitions = definitions_of('MUL')
    assert_equal [
      'select sum(ifnull(c1,0)) from (select c1 from t1 order by c1) t1;', # INT
      'select sum(ifnull(c1,0)) from (select c1 from t1 order by c1) t1;', # DECIMAL
      'select sum(length(ifnull(c1,0))) from (select c1 from t1 order by c1) t1;', # CHAR
      'select sum(length(ifnull(c1,0))) from (select c1 from t1 order by c1) t1;', # TEXT
      'select sum(unix_timestamp(ifnull(c1,0))) from (select c1 from t1 order by c1) t1;', # DATE
      'select sum(unix_timestamp(ifnull(c1,0))) from (select c1 from t1 order by c1) t1;', # TIME
    ], g.queries
  end

  def test_unique_key_queries
    g = PreWarmingQuery::Generator.new(Client.new, 'your_database')
    g.definitions = [
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => 'UNI', 'column_type' => 'INT' },
    ]
    assert_equal [
      'select sum(ifnull(c1,0)) from (select c1 from t1 order by c1) t1;', # INT
    ], g.queries
  end

  def test_unknown_column_type_error
    g = PreWarmingQuery::Generator.new(Client.new, 'your_database')
    g.definitions = [
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => 'PRI', 'column_type' => 'UNKNOWN' }
    ]
    assert_raises(RuntimeError) { g.queries }
  end

  def test_unknown_column_key_error
    g = PreWarmingQuery::Generator.new(Client.new, 'your_database')
    g.definitions = [
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => 'UNKNOWN', 'column_type' => 'INT' }
    ]
    assert_raises(RuntimeError) { g.queries }
  end

  def test_nil_definition
    c = Client.new
    def c.query(q, opts = {}); [] end
    g = PreWarmingQuery::Generator.new(c, 'your_database')
    g.definitions = nil
    assert_equal [], g.queries
  end

  def test_empty_definition
    g = PreWarmingQuery::Generator.new(Client.new, 'your_database')
    g.definitions = []
    assert_equal [], g.queries
  end

  private
  def definitions_of(column_key)
    [
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => column_key, 'column_type' => 'INT' },
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => column_key, 'column_type' => 'DECIMAL' },
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => column_key, 'column_type' => 'CHAR' },
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => column_key, 'column_type' => 'TEXT' },
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => column_key, 'column_type' => 'DATE' },
      { 'table_name' => 't1', 'column_name' => 'c1', 'column_key' => column_key, 'column_type' => 'TIME' }
    ]
  end
end
