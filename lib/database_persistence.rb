# database_persistence.rb

require 'pg'

class DatabasePersistence
  attr_reader :db, :logger

  def initialize(logger)
    @db = PG.connect(dbname: 'todos')
    @logger = logger
  end

  def query(statement, *params)
    logger.info "#{statement}: #{params}"
    db.exec_params(statement, params)
  end

  def load_list(list_id)
    sql = "SELECT * FROM lists WHERE id = $1"
    result = query(sql, list_id)
    tuple = result.first

    if tuple
      todos = load_todos_by(list_id)
      { id: tuple['id'].to_i, name: tuple['name'], todos: todos }
    else
      {}
    end
  end

  def all_lists
    sql = "SELECT * FROM lists"
    result = query(sql)

    result.map do |tuple|
      list_id = tuple['id'].to_i
      todos = load_todos_by(list_id)

      {id: list_id, name: tuple['name'], todos: todos}
    end
  end

  def create_new_list(list_name)
    sql = "INSERT INTO lists (name) VALUES ($1)"
    query(sql, list_name)
  end

  def delete_list(list_id)
    list_sql = "DELETE FROM lists WHERE id = $1"
    query(list_sql, list_id)

    todos_sql = "DELETE FROM todos WHERE list_id = $1"
    query(todos_sql, list_id)
  end

  def update_list_name(list_id, new_list_name)
    sql = "UPDATE lists SET name = $1 WHERE id = $2"
    query(sql, new_list_name, list_id)
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

  def load_todos_by(list_id)
    sql = "SELECT * FROM todos WHERE list_id = $1"
    result = query(sql, list_id)

    result.map do |tuple|
      { id: tuple['id'].to_i,
        name: tuple['name'],
        completed: tuple['completed'] == 't' }
    end
  end
end
