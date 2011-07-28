class WelcomeController < ApplicationController
  def index
    render :text => "Hello, test suite!"
  end
end
