require "pre_warming_query/version"

module PreWarmingQuery
  class Generator
    attr_writer :definitions

    def initialize(client, database_name)
      @client = client
      @database_name = database_name
    end

    def queries
      raise 'ERROR: invalid definitions' unless definitions
      order = %w( column_type table_name column_name )
      definitions.map do |d|
        case d['column_key']
        when 'PRI'
          pk_warming_query(*d.fetch_values(*order))
        when 'MUL', 'UNI'
          key_warming_query(*d.fetch_values(*order))
        else
          raise "ERROR: unknown column_key [#{d['column_key']}]"
        end
      end
    end
    
    def definitions
      dbname = @client.escape(@database_name)
      q =<<-SQL
      select
        t.table_name,
        c.column_name,
        c.column_key,
        c.column_type
      from
        information_schema.tables t
        join
        information_schema.columns c
          on (t.table_name = c.table_name)
      where
        t.table_schema = '#{dbname}' and c.column_key <> ''
      order by
        c.column_key, c.column_name
      SQL
      @definitions ||= ->() {
        # In order to use query options (Client#query), use escape not prepared-statement
        result = @client.query(q, as: :hash, symbolize_keys: false)
        result.count > 0 ? result : []
      }.call
    end

    private
    def pk_warming_query(type, table, column)
      case type.downcase
      when /int/, /decimal/
        "select sum(#{column}) from #{table};"
      when /char/, /text/
        "select sum(length(#{column})) from #{table};"
      when /date/, /time/
        "select sum(unix_timestamp(#{column})) from #{table};"
      else
        raise "ERROR: unknown column_type [#{type.downcase}]"
      end
    end

    def key_warming_query(type, table, column)
      case type.downcase
      when /int/, /decimal/
        "select sum(ifnull(#{column},0)) from (select #{column} from #{table} order by #{column}) t1;"
      when /char/, /text/
        "select sum(length(ifnull(#{column},0))) from (select #{column} from #{table} order by #{column}) t1;"
      when /date/, /time/
        "select sum(unix_timestamp(ifnull(#{column},0))) from (select #{column} from #{table} order by #{column}) t1;"
      else
        raise "ERROR: unknown column_type [#{type.downcase}]"
      end
    end
  end
end
