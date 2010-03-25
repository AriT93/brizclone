#!/usr/env ruby

require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'digest/sha1'
require 'twitter'
require 'sinatra-authentication'
require 'haml'
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

configure do
  @@config = YAML.load_file("config.yml") rescue nil || { }
  @@oauth ||= Twitter::OAuth.new(@@config['consumer_key'],@@config['consumer_secret'],:sign_in => true)
  @@profile = nil
end




helpers do
  def partial(name, options={})
    haml("_#{name.to_s}".to_sym, options.merge(:layout => false))
  end
end

get '/' do
  redirect '/login' unless logged_in?

  if session['atoken'] != ''
    @@oauth.set_callback_url(@@config['callback_url'])
    session['rtoken'] = @@oauth.request_token.token
    session['rsecret'] = @@oauth.request_token.secret
    user = BcUser.first(:email => current_user.email)
    if user != nil
      @@oauth.authorize_from_access(user.atoken,user.asecret)
      @@profile = Twitter::Base.new(@@oauth)
    else
      redirect @@oauth.request_token.authorize_url
    end
  end
  haml :home
end


get '/auth' do
  @@oauth.authorize_from_request(session['rtoken'],session['rsecret'],params[:oauth_verifier])
  @@profile = Twitter::Base.new(@@oauth)
  @@profile.verify_credentials
  session['atoken'] = @@oauth.access_token.token
  session['asecret'] = @@oauth.access_token.secret
  user = BcUser.first(:email => current_user.email)
  if user == nil
    user = BcUser.new()
    user.email = current_user.email
    if user.atoken == nil
    user.atoken = @@oauth.access_token.token
    user.asecret = @@oauth.access_token.secret
    end
    user.save
  end
  redirect '/'
end

get '/login' do
  haml :login
end

get '/twitter' do
  if @@profile == nil
    redirect '/'
  end
  @tweets = @@profile.friends_timeline
  haml :twitter
end

post '/twitter' do
  tweet = @@profile.update(params[:text])
  flash[:notice] = "tweet ##{tweet.id} created"
  redirect '/twitter'
end
