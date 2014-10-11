require 'sinatra'
require 'sinatra/flash'
require 'slim'
require 'chartkick'
require 'csv'
require 'mongoid'
# Mongoid.load!('./config/mongoid.yml', :development)
Mongoid.load!('./config/mongoid.yml')
require './models/body_weight'
if development?
  require 'sinatra/reloader'
  require 'pry'
  require 'byebug'
end

configure :production do
  require 'newrelic_rpm'
  # for sinatra/flash
  enable :sessions
end

helpers do
  # sinatra-flash and bootstrap alert
  # @ref https://gist.github.com/mamantoha/3358074
  module Sinatra
    module Flash
      module Style
        def styled_flash(key = :flash)
          return '' if flash(key).empty?
          id = (key == :flash ? 'flash' : "flash_#{key}")
          close = ['<button type="button" class="close" data-dismiss="alert">',
                   '<span aria-hidden="true">&times;</span>',
                   '<span class="sr-only">Close</span></button>'].join
          mes = flash(key).map do |message|
            ["<div class='alert alert-#{message[0]} alert-dismissible'>",
             "#{close}\n #{message[1]}</div>\n"].join
          end
          "<div id='#{id}'>\n" + mes.join + '</div>'
        end
      end
    end
  end
end

get '/' do
  slim :index
end

get '/regist' do
  slim :_form
end

PASS_KEY = ENV['PASS_KEY'] || 'dev'
post '/regist' do
  redirect to('/') unless params[:pass] == PASS_KEY

  if BodyWeight.create(params)
    redirect to('/')
  else
    redirect to('/')
  end
end

get '/csv_load' do
  BodyWeight.delete_all(pass: 'csv')
  csv = CSV.table('./models/body_weight.csv')
  csv.each do |row|
    b = BodyWeight.new
    b.date   = row[:date]
    b.time   = row[:time]
    b.weight = row[:weight]
    b.pass   = row[:pass]
    b.save
  end
  redirect to('/')
end

get '/delete/*' do |id|
  @doc = BodyWeight.find(id)
  # @doc.destroy
  slim :delete
end

post '/delete' do
  redirect to("/delete/#{params[:id]}") unless params[:pass] == PASS_KEY
  id = params[:id]
  doc = BodyWeight.find(id)
  doc.destroy

  redirect to('/')
end

# get '/delete_all/?*' do |pass|
#   unless pass.empty?
#     @cnt = BodyWeight.delete_all(pass: pass)
#     flash.now[:warning] = "pass = #{pass} is delete. #{@cnt} documents."
#   end
#   slim :delete_all
# end

__END__
@@delete
.container
  h3 deleted this doc
  table.table.table-hover
    tr
      th id
      td = @doc.id
    tr
      th date
      td = @doc.date
    tr
      th time
      td = @doc.time
    tr
      th weight
      td = @doc.weight
    /tr
      th pass
      td = @doc.pass
  h3 Did you make sure that you want to delete the document?
  form method='post' action='/delete'
    input [type='hidden'
           name='id'
           value=@doc.id]
    input [type='text'
           name='pass'
           required=''
           placeholder='key word']
    | &nbsp;&nbsp;
    button.btn.btn-danger type='submit' was confirmed.

@@delete_all
.col-sm-8
  table.table.table-hover
    tr
      th pass
      th cnt
      th
    - BodyWeight.distinct(:pass).sort.each do |k|
      tr
        td = k
        td = BodyWeight.where(pass: k).count
        td: a.btn.btn-block.btn-danger href='/delete_all/#{k}' delete
  == styled_flash
