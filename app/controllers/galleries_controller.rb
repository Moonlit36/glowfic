class GalleriesController < ApplicationController
  before_filter :login_required
  before_filter :find_gallery, :only => [:add, :icon, :destroy, :remove, :show]

  def index
    use_javascript('galleries/index')
  end

  def new
    @gallery = Gallery.new
  end

  def create
    @gallery = Gallery.new(params[:gallery])
    @gallery.user = current_user
    if @gallery.save
      flash[:success] = "Gallery saved successfully."
      redirect_to galleries_path
    else
      flash.now[:error] = "Your gallery could not be saved."
      render :action => :new
    end
  end

  def add
    use_javascript('galleries/add')
  end

  def show
    render json: @gallery.icons
  end

  def icon
    icon = Icon.find(params[:icon_id])
    @gallery.icons << icon
    flash[:success] = "Icon added to gallery successfully."
    redirect_to galleries_path
  end

  def destroy
    @gallery.destroy
    flash[:success] = "Gallery deleted successfully."
    redirect_to galleries_path
  end

  def remove
    icon = Icon.find(params[:icon_id])
    @gallery.icons.delete(icon)
    render json: {}
  end

  private

  def find_gallery
    @gallery = Gallery.find_by_id(params[:id])

    unless @gallery
      flash[:error] = "Gallery could not be found."
      redirect_to galleries_path and return
    end

    if @gallery.user_id != current_user.id
      flash[:error] = "That is not your gallery."
      redirect_to galleries_path and return
    end
  end
end
