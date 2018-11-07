class Post::Searcher < Generic::Searcher
  def initialize(search=Post.ordered)
    super
  end

  def search(params)
    @search_results = @search_results.where(board_id: params[:board_id]) if params[:board_id].present?
    @search_results = @search_results.where(id: Setting.find(params[:setting_id]).post_tags.pluck(:post_id)) if params[:setting_id].present?
    if params[:subject].present?
      @search_results = @search_results.search(params[:subject]).where('LOWER(subject) LIKE ?', "%#{params[:subject].downcase}%")
    end
    @search_results = @search_results.complete if params[:completed].present?
    if params[:author_id].present?
      post_ids = nil
      params[:author_id].each do |author_id|
        author_posts = PostAuthor.where(user_id: author_id, joined: true).pluck(:post_id)
        if post_ids.nil?
          post_ids = author_posts
        else
          post_ids &= author_posts
        end
        break if post_ids.empty?
      end
      @search_results = @search_results.where(id: post_ids.uniq)
    end
    if params[:character_id].present?
      post_ids = Reply.where(character_id: params[:character_id]).select(:post_id).distinct.pluck(:post_id)
      @search_results = @search_results.where(character_id: params[:character_id]).or(@search_results.where(id: post_ids))
    end
  end
end
