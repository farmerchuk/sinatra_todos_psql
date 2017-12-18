# database_persistence.rb

require "pg"

class DatabasePersistence
  attr_reader :db, :logger

  def initialize(logger)
    @db = if Sinatra::Base.production?
            PG.connect(ENV['DATABASE_URL'])
          else
            PG.connect(dbname: "todos")
          end
    @logger = logger
  end

  def disconnect
    @db.close
  end

  def load_list(list_id)
    sql = <<~SQL
      SELECT
        lists.*,
        COUNT(todos.id) AS todos_count,
        COUNT(NULLIF(todos.completed, false)) AS todos_completed_count
      FROM lists
      LEFT OUTER JOIN todos ON lists.id = todos.list_id
      WHERE lists.id = $1
      GROUP BY lists.id
      ORDER BY lists.name;
    SQL

    result = query(sql, list_id).first
    convert_tuple_to_hash(result)
  end

  def all_lists
    sql = <<~SQL
      SELECT
        lists.*,
        COUNT(todos.id) AS todos_count,
        COUNT(NULLIF(todos.completed, false)) AS todos_completed_count
      FROM lists
      LEFT OUTER JOIN todos ON lists.id = todos.list_id
      GROUP BY lists.id
      ORDER BY lists.name;
    SQL

    result = query(sql)
    result.map do |tuple|
      convert_tuple_to_hash(tuple)
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(list_id)
    todos_sql = "DELETE FROM todos WHERE list_id = $1"
    query(todos_sql, list_id)

    list_sql = "DELETE FROM lists WHERE id = $1"
    query(list_sql, list_id)
  end

  def update_list_name(list_id, new_list_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_list_name, list_id)
  end

  def load_todos_by(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    result = query(sql, list_id)

    result.map do |tuple|
      { id: tuple['id'].to_i,
        name: tuple['name'],
        completed: tuple['completed'] == 't' }
    end
  end

  def create_new_todo(list_id, todo_name)
    sql = "INSERT INTO todos (name, list_id) VALUES ($1, $2)"
    query(sql, todo_name, list_id)
  end

  def delete_todo(list_id, todo_id)
    sql = "DELETE FROM todos WHERE list_id = $1 and id = $2"
    query(sql, list_id, todo_id)
  end

  def mark_all_todos_done(list_id)
    sql = "UPDATE todos SET completed = true WHERE list_id = $1"
    query(sql, list_id)
  end

  def update_todo_status(list_id, todo_id, new_status)
    sql = "UPDATE todos SET completed = $1 WHERE list_id = $2 AND id = $3"
    query(sql, new_status, list_id, todo_id)
  end

  private

  def query(statement, *params)
    logger.info "#{statement}: #{params}"
    db.exec_params(statement, params)
  end

  def convert_tuple_to_hash(tuple)
    { id: tuple['id'].to_i,
      name: tuple['name'],
      todos_count: tuple['todos_count'].to_i,
      todos_completed_count: tuple['todos_completed_count'].to_i }
  end
end
