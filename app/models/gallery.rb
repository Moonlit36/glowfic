class Gallery < ActiveRecord::Base
  belongs_to :user
  has_and_belongs_to_many :icons
  has_many :characters
  belongs_to :cover_icon, :class_name => Icon

  validates_presence_of :user, :name

  def default_icon
    cover_icon || icons.first
  end
end
