#!/usr/env bin

require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'digest/sha1'
require 'sinatra-authentication'


use Rack::Session::Cookie, :secret => 'mah sekrit is 7 proxies oh yeah!!'

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/users.db"
)

get '/' do
  redirect '/login' unless logged_in?
  haml :home
end

get '/login' do
  haml :login
end

get '/twitter' do
  redirect '/login' unless logged_in?
  haml :twitter
end
