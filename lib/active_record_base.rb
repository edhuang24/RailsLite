require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

require 'sqlite3'

# https://tomafro.net/2010/01/tip-relative-paths-with-file-expand-path
ROOT_FOLDER = File.join(File.dirname(__FILE__), '..')
CATS_SQL_FILE = File.join(ROOT_FOLDER, 'cats.sql')
CATS_DB_FILE = File.join(ROOT_FOLDER, 'cats.db')

class DBConnection
  def self.open(db_file_name)
    @db = SQLite3::Database.new(db_file_name)
    @db.results_as_hash = true
    @db.type_translation = true

    @db
  end

  def self.reset
    commands = [
      "rm '#{CATS_DB_FILE}'",
      "cat '#{CATS_SQL_FILE}' | sqlite3 '#{CATS_DB_FILE}'"
    ]

    commands.each { |command| `#{command}` }
    DBConnection.open(CATS_DB_FILE)
  end

  def self.instance
    reset if @db.nil?

    @db
  end

  def self.execute(*args)
    puts args[0]

    instance.execute(*args)
  end

  def self.execute2(*args)
    puts args[0]

    instance.execute2(*args)
  end

  def self.last_insert_row_id
    instance.last_insert_row_id
  end

  private

  def initialize(db_file_name)
  end
end

# class AttrAccessorObject
#   def self.my_attr_accessor(*names)
#     # ...
#     names.each do |name|
#       define_method("#{name}=") { |value|
#           instance_variable_set("@#{name}", value)
#       }
#       define_method("#{name}") {
#           instance_variable_get("@#{name}")
#       }
#   end
# end

module Searchable
  # def where(params)
  #   where_line = params.keys.map do |key|
  #       "#{key} = ?"
  #   end.join(" AND ")

  #   result = DBConnection.execute(<<-SQL, *params.values)
  #       select
  #       *
  #       from
  #       #{self.table_name}
  #       where
  #       #{where_line}
  #   SQL

  #   parse_all(result)
  # end

  def where(params)
    Relation.new(params, table_name)
  end
end

module Associatable
  # Phase IIIb
  def belongs_to(name, options = {})
    options = BelongsToOptions.new(name, options)

    assoc_options[name] = options

    define_method(name) {
      f_key = options.send("foreign_key")
      p_key = options.send("primary_key")
      m_class = options.model_class
      # you need to do send(f_key) here because the foreign_key belongs to the 'has_many' model
      m_class.where({ p_key => self.send(f_key) }).first
    }
  end

  def has_many(name, options = {})
    options = HasManyOptions.new(name, self.to_s, options)
    define_method(name) {
      f_key = options.send("foreign_key")
      # you can't use line below because it only returns the name of the primary key column
      # p_key = options.send("primary_key")
      p_key = self.id
      m_class = options.model_class
      # you need to do send(f_key) here because the foreign_key belongs to the 'has_many' model
      m_class.where({ f_key => p_key })
    }
  end

  def assoc_options
    # Wait to implement this in Phase IVa. Modify `belongs_to`, too.
    @assoc_options ||= {}
  end

  def has_one_through(name, through_name, source_name)
    through_options = self.assoc_options[through_name]

    define_method(name) do
      source_options = through_options.model_class.assoc_options[source_name]
      results = DBConnection.execute(<<-SQL, self.send(through_options.foreign_key))
        select
          #{source_options.model_class.table_name}.*
        from
          #{through_options.model_class.table_name}
        join
          #{source_options.model_class.table_name}
        on
          #{through_options.model_class.table_name}.#{source_options.foreign_key} = #{source_options.model_class.table_name}.id
        where
          #{through_options.model_class.table_name}.id = ?
      SQL
      objects = results.map do |result|
        source_options.model_class.new(result)
      end
      objects.first
    end
  end

  def has_many_through(name, through_name, source_name)
    through_options = self.assoc_options[through_name]

    define_method(name) do
      source_options = through_options.model_class.assoc_options[source_name]
      target_table = source_options.model_class.tableize
      through_table = through_options.model_class.tableize
      results = DBConnection.execute(<<-SQL, self.send(through_options.foreign_key))
        select
          #{target_table}.*
        from
          #{through_table}
        join
          #{target_table}
        on
          #{through_table}.id = #{target_table}.#{source_options.foreign_key}
        where
          #{through_table}.id = ?
      SQL
      objects = results.map do |result|
        source_options.model_class.new(result)
      end
    end
  end

  # from Jacy Anthis, fellow student
  def includes(assoc_name)
    # PRINT STATEMENTS FOR TESTING NUMBER OF QUERIES MADE BY INCLUDES
    # puts "starting first query..."
    original_objects = self.all
    # puts "first query done"

    included_options = assoc_options[assoc_name]
    included_model_class = included_options.model_class
    included_table_name = included_model_class.table_name
    included_other_key = included_options.other_key
    self_key = included_options.self_key

    # puts "starting second query..."
    second_query = DBConnection.execute(<<-SQL)
      SELECT
        *
      FROM
        #{included_table_name}
    SQL

    included_objects = second_query.map do |result|
      included_model_class.new(result)
    end
    # puts "second query done"

    original_objects.each do |original|
      original.define_singleton_method(assoc_name) do
        relevant_results = included_objects.select do |included|
          included.send(included_other_key) == original.send(self_key)
        end
      end
    end

  end
