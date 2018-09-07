require_relative 'db_connection'
require 'active_support/inflector'
require 'byebug'
require '02_searchable'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  

  def self.columns
    if @columns
      return @columns
    else
    @columns = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    @columns = @columns.first.map {|str| str.to_sym}
    end
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) do
        attributes[column]
      end

      define_method("#{column}=") do |value|
        attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name.tableize
  end

  def self.table_name
    @table_name || @table_name = self.to_s.tableize
  end

  def self.all
    result = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
    SQL
    self.parse_all(result[1..-1])
  end

  def self.parse_all(results)
    obj_arr = []
    results.each do |hash|
      obj_arr << self.new(hash)
    end
    obj_arr
  end

  def self.find(id)
    result = DBConnection.execute2(<<-SQL)
      SELECT
        *
      FROM
        #{self.table_name}
      WHERE
        id = #{id}
    SQL
    result.length == 1 ? nil : self.new(result.last)
  end

  def initialize(params = {})
    params.each do |k, v|
      raise "unknown attribute '#{k}'" unless self.class.columns.include?(k.to_sym)
      self.send("#{k}=",v)
    end
  end

  def attributes
    if @attributes
      @attributes
    else
      @attributes = {}
    end
  end

  def attribute_values
    self.class.columns.map { |col_name| self.send(col_name)  }
  end

  def insert
    col_names = ''
    self.class.columns.map{|name| name.to_s}.each_with_index do |name, i|
      if i == self.class.columns.length - 1
        col_names += name
      elsif i == 0
        next
      else
        col_names += name + ', '
      end
    end

    question_marks = ""
    self.class.columns.length - 1.times do
      question_marks += "?, "
    end
    question_marks += "?"

    values = self.attribute_values
    values = values[1..-1]

    DBConnection.execute(<<-SQL, *values)
    INSERT INTO
      #{self.class.to_s.tableize} (#{col_names})
    VALUES
      (#{question_marks})
    SQL
    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_line = self.class.columns[1..-1].map{|column| "#{column} = ?"}.join(", ")
    values = self.attribute_values
    values = values[1..-1]

    DBConnection.execute(<<-SQL, *values, self.id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_line}
      WHERE
        id = ?
    SQL

  end

  def save
    if self.id.nil?
      self.insert
    else
      self.update
    end
  end
end
