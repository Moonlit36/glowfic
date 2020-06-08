module Tag::Taggable::ContentWarning
  extend ActiveSupport::Concern

  included do
    include Tag::Taggable

    define_attribute_method :content_warning_list

    after_initialize :load_content_warning_tags
    after_save :save_content_warning_tags

    def content_warning_list
      @content_warning_list
    end

    def content_warning_list=(list)
      list = Tag::List.new(list)
      content_warning_list_will_change! unless list == content_warning_list
      @content_warning_list = list
    end

    private

    def load_content_warning_tags
      @content_warning_list = Tag::List.new(content_warnings.map(&:name))
    end

    def save_content_warning_tags
      return unless content_warning_list_changed?
      save_tags(::ContentWarning, new_list: @content_warning_list, old_list: content_warning_list_was, assoc: content_warnings)
    end
  end
end