end

class SQLObject
  extend Searchable
  extend Associatable

  def self.columns
    results = DBConnection.execute2(<<-SQL)
        select
        *
        from
        #{self.table_name}
    SQL

    results.first.map { |column| column.to_sym }
  end

  def self.finalize!
    self.columns.each do |column|
        define_method("#{column.to_s}=") { |value|
            attributes[column] = value
        }
        define_method("#{column.to_s}") {
            attributes[column]
        }
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name || self.name.underscore.pluralize
  end

  def self.all
    results = DBConnection.execute(<<-SQL)
        select
        *
        from
        #{self.table_name}
    SQL
    self.parse_all(results)
  end

  def self.parse_all(results)
    results.map do |result|
        self.new(result)
    end
  end

  def self.find(id)
    result = DBConnection.execute(<<-SQL)
        select
        *
        from
        #{self.table_name}
        where #{self.table_name}.id = #{id}
    SQL
    parse_all(result).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
        if self.class.columns.include?(attr_name.to_sym)
            self.send("#{attr_name}=", value)
        else
            raise "unknown attribute '#{attr_name}'"
        end
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map do |column|
        self.send(column)
    end
  end

  def insert
    col_names = self.class.columns.join(", ")
    questions = (["?"] * self.class.columns.length).join(", ")
    DBConnection.execute(<<-SQL, *attribute_values)
        insert into
        #{self.class.table_name} (#{col_names})
        values
        (#{questions})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    col_names = self.class.columns.map { |column| "#{column} = ?" }.join(", ")
    DBConnection.execute(<<-SQL, *attribute_values, self.id)
        update
        #{self.class.table_name}
        set
        #{col_names}
        where
        #{self.class.table_name}.id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end

class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    class_name.to_s.constantize
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    @foreign_key = options[:foreign_key] || "#{name}_id".to_sym
    @primary_key = options[:primary_key] || :id
    @class_name = options[:class_name] || name.to_s.camelcase
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    @foreign_key = options[:foreign_key] || "#{self_class_name.underscore}_id".to_sym
    @primary_key = options[:primary_key] || :id
    @class_name = options[:class_name] || name.to_s.singularize.camelcase
  end
end

# from Haseeb Qureshi, a/A TA
class Relation
  attr_reader :table_name
  include Enumerable

  def initialize(params, table_name)
    @params = params
    @table_name = table_name
  end

  def where(params)
    Relation.new(@params.merge(params), @table_name)
  end

  def load
    lookup = @params.keys.map { |key| "#{key} = ?" }.join(" AND ")
    query = DBConnection.execute(<<-SQL, *@params.values)
      SELECT
        *
      FROM
        #{@table_name}
      WHERE
        #{lookup}
    SQL
    query.map { |attrs| Object.const_get(@table_name.camelcase.singularize).new(attrs) }
  end

  def cache
    @cache ||= load
  end

  def ==(other_obj)
    cache == other_obj
  end

  def method_missing(m, *args, &blk)
    return cache.send(m, *args, &blk) if cache.respond_to?(m)
    raise NoMethodError
  end
end


