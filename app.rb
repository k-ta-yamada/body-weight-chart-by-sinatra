require 'sinatra'
require 'sinatra/namespace'
require 'sinatra/config_file'
require 'slim'
require 'omniauth-google-oauth2'
require 'chartkick'
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
# helpers
# ######################################################################
helpers do
  def user_login?
    session[:provider] && session[:uid]
  end

  def current_user
    User.find_by(provider: session[:provider], uid: session[:uid])
  end
end

# ######################################################################
# before filter /home
# ######################################################################
before '/home/?*' do
  if user_login?
    @user = current_user
  else
    # 認証後のリダイレクト先を格納しておく
    session[:request_path] = request.path
    redirect to('/auth/google_oauth2')
  end
end

# ######################################################################
# no auth area
# ######################################################################
get '/' do
  redirect to('/home') if user_login?
  slim :index
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
    session.clear
    str = []
    str << 'h1.text-danger auth failure'
    str << "p message [#{params['message']}]"
    str << "h2: a href='/' back to index"
    slim str.join("\n")
  end
end

# ######################################################################
# Authentication Area
# ######################################################################
namespace '/home' do
  get '/?' do
    slim :home
  end

  post '/regist' do
    if @user.body_weights.create(params)
      redirect to('/home')
    else
      # TODO: 登録失敗時の対応をどうにかする
      redirect to('/home')
    end
  end

  get '/delete/:id' do |id|
    @doc = @user.body_weights.find(id)
    redirect to('/home') if @doc.nil?

    slim :delete
  end

  post '/delete/:id' do |id|
    doc = @user.body_weights.find(id)
    doc.destroy unless doc.nil?

    redirect to('/home')
  end
end

# ######################################################################
# for NewRelic ping
# ######################################################################
get '/newrelic' do
  "#{Time.now} / #{BodyWeight.count}"
end
