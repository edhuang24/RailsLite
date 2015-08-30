class CatsController < ApplicationController
  def create
    @cat = Cat.new(cat_params)
    if @cat.save
      redirect_to("/cats")
    else
      flash[:errors] = ["Invalid cat information."]
      render :new
    end
  end

  def index
    @cats = Cat.all
    render :index
  end

  def new
    @cats = Cat.new
    render :new
  end

  private

  def cat_params
    params[:cat]
  end
end
