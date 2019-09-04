class Gallery::IconAdder < Generic::Service
  attr_reader :success_message, :errors, :icons

  def initialize(gallery, user:, params:)
    @gallery = gallery
    @user = user
    @params = params
    @errors = []
  end

  def assign_existing
    raise MissingGalleryError, "Gallery could not be found." unless @gallery # gallery required for adding icons from other galleries

    icon_ids = @params[:image_ids].split(',').map(&:to_i).reject(&:zero?)
    icon_ids -= @gallery.icons.pluck(:id)
    icons = Icon.where(id: icon_ids, user_id: @user.id)
    icons.each { @gallery.icons << icon }
    @success_message = "Icons added to gallery successfully."
  end

  def create_new
    @icons = (@params[:icons] || []).reject { |icon| icon.values.all?(&:blank?) }
    raise NoIconsError, "You have to enter something." if icons.empty?

    failed = false
    icons = []
    @icons.each_with_index do |icon, index|
      icon = Icon.new(icon_params(icon.except('filename', 'file')))
      icon.user = @user
      unless icon.valid?
        @icons[index]['url'] = @icons[index]['s3_key'] = '' if icon.errors.messages[:url]&.include?('is invalid')
        @errors += icon.errors.full_messages.map{|m| "Icon "+(index+1).to_s+": "+m.downcase}
        failed = true
      end
      icons << icon
    end

    raise InvalidIconsError, "Your icons could not be saved." if failed

    if icons.all?(&:save)
      icons.each { |icon| @gallery.icons << icon } if @gallery
      @success_message = "Icons saved successfully."
    else
      @icons = [] if icons.empty?
      raise InvalidIconsError, "Your icons could not be saved."
    end
  end

  def icon_params(paramset)
    paramset.permit(:url, :keyword, :credit, :s3_key)
  end
end

class MissingGalleryError < ApiError; end
class NoIconsError < ApiError; end
class InvalidIconsError < SaveFailedError; end
