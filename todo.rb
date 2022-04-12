require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sinatra/content_for"
require "yaml"

configure do
  enable :sessions
  set :session_secret, "secret"
  set :erb, :escape_html => true
end

helpers do
  # return true if all todos in a list are completed
  def list_completed?(list)
    count_todos(list) > 0 && uncompleted_todos_count(list) == 0
  end

  # todos count
  def count_todos(list)
    list[:todos].size
  end

  # returns the number of uncompleted todo items in a list
  def uncompleted_todos_count(list)
    list[:todos].select { |todo| todo[:completed] == false }.size
  end

  # adds a class string based on condition
  def list_class(list)
    "complete" if list_completed?(list)
  end

  # sorts list
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_completed?(list) }
    
    incomplete_lists.each &block
    complete_lists.each &block
    end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each &block
    complete_todos.each &block
    end
  
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists
end

# Render the new list
get "/lists/new" do
  erb :new_list
end

# Returns an error message if name is invalid
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "The list name must be unique."
  end
end

# Returns an error message if todo is invalid
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
  end
end

# return the desired list if it exists otherwise throws an error
def load_list(id)
  list = session[:lists].find { |list| list[:id] == id }
  unless list
    session[:error] = "The specified list was not found."
    redirect "/"
  else
    list
  end
end

# creates unique identifiers for a list
def next_element_id(list)
  max = list.map { |item| item[:id] }.max || 0
  max + 1
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  id = next_element_id(session[:lists])
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# view a todo list
get "/list/:id" do
  @list_id = params[:id].to_i
  @list_data = load_list(@list_id)
  erb :list
end

# Edit and existing todo list
get "/list/:id/edit" do
  @list_id = params[:id].to_i
  @list_data = load_list(@list_id)
  erb :edit_list
end

# update an existing todo list
post "/list/:id" do
  list_name = params[:list_name].strip
  @list_id = params[:id].to_i
  @list_data = load_list(@list_id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list_data[:name] = list_name
    session[:success] = "The name has been updated."
    redirect "/list/#{@list_id}"
  end
end

# delete a todo list
post "/list/:id/delete" do
  id = params[:id].to_i
  deleted_name = session[:lists].find { |list| list[:id] == id }[:name]
  session[:lists].reject! { |list| list[:id] == id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "List '#{deleted_name}' has been successfully deleted."
    redirect "/lists"
  end
end

# add a todo to the todo list
post "/list/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list_data = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list
  else
    id = next_element_id(@list_data[:todos])
    @list_data[:todos] << { id: id, name: text, completed: false}
    session[:success] = "New todo has been added."
    redirect "/list/#{@list_id}"
  end
end

# delete a todo from list
post "/list/:list_id/delete_todo/:name" do
  @list_id = params[:list_id].to_i
  @todo_name = params[:name]

  load_list(@list_id)[:todos].delete_if { |todo_hsh| todo_hsh[:name] == @todo_name }
    if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
      status 204
    else
      session[:success] = "List item deleted."
      redirect "/list/#{@list_id}"
    end
end

# update the status of a todo
post "/list/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos].find { |todo| todo[:id] == todo_id}[:completed] = is_completed
  @list[:completed] = list_completed?(@list)
  session[:success] = "Todo has been updated."
  redirect "/list/#{@list_id}"
end

#update and complete all todos
post "/list/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  @list[:completed] = list_completed?(@list)
  session[:success] = "Todos have been updated."
  redirect "/list/#{@list_id}"
end

not_found do
  session[:error] = "The specified list was not found."
  redirect "/"
end