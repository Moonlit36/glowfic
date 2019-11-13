require "spec_helper"

RSpec.describe ReplyScraper do
  describe "set_from_icon" do
    it "handles Kappa icons" do
      kappa = create(:user, id: 3)
      char = create(:character, user: kappa)
      gallery = create(:gallery, user: kappa)
      char.galleries << gallery
      icon = create(:icon, user: kappa, keyword: '⑮ mountains')
      gallery.icons << icon
      tag = build(:reply, user: kappa, character: char)
      expect(tag.icon_id).to be_nil
      scraper = ReplyScraper.new(tag)
      scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'f.1 mountains')
      expect(Icon.count).to eq(1)
      expect(tag.icon_id).to eq(icon.id)
    end

    it "handles icons with descriptions" do
      user = create(:user)
      char = create(:character, user: user)
      gallery = create(:gallery, user: user)
      char.galleries << gallery
      icon = create(:icon, user: user, keyword: 'keyword blah')
      gallery.icons << icon
      tag = build(:reply, user: user, character: char)
      expect(tag.icon_id).to be_nil
      scraper = ReplyScraper.new(tag)
      scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'keyword blah (Accessbility description.)')
      expect(Icon.count).to eq(1)
      expect(tag.icon_id).to eq(icon.id)
    end

    it "handles kappa icons with descriptions" do
      kappa = create(:user, id: 3)
      char = create(:character, user: kappa)
      gallery = create(:gallery, user: kappa)
      char.galleries << gallery
      icon = create(:icon, user: kappa, keyword: '⑮ keyword blah')
      gallery.icons << icon
      tag = build(:reply, user: kappa, character: char)
      expect(tag.icon_id).to be_nil
      scraper = ReplyScraper.new(tag)
      scraper.send(:set_from_icon, tag, 'http://irrelevanturl.com', 'f.1 keyword blah (Accessbility description.)')
      expect(Icon.count).to eq(1)
      expect(tag.icon_id).to eq(icon.id)
    end
  end
end
