# frozen_string_literal: true
require 'will_paginate/array'

class RepliesController < WritableController
  before_action :login_required, except: [:search, :show, :history]
  before_action :find_model, only: [:show, :history, :edit, :update, :destroy]
  before_action :editor_setup, only: [:edit]
  before_action :require_permission, only: [:edit, :update]

  def search
    @page_title = 'Search Replies'
    use_javascript('posts/search')

    @post = Post.find_by_id(params[:post_id]) if params[:post_id].present?
    @icon = Icon.find_by_id(params[:icon_id]) if params[:icon_id].present?
    if @post.try(:visible_to?, current_user)
      @users = @post.authors.active
      char_ids = @post.replies.select(:character_id).distinct.pluck(:character_id) + [@post.character_id]
      @characters = Character.where(id: char_ids).ordered
      @templates = Template.where(id: @characters.map(&:template_id).uniq.compact).ordered
      gon.post_id = @post.id
    else
      @users = User.active.where(id: params[:author_id]) if params[:author_id].present?
      @characters = Character.where(id: params[:character_id]) if params[:character_id].present?
      @templates = Template.ordered.limit(25)
      @boards = Board.where(id: params[:board_id]) if params[:board_id].present?
      if @post
        # post exists but post not visible
        flash.now[:error] = "You do not have permission to view this post."
        return
      end
    end

    return unless params[:commit].present?

    @search_results = Reply.unscoped
    @search_results = @search_results.where(user_id: params[:author_id]) if params[:author_id].present?
    @search_results = @search_results.where(character_id: params[:character_id]) if params[:character_id].present?
    @search_results = @search_results.where(icon_id: params[:icon_id]) if params[:icon_id].present?

    if params[:subj_content].present?
      @search_results = @search_results.search(params[:subj_content]).with_pg_search_highlight
      exact_phrases = params[:subj_content].scan(/"([^"]*)"/)
      if exact_phrases.present?
        exact_phrases.each do |phrase|
          phrase = phrase.first.strip
          next if phrase.blank?
          @search_results = @search_results.where("replies.content LIKE ?", "%#{phrase}%")
        end
      end
    end

    append_rank = params[:subj_content].present? ? ', rank DESC' : ''
    if params[:sort] == 'created_new'
      @search_results = @search_results.except(:order).order('replies.created_at DESC' + append_rank)
    elsif params[:sort] == 'created_old'
      @search_results = @search_results.except(:order).order('replies.created_at ASC' + append_rank)
    elsif params[:subj_content].blank?
      @search_results = @search_results.order('replies.created_at DESC')
    end

    if @post
      @search_results = @search_results.where(post_id: @post.id)
    elsif params[:board_id].present?
      post_ids = Post.where(board_id: params[:board_id]).pluck(:id)
      @search_results = @search_results.where(post_id: post_ids)
    end

    if params[:template_id].present?
      @templates = Template.where(id: params[:template_id])
      if @templates.first.present?
        character_ids = Character.where(template_id: @templates.first.id).pluck(:id)
        @search_results = @search_results.where(character_id: character_ids)
      end
    elsif params[:author_id].present?
      @templates = @templates.where(user_id: params[:author_id])
    end

    @search_results = @search_results
      .select('replies.*, characters.name, characters.screenname, users.username, users.deleted as user_deleted')
      .visible_to(current_user)
      .joins(:user)
      .left_outer_joins(:character)
      .with_edit_audit_counts
      .paginate(page: page)
      .includes(:post)

    unless params[:condensed]
      @search_results = @search_results
        .select('icons.keyword, icons.url')
        .left_outer_joins(:icon)
    end
  end

  def create
    if params[:button_draft]
      draft = make_draft
      redirect_to posts_path and return unless draft.post
      redirect_to post_path(draft.post, page: :unread, anchor: :unread) and return
    elsif params[:button_preview]
      draft = make_draft
      preview(ReplyDraft.reply_from_draft(draft)) and return
    end

    @reply = Reply.new(user: current_user)
    creator = Reply::Saver.new(@reply, user: current_user, params: params)

    if creator.create # rubocop:disable Rails/SaveBang
      flash[:success] = "Posted!"
      redirect_to reply_path(@reply, anchor: "reply-#{@reply.id}")
    else
      flash[:error] = {
        message: creater.error_message,
        array: reply.errors.full_messages
      }
      if creator.show_preview
        if creator.skip_draft
          preview(@reply)
        else
          draft = make_draft(false)
          preview(ReplyDraft.reply_from_draft(draft))
        end
      end
      @allow_dupe = true if creator.duplicate
      redirect_to posts_path and return unless reply.post
      redirect_to post_path(reply.post)
    end
  end

  def show
    @page_title = @post.subject
    params[:page] ||= @reply.post_page(per_page)

    show_post(params[:page])
  end

  def history
  end

  def edit
  end

  def update
    updater = Reply::Saver.new(@reply, user: current_user, params: params)

    if updater.update
      flash[:success] = "Post updated"
      redirect_to reply_path(@reply, anchor: "reply-#{@reply.id}")
    else
      flash[:error] = {
        message: updater.error_message,
        array: @reply.errors.full_messages
      }
      editor_setup
      render :edit
    end
  end

  def destroy
    unless @reply.deletable_by?(current_user)
      flash[:error] = "You do not have permission to modify this post."
      redirect_to post_path(@reply.post) and return
    end

    previous_reply = @reply.send(:previous_reply)
    to_page = previous_reply.try(:post_page, per_page) || 1

    # to destroy subsequent replies, do @reply.destroy_subsequent_replies
    begin
      @reply.destroy!
    rescue ActiveRecord::RecordNotDestroyed
      flash[:error] = {
        message: "Reply could not be deleted.",
        array: @reply.errors.full_messages
      }
      redirect_to reply_path(@reply, anchor: "reply-#{@reply.id}")
    else
      flash[:success] = "Reply deleted."
      redirect_to post_path(@reply.post, page: to_page)
    end
  end

  def restore
    audit = Audited::Audit.where(action: 'destroy').order(id: :desc).find_by(auditable_id: params[:id])
    unless audit
      flash[:error] = "Reply could not be found."
      redirect_to continuities_path and return
    end

    if audit.auditable
      flash[:error] = "Reply does not need restoring."
      redirect_to post_path(audit.associated) and return
    end

    new_reply = Reply.new(audit.audited_changes)
    unless new_reply.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this post."
      redirect_to post_path(new_reply.post) and return
    end

    new_reply.is_import = true
    new_reply.skip_notify = true
    new_reply.id = audit.auditable_id

    following_replies = new_reply.post.replies.where('id > ?', new_reply.id).order(id: :asc)
    new_reply.skip_post_update = following_replies.exists?
    new_reply.reply_order = following_replies.first&.reply_order

    Reply.transaction do
      following_replies.update_all('reply_order = reply_order + 1') # rubocop:disable Rails/SkipsModelValidations
      new_reply.save!
    end

    flash[:success] = "Reply has been restored!"
    redirect_to reply_path(new_reply)
  end

  private

  def find_model
    @reply = Reply.find_by_id(params[:id])

    unless @reply
      flash[:error] = "Post could not be found."
      redirect_to continuities_path and return
    end

    @post = @reply.post
    unless @post.visible_to?(current_user)
      flash[:error] = "You do not have permission to view this post."
      redirect_to continuities_path and return
    end

    @page_title = @post.subject
  end

  def require_permission
    unless @reply.editable_by?(current_user)
      flash[:error] = "You do not have permission to modify this post."
      redirect_to post_path(@reply.post)
    end
  end

  def preview(written)
    @written = written
    @post = @written.post
    @written.user = current_user unless @written.user

    @page_title = @post.subject

    editor_setup
    render :preview
  end

  def make_draft(show_message=true)
    drafter = Reply::Drafter.new(params, user: current_user)

    if drafter.perform
      flash[:success] = "Draft saved!" if show_message
    else
      flash[:error] = {
        message: "Your draft could not be saved because of the following problems:",
        array: drafter.draft.errors.full_messages
      }
    end
    drafter.draft
  end
end
