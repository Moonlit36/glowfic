class AddEditorModeToReplies < ActiveRecord::Migration[5.2]
  def up
    add_column :replies, :editor_mode, :string

    Reply.all.each do |reply|
      if reply.content[/<p( [^>]*)?>/] || reply.content[/<br *\/?>/]
        reply.update_columns(editor_mode: 'rtf')
      else
        reply.update_columns(editor_mode: 'html')
      end
    end
  end

  def down
    remove_column :replies, :editor_mode, :string
  end
end
