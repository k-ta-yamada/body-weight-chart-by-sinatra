require 'sinatra'
require 'sinatra/namespace'
require 'sinatra/config_file'
require 'omniauth-google-oauth2'
require 'slim'
require 'chartkick'
require 'will_paginate_mongoid'
require 'will_paginate/view_helpers/sinatra'
require 'will_paginate-bootstrap'
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
  # use Rack::MethodOverride
  # set :method_override, true
  enable :method_override
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
helpers WillPaginate::Sinatra
helpers do
  def user_login?
    session[:provider] && session[:uid]
  end

  def current_user
    User.find_by(provider: session[:provider], uid: session[:uid])
  end

  def form_action
    @action ||= '/home/body_weights'
  end

  def current_date
    @date ||= Time.now.strftime('%Y-%m-%d')
  end

  def current_time
    @time ||= Time.now.strftime('%H:%M')
  end

  def recent_weight
    bw = @user.body_weights
    @bw ||= bw.empty? ? nil : bw.desc(:date, :time).first.weight
  end

  def body_weights_paginate
    per_page = (request.path == '/home') ? 5 : nil
    page     = params[:page]
    @user.body_weights.desc(:date, :time).paginate(per_page: per_page,
                                                   page:     page)
  end
end

# ######################################################################
# filters
# ######################################################################
before do
  puts request.cookies
  if !request.ssl? && Sinatra::Base.environment == :production
    redirect to("https://#{request.host}#{request.path}")
  end
end

# ######################################################################
# no auth area
# ######################################################################
namespace '/' do
  get '' do
    redirect to('/home') if user_login?
    slim :index
  end

  get 'logout' do
    session.clear
    redirect to('/')
  end
end

# ######################################################################
# OmniAuth
# ######################################################################
namespace '/auth' do
  get '/:provider/callback' do
    auth = env['omniauth.auth']
    # ユーザーがいれば検索結果を、いなければcreateする
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
  before '/?*' do
    if user_login?
      @user = current_user
    else
      # 認証後のリダイレクト先を格納しておく
      session[:request_path] = request.path
      redirect to('/auth/google_oauth2')
    end
  end

  get '/?' do
    slim :home
  end

  namespace '/body_weights' do
    # body_weights#index
    get '/?' do
      slim :_data_list
    end

    # body_weights#new
    get '/new' do
      slim :_form
    end

    # body_weights#create
    post '/?' do
      if @user.body_weights.create(date:   params[:date],
                                   time:   params[:time],
                                   weight: params[:weight])
      else
        # TODO: 登録失敗時の対応をどうにかする
      end
      redirect to('/home')
    end

    # body_weights#show
    get '/:id' do |id|
      @doc = @user.body_weights.find(id)
      redirect to('/home') if @doc.nil?
      slim :show
    end

    # body_weights#edit
    get '/:id/edit' do |id|
      bw = @user.body_weights.find(id)
      @date   = bw.date.strftime('%Y-%m-%d')
      @time   = bw.time.strftime('%H:%M')
      @bw     = bw.weight
      @action = "/home/body_weights/#{id}"
      @method = 'PUT'
      slim :edit
    end

    # body_weights#update
    put '/:id' do |id|
      @doc = @user.body_weights.find(id)
      redirect to("/home/body_weights/#{id}") if @doc.nil?
      if @doc.update(date:   params[:date],
                     time:   params[:time],
                     weight: params[:weight])
        redirect to('/home')
      else
        # TODO: 更新失敗時の対応をなんとかする
      end
    end

    # body_weights#destroy
    delete '/:id/delete' do |id|
      doc = @user.body_weights.find(id)
      doc.destroy unless doc.nil?
      redirect to('/home')
    end
  end # namespace '/body_weights' do
end # namespace '/home' do

# ######################################################################
# for NewRelic ping
# ######################################################################
get '/newrelic' do
  "#{Time.now} / #{BodyWeight.count}"
end
