require "spec_helper"

RSpec.describe DailyReport do
  describe "#posts" do
    default_zone = Time.zone
    {
      # 2017-11-05 10:00, clock goes back in Eastern
      "without timezone" => [default_zone, [2017, 11, 05, 10, 00]],
      # 2017-10-29 10:00, clock goes back in GMT/BST
      "with timezone" => ["Europe/London", [2017, 10, 29, 10, 00]]
    }.each do |name, data|
      zone = data.first
      dst_day_params = data.last
      context name do
        before(:each) { Time.zone = zone }
        after(:each) { Time.zone = default_zone }
        it "should work on a regular day" do
          time = Time.zone.local(2017, 01, 02, 10, 00) # 2017-01-02 10:00
          day = time.beginning_of_day
          shown_posts = Array.new(24) do |i| # 0 .. 23
            step = day + i.hours
            Timecop.freeze(step) { create(:post) }
          end
          shown_posts.each do |post|
            expect(post.tagged_at).to be_between(day, day.end_of_day).inclusive
          end

          hidden_post1 = Timecop.freeze(day - 1.hour) { create(:post) }
          hidden_post2 = Timecop.freeze(day.end_of_day + 1.hour) { create(:post) }
          expect(hidden_post1.tagged_at).not_to be_between(day, day.end_of_day).inclusive
          expect(hidden_post2.tagged_at).not_to be_between(day, day.end_of_day).inclusive

          expect(DailyReport.new(time).posts).to match_array(shown_posts)
        end

        it "should work on a daylight change day" do
          time = Time.zone.local(*dst_day_params)
          # clock goes back; 25 hours in the day
          day = time.beginning_of_day
          shown_posts = Array.new(25) do |i| # 0 .. 24
            step = day + i.hours
            Timecop.freeze(step) { create(:post) }
          end
          shown_posts.each do |post|
            expect(post.tagged_at).to be_between(day, day.end_of_day).inclusive
          end

          hidden_post1 = Timecop.freeze(day - 1.hour) { create(:post) }
          hidden_post2 = Timecop.freeze(day.end_of_day + 1.hour) { create(:post) }
          expect(hidden_post1.tagged_at).not_to be_between(day, day.end_of_day).inclusive
          expect(hidden_post2.tagged_at).not_to be_between(day, day.end_of_day).inclusive

          expect(DailyReport.new(time).posts).to match_array(shown_posts)
        end
      end
    end
  end
end