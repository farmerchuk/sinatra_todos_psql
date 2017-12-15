# session_persistence.rb

class SessionPersistence
  attr_reader :session

  def initialize(session)
    @session = session
    @session[:lists] ||= []
  end

  def load_list(list_id)
    session[:lists].find { |list| list[:id] == list_id }
  end

  def all_lists
    session[:lists]
  end

  def create_new_list(list_name)
    id = next_id(all_lists)
    session[:lists] << { id: id, name: list_name, todos: [] }
  end

  def delete_list(list_id)
    session[:lists].reject! { |list| list[:id] == id }
  end

  def edit_list_name(list_id, new_list_name)
    list = load_list(list_id)
    list[:name] = new_list_name
  end

  def create_new_todo(list_id, todo_name)
    todo_id = next_id(@todos)
    list = load_list(list_id)
    list[:todos] << { id: todo_id, name: todo_name, completed: false }
  end

  def delete_todo(list_id, todo_id)
    list = load_list(list_id)
    list[:todos].reject! { |todo| todo[:id] == todo_id }
  end

  def mark_all_todos_done(list_id)
    todos = find_todos_by(list_id)
    todos.each { |todo| todo[:completed] = true }
  end

  def update_todo_status(list_id, todo_id, new_status)
    todos = find_todos_by(list_id)
    todo = find_todo(todo_id, todos)
    todo[:completed] = new_status
  end

  private

  def find_todos_by(list_id)
    list = load_list(list_id)
    list[:todos]
  end

  def find_todo(todo_id, todos)
    todos.find { |todo| todo[:id] == todo_id }
  end

  def next_id(array)
    max = array.map { |item| item[:id] }.max || 0
    max + 1
  end
end
