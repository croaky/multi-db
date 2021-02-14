class ThingsController < ApplicationController
  def index
    ApplicationRecord.read_only do
      @things = Thing.order(created_at: :desc)
    end
  end

  def new
    @thing = Thing.new
  end

  def create
    @thing = Thing.new(params.require(:thing).permit(:name))

    if @thing.save
      redirect_to "/"
    else
      render :new
    end
  end
end
