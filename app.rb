require 'sinatra'
require 'sinatra/namespace'
require 'sinatra/config_file'
require 'slim'
require 'omniauth-google-oauth2'
require 'chartkick'
require 'csv'
require './models/load'
if development?
  require 'sinatra/reloader'
  require 'pry'
  require 'byebug'
end

# ######################################################################
# configure
# ######################################################################
config_file './config/config.yml.erb'
configure do
  # enable :sessions
  use Rack::Session::Pool, session_secret: settings.rack_session_secret
  use OmniAuth::Builder do
    provider :google_oauth2,
             settings.google_client_id,
             settings.google_client_secret
  end
end
configure :production do
  require 'newrelic_rpm'
end

# ######################################################################
# before filter /protected
# ######################################################################
before '/protected' do
  provider = session[:provider]
  uid      = session[:uid]
  if provider.nil? || uid.nil?
    # 認証後のリダイレクト先を格納しておく
    session[:request_path] = request.path
    redirect to('/auth/google_oauth2')
  else
    @user = User.find_by(provider: provider, uid: uid)
  end
end

# ######################################################################
# no auth area
# ######################################################################
get '/' do
  slim 'h1: a href="/protected" login with Google', layout: false
end

get '/logout' do
  session.clear
  redirect to('/')
end

# ######################################################################
# OmniAuth
# ######################################################################
namespace '/auth' do
  get '/:provider/callback' do
    auth = env['omniauth.auth']

    # ユーザーがいれば検索結果を、いなければcreateする
    # user = User.find_by(provider: auth.provider, uid: auth.uid)
    user = User.find_by(provider: auth.provider, uid: auth.uid) ||
             User.create_with_omniauth(auth)

    # セッションにログイン有無の判定に必要な値を設定
    session[:provider] = user.provider
    session[:uid]      = user.uid

    redirect to(session[:request_path])
  end

  get '/failure' do
    str = []
    str << 'h1.tet-danger auth failure'
    str << "h2 message [#{params['message']}]"
    slim str.join("\n")
  end
end

# ######################################################################
# Authentication Area
# ######################################################################
namespace '/protected' do
  get '/?' do
    slim :index
  end

  get '/regist' do
    slim :regist
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
end

# ######################################################################
# for NewRelic ping
# ######################################################################
get '/newrelic' do
  "#{Time.now} / #{BodyWeight.count}"
end
