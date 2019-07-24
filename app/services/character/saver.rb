class Character::Saver < Auditable::Saver
  include Taggable

  attr_reader :character

  def initialize(character, user:, params:)
    super
    @character = character
    @settings = process_tags(Setting, :character, :setting_ids)
    @gallery_groups = process_tags(GalleryGroup, :character, :gallery_group_ids)
  end

  private

  def check_audit_comment
    # TODO once assign_attributes doesn't save, use @character.audit_comment and uncomment clearing
    raise NoModNoteError if @user.id != @character.user_id && @params.fetch(:character, {})[:audit_comment].blank?
    # @character.audit_comment = nil if @character.changes.empty?
  end

  def build
    build_template
  end

  def save!
    Character.transaction do
      @character.assign_attributes(permitted_params)
      @character.settings = process_tags(Setting, :character, :setting_ids)
      @character.gallery_groups = process_tags(GalleryGroup, :character, :gallery_group_ids)
      @character.save!
    end
  end

  def build_template
    return unless @params[:new_template].present? && @character.user == @user
    @character.build_template unless @character.template
    @character.template.user = @user
  end

  def permitted_params
    permitted = [
      :name,
      :template_name,
      :screenname,
      :template_id,
      :pb,
      :description,
      :audit_comment,
      ungrouped_gallery_ids: [],
    ]
    if @character.user == @user
      permitted.last[:template_attributes] = [:name, :id]
      permitted.insert(0, :default_icon_id)
    end
    @params.fetch(:character, {}).permit(permitted)
  end
end
