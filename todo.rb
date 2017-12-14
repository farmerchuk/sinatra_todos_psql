require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, "secret"
end

helpers do
  def completed_todos(list)
    todos = list[:todos]
    completed_todos = todos.count { |todo| todo[:completed] }
    "#{completed_todos} / #{todos.size}"
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def list_complete?(list)
    todos = list[:todos]
    todos.all? { |todo| todo[:completed] } && todos.size > 0
  end

  def sort_lists(lists, &block)
    completed_lists, incomplete_lists = lists.partition do |list|
      list_complete?(list)
    end

    incomplete_lists.each { |list| yield(list, lists.index(list)) }
    completed_lists.each { |list| yield(list, lists.index(list)) }
  end

  def sort_todos(todos, &block)
    completed_todos, incomplete_todos = todos.partition do |todo|
      todo[:completed]
    end

    incomplete_todos.each { |todo| yield(todo, todos.index(todo)) }
    completed_todos.each { |todo| yield(todo, todos.index(todo)) }
  end
end

before do
  session[:lists] ||= []
end

def error_for_list_name(list_name)
  if session[:lists].any? { |list| list[:name] == list_name }
    "List name must be unique."
  elsif !(1..100).cover?(list_name.size)
    "List name must be between 1 and 100 characters long."
  end
end

def error_for_todo_name(todo_name, list_id)
  list = load_list(list_id)
  if list[:todos].any? { |todo| todo[:name] == todo_name }
    "Todo name must be unique."
  elsif !(1..100).cover?(todo_name.size)
    "Todo name must be between 1 and 100 characters long."
  end
end

def load_list(list_id)
  list = session[:lists].find { |list| list[:id] == list_id }
  return list if list

  session[:error] = "List not found."
  redirect "/lists"
end

def next_id(array)
  max = array.map { |item| item[:id] }.max || 0
  max + 1
end

get "/" do
  redirect "/lists"
end

# displays a list of todo lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# form for creating new todo list
get "/lists/new" do
  erb :new_list, layout: :layout
end

# creates new todo list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = "New Todo list successfully added!"
    redirect "/lists"
  end
end

# displays a single todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  @todos = @list[:todos]
  erb :list, layout: :layout
end

# edit an existing todo list
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# updates an existing todo list
post "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  new_list_name = params[:list_name]

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = new_list_name
    session[:success] = "Todo list successfully updated!"
    redirect "/lists/#{@list_id}"
  end
end

# deletes an existing todo list
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "Todo list successfully deleted!"
    redirect "/lists"
  end
end

# adds a new todo item to a todo list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  todo_name = params[:todo].strip

  error = error_for_todo_name(todo_name, @list_id)
  if error
    @todos = @list[:todos]
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_id(@list[:todos])
    @list[:todos] << { id: id, name: todo_name, completed: false }
    session[:success] = "Todo item successfully added!"
    redirect "lists/#{@list_id}"
  end
end

# deletes a todo item from a todo list
post "/lists/:list_id/todos/:todo_id/delete" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  @list = load_list(list_id)
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "Todo item successfully deleted!"
    redirect "/lists/#{list_id}"
  end
end

# marks all todo items in a list as done
post "/lists/:id/complete_all" do
  list_id = params[:id].to_i
  list = load_list(list_id)
  todos = list[:todos]
  todos.each { |todo| todo[:completed] = true }
  redirect "/lists/#{list_id}"
end

# marks a todo item as done
post "/lists/:list_id/todos/:todo_id" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  list = load_list(list_id)
  todos = list[:todos]
  todo = todos.find { |todo| todo[:id] == todo_id }
  todo[:completed] = (params[:completed] == 'true' ? true : false)
  redirect "/lists/#{list_id}"
end
