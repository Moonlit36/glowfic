class ScrapePostJob < ApplicationJob
  queue_as :low

  def perform(params, user:)
    Resque.logger.debug "Starting scrape for #{params[:dreamwidth_url]}"
    scraper = PostScraper.new(params[:dreamwidth_url], board_id: params[:board_id], section_id: params[:section_id],
                              status: params[:status], threaded: params[:threaded])
    scraped_post = scraper.scrape!
    Message.send_site_message(user.id, 'Post import succeeded', "Your post was successfully imported! #{self.class.view_post(scraped_post.id)}")
  end

  def self.notify_exception(exception, params, user:)
    Resque.logger.warn "Failed to import #{url}: #{exception.message}"
    if user
      message = "The url <a href='#{url}'>#{url}</a> could not be successfully scraped. "
      message += exception.message if exception.is_a?(UnrecognizedUsernameError)
      message += "Your post was already imported! #{view_post(exception.post_id)}" if exception.is_a?(AlreadyImportedError)
      Message.send_site_message(user.id, 'Post import failed', message)
    end
    super
  end

  def self.view_post(post_id)
    host = ENV['DOMAIN_NAME'] || 'localhost:3000'
    url = Rails.application.routes.url_helpers.post_url(post_id, host: host, protocol: 'https')
    "<a href='#{url}'>View it here</a>."
  end
end
