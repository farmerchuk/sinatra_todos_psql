require "sinatra"
require "sinatra/content_for"
require "tilt/erubis"

require_relative "lib/database_persistence"

configure do
  set :erb, :escape_html => true
  enable :sessions
  set :session_secret, "secret"
end

configure(:development) do
  require "sinatra/reloader"
  also_reload "database_persistence.rb"
end

after do
  @storage.disconnect
end

helpers do
  def completed_todos(list)
    "#{list[:todos_completed_count]} / #{list[:todos_count]}"
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def list_complete?(list)
    list[:todos_count] > 0 &&
      list[:todos_completed_count] == list[:todos_count]
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

def error_for_list_name(list_name)
  if @storage.all_lists.any? { |list| list[:name] == list_name }
    "List name must be unique."
  elsif !(1..100).cover?(list_name.size)
    "List name must be between 1 and 100 characters long."
  end
end

def error_for_todo_name(todo_name, list_id)
  todos = @storage.load_todos_by(list_id)
  if todos.any? { |todo| todo[:name] == todo_name }
    "Todo name must be unique."
  elsif !(1..100).cover?(todo_name.size)
    "Todo name must be between 1 and 100 characters long."
  end
end

before do
  @storage = DatabasePersistence.new(logger)
end

get "/" do
  redirect "/lists"
end

# displays a list of todo lists
get "/lists" do
  @lists = @storage.all_lists
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
    @storage.create_new_list(list_name)
    session[:success] = "New Todo list successfully added!"
    redirect "/lists"
  end
end

# displays a single todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = @storage.load_list(@list_id)

  unless @list.empty?
    @todos = @storage.load_todos_by(@list_id)
    erb :list, layout: :layout
  else
    session[:error] = "List not found."
    redirect "/lists"
  end
end

# edit an existing todo list
get "/lists/:id/edit" do
  @list_id = params[:id].to_i
  @list = @storage.load_list(@list_id)

  unless @list.empty?
    erb :edit_list, layout: :layout
  else
    session[:error] = "List not found."
    redirect "/lists"
  end
end

# updates an existing todo list
post "/lists/:id" do
  @list_id = params[:id].to_i
  new_list_name = params[:list_name]

  error = error_for_list_name(new_list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, new_list_name)
    session[:success] = "Todo list successfully updated!"
    redirect "/lists/#{@list_id}"
  end
end

# deletes an existing todo list
post "/lists/:id/delete" do
  id = params[:id].to_i
  @storage.delete_list(id)

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
  todo_name = params[:todo].strip

  error = error_for_todo_name(todo_name, @list_id)
  if error
    @list = @storage.load_list(@list_id)
    @todos = @storage.load_todos_by(@list_id)
    session[:error] = error
    erb :list, layout: :layout
  else
    @storage.create_new_todo(@list_id, todo_name)
    session[:success] = "Todo item successfully added!"
    redirect "lists/#{@list_id}"
  end
end

# deletes a todo item from a todo list
post "/lists/:list_id/todos/:todo_id/delete" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  @storage.delete_todo(list_id, todo_id)

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
  @storage.mark_all_todos_done(list_id)
  redirect "/lists/#{list_id}"
end

# updates a todo's status
post "/lists/:list_id/todos/:todo_id" do
  list_id = params[:list_id].to_i
  todo_id = params[:todo_id].to_i
  new_status = (params[:completed] == 'true' ? true : false)
  @storage.update_todo_status(list_id, todo_id, new_status)
  redirect "/lists/#{list_id}"
end
