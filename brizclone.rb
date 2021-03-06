#!/usr/env ruby

require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'digest/sha1'
require 'twitter'
require 'sinatra-authentication'
require 'haml'
require 'dm-migrations'
require 'rack-flash'

use Rack::Session::Cookie, :secret => 'mah sekrit is 7 proxies oh yeah!!'
use Rack::Flash, :sweep => true


  DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/users.db"
)


class BcUser
  include DataMapper::Resource

  property :id, Serial
  property :email, String
  property :atoken, String
  property :asecret, String
end

DataMapper.auto_upgrade!

configure do
  @@config = YAML.load_file("config.yml") rescue nil || { }
end

helpers do
  def partial(name, options={})
    haml("_#{name.to_s}".to_sym, options.merge(:layout => false))
  end
  def link_to(text,url)
    "<a href=#{url}>#text</a>"
  end
  def linkup_mentions(text)
    text.gsub!(/@([\w]+)(\W)?/, '@<a href="http://twitter.com/\1">\1</a>\2')
    text
  end

  def pretty_datetime(datetime)
    date = datetime.strftime('%b %e, %Y').downcase
    time = datetime.strftime('%l:%M%p').downcase
    "<span class='date'>" + date + "</span>  <span class='time'>" + time + "</span>"
  end
 def auto_link(str)
   str.gsub(/((https?|ftp|irc):[\S]+)/xi, %Q{<a href="\\1">\\1</a>})
 end
end

before do
  @oauth ||= Twitter::OAuth.new(@@config['consumer_key'],@@config['consumer_secret'],:sign_in => true)
  @user = nil
  next unless logged_in?
  @user = BcUser.first(:email => current_user.email)
  if @user != nil
    @oauth.authorize_from_access(@user.atoken,@user.asecret)
    @profile = Twitter::Base.new(@oauth)
  else
    @profile = nil
  end
end

get '/' do
  redirect '/login' unless logged_in?
  if @user
    @oauth.authorize_from_access(@user.atoken,@user.asecret)
    @profile = Twitter::Base.new(@oauth)
  else
    @oauth.set_callback_url(@@config['callback_url'])
    session['rtoken'] = @oauth.request_token.token
    session['rsecret'] = @oauth.request_token.secret
    redirect @oauth.request_token.authorize_url
  end
  haml :home
end

get '/auth' do
  @oauth.authorize_from_request(session['rtoken'],session['rsecret'],params[:oauth_verifier])
  @profile =  Twitter::Base.new(@oauth)
  @profile.verify_credentials
  session['atoken'] = @oauth.access_token.token
  session['asecret'] = @oauth.access_token.secret
  if @user == nil
    @user = BcUser.new()
    @user.email = current_user.email
    if @user.atoken == nil
    @user.atoken = @oauth.access_token.token
    @user.asecret = @oauth.access_token.secret
    end
    @user.save
  end
  redirect '/'
end

get '/arit93itter.css' do
  sass :arit93itter
end
get '/login' do
  haml :login
end

get '/twitter' do
  params[:page] ||= 1
  redirect '/' unless @profile
  @tweets = @profile.home_timeline(:page => params[:page])
  haml :twitter
end

get '/twitter/replies' do
  params[:page] ||= 1
  redirect '/' unless @profile
  @tweets = @profile.mentions(:page => params[:page])
  haml :twitter
end

post '/twitter' do
 options = {}
 options.update(:in_reply_to_status_id => params[:in_reply_to_status_id]) unless params[:in_reply_to_status_id].empty?
 tweet = @profile.update(params[:text], options)
 flash[:notice] = "tweet ##{tweet.id} created #{params[:in_reply_to_status_id]}"
 redirect '/twitter'
end
